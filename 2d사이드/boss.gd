extends CharacterBody2D
# 보스 몬스터: "player" 그룹을 감지하면 플레이어 쪽으로 방향을 틀고 다가갑니다. (Godot 4.x, AnimatedSprite2D 기준)
#
# 씬 구조 (이름을 맞춰주세요):
# Boss (CharacterBody2D)  <- 이 스크립트
# ├─ CollisionShape2D
# ├─ AnimatedSprite2D     <- 저장해둔 애니메이션(SpriteFrames)이 있는 노드
# └─ DetectionArea (Area2D)
#    └─ CollisionShape2D  <- 감지 범위(원형 추천)
#
# 주의: DetectionArea의 body_entered / body_exited 시그널은 에디터(노드 탭)에서 연결한 상태입니다.
#       그래서 _ready()에서 다시 connect 하지 않습니다.

@export var attack_animation: StringName = &"attack"  # 공격 애니메이션 이름
@export var walk_animation: StringName = &"walk"      # 이동 애니메이션 이름 (없으면 attack을 대신 재생)
@export var idle_animation: StringName = &"idle"      # 플레이어가 범위를 벗어나면 재생(없으면 무시)
@export var player_group: StringName = &"player"      # 감지할 그룹 이름

@export var move_speed: float = 120.0     # 이동 속도(px/s)
@export var gravity: float = 980.0
@export var stop_distance: float = 60.0   # 이 거리 안으로 들어오면 멈추고 공격 (가로 거리 기준)
@export var sprite_faces_right: bool = true  # 스프라이트 원본 그림이 오른쪽을 보고 있으면 true, 왼쪽이면 false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

var targets: Array[Node2D] = []


func _ready() -> void:
	_play(idle_animation)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	var target := _get_closest_target()
	if target == null:
		# 감지된 플레이어가 없으면 멈추고 대기
		velocity.x = 0.0
		_play(idle_animation)
		move_and_slide()
		return

	var dx: float = target.global_position.x - global_position.x

	# 1) 플레이어 쪽으로 모습(스프라이트) 돌리기
	if dx != 0.0:
		var target_is_right: bool = dx > 0.0
		anim.flip_h = (not target_is_right) if sprite_faces_right else target_is_right

	# 2) 멀면 이동, 가까우면 멈추고 공격
	if absf(dx) > stop_distance:
		velocity.x = signf(dx) * move_speed
		_play(walk_animation if anim.sprite_frames.has_animation(walk_animation) else attack_animation)
	else:
		velocity.x = 0.0
		_play(attack_animation)

	move_and_slide()


# 감지 범위 안의 플레이어 중 가장 가까운 대상
func _get_closest_target() -> Node2D:
	var closest: Node2D = null
	var best: float = INF
	for t in targets:
		if not is_instance_valid(t):
			continue
		var d: float = global_position.distance_to(t.global_position)
		if d < best:
			best = d
			closest = t
	return closest


# 해당 애니메이션이 있을 때만, 같은 애니메이션이 이미 재생 중이면 다시 시작하지 않음
func _play(anim_name: StringName) -> void:
	if not anim.sprite_frames.has_animation(anim_name):
		return
	if anim.animation != anim_name or not anim.is_playing():
		anim.play(anim_name)


# 에디터에서 연결된 시그널 함수
func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group(player_group) and not targets.has(body):
		targets.append(body)


func _on_detection_area_body_exited(body: Node2D) -> void:
	targets.erase(body)
