extends CharacterBody2D
# 보스 몬스터: "player" 그룹을 감지하면 저장해둔 애니메이션을 재생합니다. (Godot 4.x)
#
# 씬 구조 (이름을 맞춰주세요):
# Boss (CharacterBody2D)  <- 이 스크립트
# ├─ AnimationPlayer      <- 저장해둔 애니메이션이 있는 노드
# ├─ Sprite2D / AnimatedSprite2D
# └─ DetectionArea (Area2D)
#    └─ CollisionShape2D  <- 감지 범위(원형 추천)

@export var detect_animation: StringName = &"detect"  # 감지 시 재생할 애니메이션 이름
@export var idle_animation: StringName = &"idle"      # 플레이어가 범위를 벗어나면 재생(없으면 무시)
@export var player_group: StringName = &"player"      # 감지할 그룹 이름

@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var detection_area: Area2D = $DetectionArea

var targets: Array[Node2D] = []

func _ready() -> void:
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	if anim.has_animation(idle_animation):
		anim.play(idle_animation)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(player_group):
		return
	targets.append(body)
	# 이미 재생 중이면 처음부터 다시 시작하지 않음
	if anim.current_animation != detect_animation:
		if anim.has_animation(detect_animation):
			anim.play(detect_animation)
		else:
			push_warning("애니메이션 '%s'을(를) 찾을 수 없어요. detect_animation 이름을 확인하세요." % detect_animation)

func _on_body_exited(body: Node2D) -> void:
	targets.erase(body)
	# 범위 안에 플레이어가 아무도 없으면 대기 상태로 복귀
	if targets.is_empty() and anim.has_animation(idle_animation):
		anim.play(idle_animation)
