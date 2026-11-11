extends CharacterBody2D
# 버질 (Godot 4.x)
# 조작: Space 점프 / 마우스 왼쪽 기본공격 / E 저지먼트 컷 / Q 대시 / F 방어

enum State { NORMAL, DASH, GUARD, ATTACK, JUDGEMENT }

# ---------- 이동 ----------
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0
@export var friction: float = 1600.0

# ---------- 대시 (Q) ----------
@export var dash_distance: float = 200.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5

# ---------- 체력 ----------
@export var max_health: float = 100.0
signal health_changed(current: float, maximum: float)

# ---------- 기본공격 (마우스 왼쪽) ----------
@export var attack_effect: PackedScene
@export var attack_damage: float = 10.0
@export var attack_fallback_duration: float = 0.4
@export var attack_cooldown: float = 0.2

# ---------- 저지먼트 컷 (E) ----------
@export var judgement_cut_scene: PackedScene      # judgement_cut.tscn 연결
@export var judgement_damage: float = 40.0
@export var judgement_range: float = 800.0        # 이 거리 안의 enemy만 공격. 0이면 거리 제한 없음
@export var judgement_cooldown: float = 6.0
@export var judgement_cast_fallback: float = 0.5  # 시전 애니메이션이 없을 때 서있는 시간
@export var judgement_stagger: float = 0.0        # 적마다 컷이 순서대로 나가는 간격(초). 0이면 동시에

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.NORMAL
var health: float = 0.0
var state_time_left: float = 0.0

var dash_time_left: float = 0.0
var dash_dir: float = 1.0
var dash_cooldown_left: float = 0.0
var attack_cooldown_left: float = 0.0
var judgement_cooldown_left: float = 0.0


func _ready() -> void:
	_ensure_key("jump", KEY_SPACE)
	_ensure_key("dash", KEY_Q)
	_ensure_key("skill1", KEY_E)
	_ensure_key("guard", KEY_F)
	_ensure_mouse("attack", MOUSE_BUTTON_LEFT)
	add_to_group("player")
	health = max_health
	health_changed.emit(health, max_health)


func _ensure_key(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and ev.physical_keycode == key:
			return
	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = key
	InputMap.action_add_event(action, new_ev)


func _ensure_mouse(action: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and ev.button_index == button:
			return
	var new_ev := InputEventMouseButton.new()
	new_ev.button_index = button
	InputMap.action_add_event(action, new_ev)


func _physics_process(delta: float) -> void:
	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)
	attack_cooldown_left = max(attack_cooldown_left - delta, 0.0)
	judgement_cooldown_left = max(judgement_cooldown_left - delta, 0.0)

	match state:
		State.NORMAL:
			_normal_state(delta)
		State.DASH:
			_dash_state(delta)
		State.GUARD:
			_guard_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.JUDGEMENT:
			_judgement_state(delta)

	move_and_slide()


# ---------- 일반 상태 (이동/점프) ----------
func _normal_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * speed
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	# 대시 (Q)
	if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0.0:
		_start_dash(direction)
		return

	# 저지먼트 컷 (E) : 땅 위에서
	if is_on_floor() and Input.is_action_just_pressed("skill1") and judgement_cooldown_left <= 0.0:
		_start_judgement()
		return

	# 기본공격 (클릭) : 땅 위에서
	if is_on_floor() and Input.is_action_just_pressed("attack") and attack_cooldown_left <= 0.0:
		_start_attack()
		return

	# 방어 (F)
	if Input.is_action_pressed("guard") and is_on_floor():
		state = State.GUARD
		velocity.x = 0.0
		_play_anim("guard")
		return

	if not is_on_floor():
		_play_anim("jump")
	elif direction != 0:
		_play_anim("run")
	else:
		_play_anim("idle")


# ---------- 대시 ----------
func _start_dash(input_dir: float) -> void:
	dash_dir = sign(input_dir) if input_dir != 0.0 else _facing()
	sprite.flip_h = dash_dir < 0
	dash_time_left = dash_duration
	state = State.DASH
	_play_anim("dash")


func _dash_state(delta: float) -> void:
	var start_speed: float = 2.0 * dash_distance / dash_duration
	var ratio: float = clamp(dash_time_left / dash_duration, 0.0, 1.0)
	velocity.x = dash_dir * start_speed * ratio
	velocity.y = 0.0
	dash_time_left -= delta
	if dash_time_left <= 0.0:
		velocity.x = 0.0
		dash_cooldown_left = dash_cooldown
		state = State.NORMAL


# ---------- 방어 ----------
func _guard_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0, friction * delta)
	if not Input.is_action_pressed("guard") or not is_on_floor():
		state = State.NORMAL


# ---------- 기본공격 ----------
func _start_attack() -> void:
	state = State.ATTACK
	velocity.x = 0.0
	var anim_name: StringName = _play_anim_restart(&"attack")
	state_time_left = _anim_length(anim_name, attack_fallback_duration)
	if attack_effect != null:
		var effect := attack_effect.instantiate()
		if "damage" in effect:
			effect.damage = attack_damage
		add_child(effect)
		if effect is Node2D:
			effect.scale.x = _facing()


func _attack_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	state_time_left -= delta
	if state_time_left <= 0.0:
		attack_cooldown_left = attack_cooldown
		state = State.NORMAL


# ---------- 저지먼트 컷 (E) ----------
# 시전 모션(애니메이션 "judgement_cast", 없으면 "skill1" → 없으면 그냥 서있음) 동안 가만히 서고,
# 시전과 동시에 enemy 그룹의 적마다 저지먼트 컷 씬을 하나씩 생성
func _start_judgement() -> void:
	state = State.JUDGEMENT
	velocity.x = 0.0
	var anim_name: StringName = _play_anim_restart(&"judgement_cast", &"skill1")
	state_time_left = _anim_length(anim_name, judgement_cast_fallback)
	_cast_judgement_cuts()


func _judgement_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	state_time_left -= delta
	if state_time_left <= 0.0:
		judgement_cooldown_left = judgement_cooldown
		state = State.NORMAL


func _cast_judgement_cuts() -> void:
	if judgement_cut_scene == null:
		return  # 씬이 아직 연결 안 됐으면 시전 모션만 재생
	var index: int = 0
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node2D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if judgement_range > 0.0 and global_position.distance_to(enemy.global_position) > judgement_range:
			continue
		if judgement_stagger > 0.0:
			_spawn_cut_delayed(enemy, judgement_stagger * index)
		else:
			_spawn_cut(enemy)
		index += 1


func _spawn_cut_delayed(enemy: Node2D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(enemy):
		_spawn_cut(enemy)


func _spawn_cut(enemy: Node2D) -> void:
	var cut := judgement_cut_scene.instantiate()
	cut.target = enemy
	cut.damage = judgement_damage
	get_parent().add_child(cut)  # 캐릭터가 아니라 메인 씬에 생성 (적을 따라다니므로)


# ---------- 헬퍼 ----------
func _facing() -> float:
	return -1.0 if sprite.flip_h else 1.0


func _anim_length(anim: StringName, fallback: float) -> float:
	var frames := sprite.sprite_frames
	if anim != &"" and frames and frames.has_animation(anim):
		var total: float = 0.0
		for i in frames.get_frame_count(anim):
			total += frames.get_frame_duration(anim, i)
		var fps: float = frames.get_animation_speed(anim)
		if fps > 0.0 and total > 0.0:
			return total / fps / max(sprite.speed_scale, 0.001)
	return fallback


func _pick_anim(primary: StringName, fallback: StringName = &"") -> StringName:
	var frames := sprite.sprite_frames
	if frames == null:
		return &""
	if frames.has_animation(primary):
		return primary
	if fallback != &"" and frames.has_animation(fallback):
		return fallback
	return &""


func _play_anim(anim: StringName) -> void:
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)


func _play_anim_restart(primary: StringName, fallback: StringName = &"") -> StringName:
	var anim_name: StringName = _pick_anim(primary, fallback)
	if anim_name != &"":
		sprite.stop()
		sprite.play(anim_name)
	return anim_name
