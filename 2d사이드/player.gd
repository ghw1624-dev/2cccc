extends CharacterBody2D

# 이동 관련 변수
@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 980.0

func _physics_process(delta: float) -> void:
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
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		# 입력 없으면 부드럽게 감속 (원하면 즉시 0으로 바꿔도 됨)
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
