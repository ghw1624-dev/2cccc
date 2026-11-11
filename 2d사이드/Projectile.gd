extends Area2D
# 궁극기 투사체 (Godot 4.x)
#
# 투사체 씬 구조:
# Projectile (Area2D)         <- 이 스크립트
# ├─ AnimatedSprite2D         <- 투사체 애니메이션 (선택, 이름은 projectile_animation)
# └─ CollisionShape2D         <- 판정 범위

@export var speed: float = 700.0
@export var damage: float = 50.0               # 캐릭터 스크립트가 발사할 때 덮어씀
@export var lifetime: float = 2.0              # 이 시간이 지나면 사라짐
@export var target_group: StringName = &"enemy"
@export var owner_group: StringName = &"player"  # 이 그룹은 무시 (발사한 캐릭터에 맞지 않도록)
@export var destroy_on_hit: bool = true        # 대상에 맞으면 사라짐 (false면 관통)
@export var destroy_on_world: bool = true      # 벽/바닥에 닿으면 사라짐
@export var projectile_animation: StringName = &"default"

var direction: Vector2 = Vector2.RIGHT         # 캐릭터 스크립트가 발사할 때 덮어씀

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# 발사 방향으로 회전 (마우스 방향 조준). 그림은 오른쪽을 향한 상태를 기준으로 그려주세요.
	rotation = direction.angle()
	if direction.x < 0.0:
		scale.y = -1.0  # 왼쪽으로 쏠 때 그림이 뒤집혀 보이지 않게 위아래 반전
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(projectile_animation):
		sprite.play(projectile_animation)
	await get_tree().create_timer(lifetime).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(owner_group):
		return
	if body.is_in_group(target_group):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if destroy_on_hit:
			queue_free()
	elif destroy_on_world:
		queue_free()
