extends CharacterBody2D
# 미사 (Godot 4.x)
# 조작: Space 점프 / 마우스 왼쪽 기본공격 / E 스킬1 / R 스킬2 / T 궁극기 / Q 대시 / F 방어

enum State {
	NORMAL, DASH, GUARD,
	ATTACK, SKILL1, SKILL2,
	AIR_ATTACK, AIR_SKILL1,
	ULT_READY, ULT_FIRE,
}

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

# ---------- 기본공격 (마우스 왼쪽) : 땅에서는 가만히 서서 근접공격 ----------
@export var attack_effect: PackedScene
@export var attack_damage: float = 10.0
@export var attack_fallback_duration: float = 0.4
@export var attack_cooldown: float = 0.2

# ---------- 스킬1 (E) : 망치 회전 돌진 + 회오리바람 ----------
@export var skill1_effect: PackedScene
@export var skill1_damage: float = 20.0
@export var skill1_distance: float = 350.0
@export var skill1_fallback_duration: float = 0.7
@export var skill1_cooldown: float = 5.0

# ---------- 스킬2 (R) : 가만히 서서 체력/능력 회복 ----------
@export var skill2_effect: PackedScene
@export var skill2_heal: float = 30.0
@export var skill2_fallback_duration: float = 1.0
@export var skill2_cooldown: float = 12.0
@export var buff_duration: float = 5.0
@export var buff_speed_multiplier: float = 1.3
@export var buff_damage_multiplier: float = 1.3

# ---------- 공중 공격 : 점프 중 기본공격 → 빠르게 내려오며 공격 ----------
@export var air_attack_effect: PackedScene        # 비워두면 attack_effect를 사용
@export var air_attack_damage: float = 12.0
@export var air_attack_fall_speed: float = 900.0  # 내려오는 속도(px/s)
@export var air_attack_drift: float = 120.0       # 내려오며 앞으로 밀리는 속도

# ---------- 공중 스킬1 : 점프 중 E → 회전 공격하며 앞으로 빠르게 이동, 내려옴 ----------
@export var air_skill1_effect: PackedScene        # 비워두면 skill1_effect를 사용
@export var air_skill1_damage: float = 25.0
@export var air_skill1_speed: float = 700.0       # 앞으로 이동하는 속도
@export var air_skill1_fall_speed: float = 700.0  # 내려오는 속도
@export var air_max_time: float = 1.5             # 착지 못해도 이 시간이 지나면 종료(안전장치)

# ---------- 궁극기 (T) : 뒤로 도약 → 준비모션 → 0.5초 뒤 큰 반동으로 날아가며 투사체 발사 ----------
@export var ultimate_projectile: PackedScene      # projectile.gd를 붙인 투사체 씬
@export var ultimate_damage: float = 50.0
@export var ultimate_cooldown: float = 20.0
@export var ult_back_speed: float = 350.0         # 뒤로 도약하는 속도
@export var ult_back_hop: float = 280.0           # 도약할 때 위로 뜨는 속도
@export var ult_ready_time: float = 0.5           # 준비모션 시간(초). 이 시간 뒤에 발사
@export var ult_recoil_speed: float = 900.0       # 발사 반동으로 날아가는 속도
@export var ult_recoil_lift: float = 150.0        # 반동으로 살짝 뜨는 정도
@export var ult_recoil_decel: float = 1800.0      # 반동 감속량
@export var ult_fire_fallback_duration: float = 0.6
@export var recoil_backward: bool = true          # true: 발사 방향의 뒤쪽으로 반동 / false: 앞쪽으로
@export var projectile_offset: Vector2 = Vector2(50, -30)  # 오른쪽을 볼 때 투사체가 나오는 위치

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.NORMAL
var health: float = 0.0
var state_time_left: float = 0.0
var skill_dir: float = 1.0
var skill1_speed: float = 0.0
var buff_time_left: float = 0.0
var _active_effect: Node = null

var dash_time_left: float = 0.0
var dash_dir: float = 1.0
var dash_cooldown_left: float = 0.0
var attack_cooldown_left: float = 0.0
var skill1_cooldown_left: float = 0.0
var skill2_cooldown_left: float = 0.0
var ultimate_cooldown_left: float = 0.0


func _ready() -> void:
	_ensure_key("jump", KEY_SPACE)
	_ensure_key("dash", KEY_Q)
	_ensure_key("skill1", KEY_E)
	_ensure_key("skill2", KEY_R)
	_ensure_key("ultimate", KEY_T)
	_ensure_key("guard", KEY_F)
	_ensure_mouse("attack", MOUSE_BUTTON_LEFT)
	add_to_group("player")  # 보스가 이 그룹을 감지합니다
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
	skill1_cooldown_left = max(skill1_cooldown_left - delta, 0.0)
	skill2_cooldown_left = max(skill2_cooldown_left - delta, 0.0)
	ultimate_cooldown_left = max(ultimate_cooldown_left - delta, 0.0)
	buff_time_left = max(buff_time_left - delta, 0.0)

	match state:
		State.NORMAL:
			_normal_state(delta)
		State.DASH:
			_dash_state(delta)
		State.GUARD:
			_guard_state(delta)
		State.ATTACK:
			_attack_state(delta)
		State.SKILL1:
			_skill1_state(delta)
		State.SKILL2:
			_skill2_state(delta)
		State.AIR_ATTACK:
			_air_attack_state(delta)
		State.AIR_SKILL1:
			_air_skill1_state(delta)
		State.ULT_READY:
			_ult_ready_state(delta)
		State.ULT_FIRE:
			_ult_fire_state(delta)

	move_and_slide()


# ---------- 일반 상태 (이동/점프) ----------
func _normal_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	# 점프 (Space)
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 좌우 이동
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * _current_speed()
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	# 대시 (Q)
	if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0.0:
		_start_dash(direction)
		return

	# 궁극기 (T) : 땅 위에서만
	if Input.is_action_just_pressed("ultimate") and ultimate_cooldown_left <= 0.0 and is_on_floor():
		_start_ultimate()
		return

	if is_on_floor():
		# 땅: 스킬1(E) / 스킬2(R) / 기본공격(클릭)
		if Input.is_action_just_pressed("skill1") and skill1_cooldown_left <= 0.0:
			_start_skill1(direction)
			return
		if Input.is_action_just_pressed("skill2") and skill2_cooldown_left <= 0.0:
			_start_skill2()
			return
		if Input.is_action_just_pressed("attack") and attack_cooldown_left <= 0.0:
			_start_attack()
			return
	else:
		# 공중: 스킬1(E) / 기본공격(클릭)
		if Input.is_action_just_pressed("skill1") and skill1_cooldown_left <= 0.0:
			_start_air_skill1(direction)
			return
		if Input.is_action_just_pressed("attack") and attack_cooldown_left <= 0.0:
			_start_air_attack()
			return

	# 방어 (F 누르고 있는 동안, 땅 위에서만)
	if Input.is_action_pressed("guard") and is_on_floor():
		state = State.GUARD
		velocity.x = 0.0
		_play_anim("guard")
		return

	# 애니메이션 선택
	if not is_on_floor():
		_play_anim("jump")
	elif direction != 0:
		_play_anim("run")
	else:
		_play_anim("idle")


# ---------- 대시 ----------
func _start_dash(input_dir: float) -> void:
	if input_dir != 0.0:
		dash_dir = sign(input_dir)
	else:
		dash_dir = _facing()
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


# ---------- 기본공격 (땅) ----------
func _start_attack() -> void:
	state = State.ATTACK
	velocity.x = 0.0
	var anim_name: StringName = _play_anim_restart(&"attack")
	state_time_left = _anim_length(anim_name, attack_fallback_duration)
	_spawn_effect(attack_effect, _damage(attack_damage), -1.0)


func _attack_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	state_time_left -= delta
	if state_time_left <= 0.0:
		attack_cooldown_left = attack_cooldown
		state = State.NORMAL


# ---------- 스킬1 (땅): 회전 돌진 + 회오리바람 ----------
func _start_skill1(input_dir: float) -> void:
	skill_dir = sign(input_dir) if input_dir != 0.0 else _facing()
	sprite.flip_h = skill_dir < 0
	state = State.SKILL1
	var anim_name: StringName = _play_anim_restart(&"skill1")
	state_time_left = _anim_length(anim_name, skill1_fallback_duration)
	skill1_speed = skill1_distance / state_time_left
	_spawn_effect(skill1_effect, _damage(skill1_damage), state_time_left)


func _skill1_state(delta: float) -> void:
	velocity.x = skill_dir * skill1_speed
	velocity.y = 0.0
	state_time_left -= delta
	if state_time_left <= 0.0:
		velocity.x = 0.0
		skill1_cooldown_left = skill1_cooldown
		state = State.NORMAL


# ---------- 스킬2: 체력/능력 회복 ----------
func _start_skill2() -> void:
	state = State.SKILL2
	velocity.x = 0.0
	var anim_name: StringName = _play_anim_restart(&"skill2")
	state_time_left = _anim_length(anim_name, skill2_fallback_duration)
	_spawn_effect(skill2_effect, 0.0, -1.0)
	health = min(health + skill2_heal, max_health)
	health_changed.emit(health, max_health)
	buff_time_left = buff_duration


func _skill2_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = 0.0
	state_time_left -= delta
	if state_time_left <= 0.0:
		skill2_cooldown_left = skill2_cooldown
		state = State.NORMAL


# ---------- 공중 기본공격: 빠르게 내려오며 공격 ----------
func _start_air_attack() -> void:
	state = State.AIR_ATTACK
	state_time_left = air_max_time
	skill_dir = _facing()
	velocity.x = skill_dir * air_attack_drift
	velocity.y = max(velocity.y, air_attack_fall_speed)
	_play_anim_restart(&"air_attack", &"attack")
	var scene: PackedScene = air_attack_effect if air_attack_effect != null else attack_effect
	_active_effect = _spawn_effect(scene, _damage(air_attack_damage), -1.0)


func _air_attack_state(delta: float) -> void:
	velocity.x = skill_dir * air_attack_drift
	velocity.y = air_attack_fall_speed
	state_time_left -= delta
	if is_on_floor() or state_time_left <= 0.0:
		_clear_effect()
		velocity.x = 0.0
		attack_cooldown_left = attack_cooldown
		state = State.NORMAL


# ---------- 공중 스킬1: 회전 공격하며 앞으로 빠르게 이동, 내려옴 ----------
func _start_air_skill1(input_dir: float) -> void:
	skill_dir = sign(input_dir) if input_dir != 0.0 else _facing()
	sprite.flip_h = skill_dir < 0
	state = State.AIR_SKILL1
	state_time_left = air_max_time
	velocity = Vector2(skill_dir * air_skill1_speed, air_skill1_fall_speed)
	_play_anim_restart(&"air_skill1", &"skill1")
	var scene: PackedScene = air_skill1_effect if air_skill1_effect != null else skill1_effect
	# 착지하면 _clear_effect()로 바로 제거되므로 lifetime은 안전장치 시간으로 지정
	_active_effect = _spawn_effect(scene, _damage(air_skill1_damage), air_max_time)


func _air_skill1_state(delta: float) -> void:
	velocity.x = skill_dir * air_skill1_speed
	velocity.y = air_skill1_fall_speed
	state_time_left -= delta
	if is_on_floor() or state_time_left <= 0.0:
		_clear_effect()
		velocity.x = 0.0
		skill1_cooldown_left = skill1_cooldown
		state = State.NORMAL


# ---------- 궁극기: 뒤로 도약 → 준비모션(0.5초) → 반동 + 투사체 ----------
func _start_ultimate() -> void:
	state = State.ULT_READY
	state_time_left = ult_ready_time
	velocity.x = -_facing() * ult_back_speed  # 바라보는 방향의 반대로 도약 (방향은 그대로 유지)
	velocity.y = -ult_back_hop
	_play_anim_restart(&"ultimate_ready")


func _ult_ready_state(delta: float) -> void:
	velocity.y += gravity * delta
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, friction * delta)
	state_time_left -= delta
	if state_time_left <= 0.0:
		_start_ult_fire()


func _start_ult_fire() -> void:
	state = State.ULT_FIRE
	var anim_name: StringName = _play_anim_restart(&"ultimate_fire")
	state_time_left = _anim_length(anim_name, ult_fire_fallback_duration)
	var recoil_dir: float = -_facing() if recoil_backward else _facing()
	velocity.x = recoil_dir * ult_recoil_speed
	velocity.y = -ult_recoil_lift
	_fire_projectile()


func _ult_fire_state(delta: float) -> void:
	velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0, ult_recoil_decel * delta)
	state_time_left -= delta
	if state_time_left <= 0.0:
		ultimate_cooldown_left = ultimate_cooldown
		state = State.NORMAL


# 투사체는 캐릭터의 자식이 아니라 부모(메인 씬)에 생성해서, 캐릭터가 날아가도 따라가지 않게 함
func _fire_projectile() -> void:
	if ultimate_projectile == null:
		return  # 투사체 씬이 아직 없으면 애니메이션과 반동만 실행
	var proj := ultimate_projectile.instantiate()
	if "damage" in proj:
		proj.damage = _damage(ultimate_damage)
	if "direction" in proj:
		proj.direction = Vector2(_facing(), 0.0)
	get_parent().add_child(proj)
	if proj is Node2D:
		proj.global_position = global_position + Vector2(projectile_offset.x * _facing(), projectile_offset.y)


# ---------- 헬퍼 ----------
func _facing() -> float:
	return -1.0 if sprite.flip_h else 1.0


func _current_speed() -> float:
	return speed * (buff_speed_multiplier if buff_time_left > 0.0 else 1.0)


func _damage(base: float) -> float:
	return base * (buff_damage_multiplier if buff_time_left > 0.0 else 1.0)


# 애니메이션 길이(초). 애니메이션이 없으면 fallback 사용
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


# 이펙트 씬을 캐릭터 자식으로 생성 (바라보는 방향에 맞춰 좌우 반전). 생성한 노드를 돌려줌
func _spawn_effect(scene: PackedScene, damage: float, effect_lifetime: float) -> Node:
	if scene == null:
		return null  # 이펙트 씬이 아직 없으면 캐릭터 애니메이션만 재생
	var effect := scene.instantiate()
	if "damage" in effect:
		effect.damage = damage
	if effect_lifetime > 0.0 and "lifetime" in effect:
		effect.lifetime = effect_lifetime
	add_child(effect)
	if effect is Node2D:
		effect.scale.x = _facing()
	return effect


func _clear_effect() -> void:
	if is_instance_valid(_active_effect):
		_active_effect.queue_free()
	_active_effect = null


# primary 애니메이션이 없으면 fallback을, 둘 다 없으면 빈 이름을 돌려줌
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


# 같은 애니메이션이어도 처음부터 다시 재생. 실제로 재생한 애니메이션 이름을 돌려줌
func _play_anim_restart(primary: StringName, fallback: StringName = &"") -> StringName:
	var anim_name: StringName = _pick_anim(primary, fallback)
	if anim_name != &"":
		sprite.stop()
		sprite.play(anim_name)
	return anim_name
