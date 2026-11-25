extends Area2D
# 저지먼트 컷 엔드: 생성되고 delay_frames 프레임 뒤에 애니메이션 재생 + 히트박스 데미지
# 씬 구조: JudgementCutEnd (Area2D) ├ AnimatedSprite2D ├ Hitbox (CollisionShape2D)

@export var animation_name: StringName = &"judgement cut end"
@export var delay_frames: int = 2   # 생성 후 이 프레임(물리 프레임) 수가 지나면 재생
@export var hit_frame: int = 0      # 데미지 프레임 번호. -1이면 애니메이션 끝날 때
var damage: float = 0.0

var _hit_done: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	z_index = 100
	monitorable = false
	sprite.hide()
	sprite.animation_finished.connect(_on_finished)
	sprite.frame_changed.connect(_on_frame_changed)

	for i in delay_frames:
		await get_tree().physics_frame

	sprite.show()
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		sprite.play(animation_name)
		if hit_frame == 0:
			_apply_hit()
	else:
		push_warning("JudgementCutEnd: '%s' 애니메이션을 찾을 수 없습니다." % animation_name)
		await _apply_hit()
		queue_free()


func _on_frame_changed() -> void:
	if hit_frame > 0 and sprite.frame == hit_frame:
		_apply_hit()


func _on_finished() -> void:
	await _apply_hit()
	queue_free()


func _apply_hit() -> void:
	if _hit_done:
		return
	_hit_done = true
	await get_tree().physics_frame
	var found: Array[Node] = []
	for n in get_overlapping_bodies():
		_collect_enemy(n, found)
	for n in get_overlapping_areas():
		_collect_enemy(n, found)
	for enemy in found:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage)


func _collect_enemy(node: Node, out: Array[Node]) -> void:
	var n: Node = node
	while n != null:
		if n.is_in_group("enemy"):
			if not out.has(n):
				out.append(n)
			return
		n = n.get_parent()
