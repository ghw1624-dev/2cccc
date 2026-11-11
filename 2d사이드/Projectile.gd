extends Area2D
# 궁극기 투사체 (Godot 4.x)
#
# 투사체 씬 구조:
# Projectile (Area2D)         <- 이 스크립트
# ├─ AnimatedSprite2D         <- 투사체 애니메이션 (선택, 이름은 projectile_animation)
# └─ CollisionShape2D         <- 판정 범위
# (잔상 파티클은 코드가 자동으로 만들어 줍니다)

@export var speed: float = 700.0
@export var damage: float = 50.0               # 캐릭터 스크립트가 발사할 때 덮어씀
@export var lifetime: float = 2.0              # 이 시간이 지나면 사라짐
@export var target_group: StringName = &"enemy"
@export var owner_group: StringName = &"player"  # 이 그룹은 무시 (발사한 캐릭터에 맞지 않도록)
@export var destroy_on_hit: bool = true        # 대상에 맞으면 사라짐 (false면 관통)
@export var destroy_on_world: bool = true      # 벽/바닥에 닿으면 사라짐
@export var projectile_animation: StringName = &"default"

# 잔상(GPU 파티클)
@export var trail_enabled: bool = true
@export var trail_color: Color = Color(1.0, 0.7, 0.3)
@export var trail_amount: int = 40             # 잔상 입자 수 (많을수록 촘촘함)
@export var trail_lifetime: float = 0.4        # 잔상이 남아 있는 시간(초)
@export var trail_size: float = 1.0            # 잔상 입자 크기 배율

var direction: Vector2 = Vector2.RIGHT         # 캐릭터 스크립트가 발사할 때 덮어씀

@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

var _dead: bool = false
var _trail: GPUParticles2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# 발사 방향으로 회전 (마우스 방향 조준). 그림은 오른쪽을 향한 상태를 기준으로 그려주세요.
	rotation = direction.angle()
	if direction.x < 0.0:
		scale.y = -1.0  # 왼쪽으로 쏠 때 그림이 뒤집혀 보이지 않게 위아래 반전
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(projectile_animation):
		sprite.play(projectile_animation)
	if trail_enabled:
		_create_trail()
	get_tree().create_timer(lifetime).timeout.connect(_destroy)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if _dead or body.is_in_group(owner_group):
		return
	if body.is_in_group(target_group):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if destroy_on_hit:
			_destroy()
	elif destroy_on_world:
		_destroy()


# 잔상 GPU 파티클: 투사체가 지나간 자리에 입자가 남았다가 점점 작아지며 사라짐
func _create_trail() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.gravity = Vector3.ZERO
	mat.scale_min = trail_size
	mat.scale_max = trail_size

	# 색이 점점 투명해지게
	var grad := Gradient.new()
	grad.set_color(0, trail_color)
	grad.set_color(1, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp

	# 크기가 점점 작아지게
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	mat.scale_curve = curve_tex

	# 이미지 없이 쓰는 부드러운 동그란 점 텍스처
	var dot := Gradient.new()
	dot.set_color(0, Color.WHITE)
	dot.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = dot
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 32
	tex.height = 32

	_trail = GPUParticles2D.new()
	_trail.process_material = mat
	_trail.texture = tex
	_trail.amount = trail_amount
	_trail.lifetime = trail_lifetime
	_trail.local_coords = false          # 입자가 투사체를 따라오지 않고 지나간 자리에 남음
	_trail.show_behind_parent = true     # 투사체 그림 뒤에 그려짐
	_trail.emitting = true
	add_child(_trail)


func _destroy() -> void:
	if _dead:
		return
	_dead = true
	set_deferred("monitoring", false)
	_finish_destroy.call_deferred()


func _finish_destroy() -> void:
	# 남은 잔상이 갑자기 사라지지 않도록 부모로 옮겨서 자연스럽게 끝날 때까지 둠
	if is_instance_valid(_trail):
		_trail.emitting = false
		_trail.reparent(get_parent())
		get_tree().create_timer(trail_lifetime + 0.2).timeout.connect(_trail.queue_free)
	queue_free()
