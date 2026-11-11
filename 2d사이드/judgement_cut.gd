extends Node2D
# 저지먼트 컷 이펙트 (적 추적 + 생성용 씬 스크립트)
# 씬 구조: JudgementCut (Node2D, 이 스크립트) └ AnimatedSprite2D ("judgement cut" 애니메이션이 든 SpriteFrames)
# vergil.gd 가 적마다 하나씩 생성하고, target 을 지정해 줍니다.

@export var animation_name: StringName = &"judgement cut"
## 데미지가 들어가는 프레임 번호. -1이면 애니메이션이 끝날 때 한 번에 들어감
@export var hit_frame: int = -1

var target: Node2D = null
var damage: float = 0.0

var _hit_done: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	z_index = 100  # 적보다 위에 보이게
	_follow_target()
	sprite.animation_finished.connect(_on_finished)
	sprite.frame_changed.connect(_on_frame_changed)
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
	else:
		push_warning("JudgementCut: '%s' 애니메이션을 찾을 수 없습니다." % animation_name)
		_apply_damage()
		queue_free()


func _process(_delta: float) -> void:
	# 적이 어디로 움직이든 히트박스 정중앙을 계속 따라감
	_follow_target()


func _follow_target() -> void:
	if is_instance_valid(target):
		global_position = _hitbox_center(target)


func _on_frame_changed() -> void:
	if hit_frame >= 0 and sprite.frame == hit_frame:
		_apply_damage()


func _on_finished() -> void:
	_apply_damage()  # hit_frame 을 못 찍었거나 -1 인 경우 여기서 처리
	queue_free()


func _apply_damage() -> void:
	if _hit_done:
		return
	_hit_done = true
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(damage)


# 적의 히트박스(CollisionShape2D) 정중앙. Area2D 아래에 있는 것을 우선, 없으면 첫 번째 것, 그것도 없으면 적 위치
static func _hitbox_center(enemy: Node2D) -> Vector2:
	var shapes := enemy.find_children("*", "CollisionShape2D", true, false)
	var fallback: CollisionShape2D = null
	for s in shapes:
		var cs := s as CollisionShape2D
		if cs == null or cs.shape == null:
			continue
		if cs.get_parent() is Area2D:
			return cs.global_position
		if fallback == null:
			fallback = cs
	if fallback != null:
		return fallback.global_position
	return enemy.global_position
