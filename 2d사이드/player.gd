extends CharacterBody2D

# 상태: 일반 / 대시 / 방어
enum State { NORMAL, DASH, GUARD }

# 이동 관련 변수
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0
@export var friction: float = 1600.0  # 멈출 때 감속량(px/s²) - 작을수록 더 오래 미끄러짐

# 대시 관련 변수
@export var dash_distance: float = 200.0  # 대시로 이동할 총 거리(px)
@export var dash_duration: float = 0.15   # 대시 지속 시간(초) - 짧을수록 빠름
@export var dash_cooldown: float = 0.5    # 재사용 대기시간(초)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var state: State = State.NORMAL
var dash_time_left: float = 0.0
var dash_cooldown_left: float = 0.0
var dash_dir: float = 1.0


func _ready() -> void:
	# Input Map에 액션이 없으면 자동 등록 (dash = Q, guard = E)
	_register_key_action("dash", KEY_Q)
	_register_key_action("guard", KEY_E)


func _register_key_action(action: StringName, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func _physics_process(delta: float) -> void:
	dash_cooldown_left = max(dash_cooldown_left - delta, 0.0)

	match state:
		State.NORMAL:
			_normal_state(delta)
		State.DASH:
			_dash_state(delta)
		State.GUARD:
			_guard_state(delta)

	move_and_slide()


# ---------- 일반 상태 (이동/점프) ----------
func _normal_state(delta: float) -> void:
	# 중력 적용 (땅에 닿아있지 않을 때)
	if not is_on_floor():
		velocity.y += gravity * delta

	# 점프 입력
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	# 좌우 이동 입력
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0:
		velocity.x = direction * speed
		# 캐릭터 방향에 따라 스프라이트 좌우 반전
		sprite.flip_h = direction < 0
	else:
		# 입력 없으면 마찰로 서서히 감속 (살짝 미끄러짐)
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	# 대시 시작 (Q)
	if Input.is_action_just_pressed("dash") and dash_cooldown_left <= 0.0:
		_start_dash(direction)
		return

	# 방어 시작 (E 누르고 있는 동안, 땅 위에서만)
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


# ---------- 대시 상태 ----------
func _start_dash(input_dir: float) -> void:
	# 방향키를 누르고 있으면 그 방향, 아니면 바라보는 방향
	if input_dir != 0.0:
		dash_dir = sign(input_dir)
	else:
		dash_dir = -1.0 if sprite.flip_h else 1.0
	sprite.flip_h = dash_dir < 0
	dash_time_left = dash_duration
	state = State.DASH
	_play_anim("dash")


func _dash_state(delta: float) -> void:
	# 시작 속도에서 0까지 선형으로 줄어듦 → 총 이동거리 = 시작속도 * 시간 / 2 = dash_distance
	var start_speed: float = 2.0 * dash_distance / dash_duration
	var ratio: float = clamp(dash_time_left / dash_duration, 0.0, 1.0)
	velocity.x = dash_dir * start_speed * ratio
	velocity.y = 0.0  # 대시 중에는 중력 무시

	dash_time_left -= delta
	if dash_time_left <= 0.0:
		velocity.x = 0.0
		dash_cooldown_left = dash_cooldown
		state = State.NORMAL


# ---------- 방어 상태 ----------
func _guard_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	velocity.x = move_toward(velocity.x, 0, friction * delta)

	# E를 떼거나 공중에 뜨면 방어 해제
	if not Input.is_action_pressed("guard") or not is_on_floor():
		state = State.NORMAL


# ---------- 애니메이션 헬퍼 ----------
# 해당 이름의 애니메이션이 있을 때만, 이미 재생 중이 아닐 때만 재생
func _play_anim(anim: StringName) -> void:
	if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
		sprite.play(anim)
