extends Node2D
# 궁극기 파티클 이펙트 (Godot 4.x) - 눈에 보이는 효과만 있고 피해/판정은 없습니다.
# 이미지 없이 코드로 파티클을 만들어서, 씬에 이 스크립트만 붙이면 바로 나옵니다.
#
# 씬 만들기: Node2D 하나를 루트로 만들고 이 스크립트를 붙인 뒤 ultimate_effect.tscn으로 저장
# misa의 Ultimate Ready Effect / Ultimate Fire Effect 두 칸에 같은 씬을 넣으면 됩니다.
# (misa.gd가 생성할 때 style을 자동으로 CHARGE / BURST로 정해줍니다)
#
# CHARGE: 준비모션 동안 캐릭터 주변에서 안쪽으로 모여드는 파티클 (캐릭터를 따라다님)
# BURST : 발사하는 순간 사방으로 터지는 파티클

enum Style { CHARGE, BURST }

@export var style: Style = Style.CHARGE
@export var duration: float = 0.5          # CHARGE: 모이는 시간(misa.gd가 준비 시간에 맞춰 덮어씀)
@export var color: Color = Color(1.0, 0.8, 0.3)
@export var radius: float = 60.0           # CHARGE: 모이기 시작하는 반경
@export var particle_amount: int = 40
@export var particle_scale: float = 4.0    # 입자 크기(픽셀)


func _ready() -> void:
	z_index = 10  # 캐릭터 앞에 보이도록
	var p := CPUParticles2D.new()
	p.amount = particle_amount
	p.one_shot = true
	p.gravity = Vector2.ZERO
	p.spread = 180.0
	p.scale_amount_min = particle_scale * 0.5
	p.scale_amount_max = particle_scale

	# 색이 점점 투명해지며 사라지게
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g

	var life: float
	if style == Style.CHARGE:
		life = max(duration, 0.1)
		p.lifetime = life
		p.explosiveness = 0.0
		p.local_coords = true  # 캐릭터가 움직여도 같이 따라감
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = radius
		p.initial_velocity_min = 0.0
		p.initial_velocity_max = 0.0
		# 음수 radial 가속도 = 중심을 향해 모여듦 (거리 = 0.5 * a * t² = radius)
		var accel: float = -2.0 * radius / (life * life)
		p.radial_accel_min = accel
		p.radial_accel_max = accel
	else:
		life = 0.4
		p.lifetime = life
		p.explosiveness = 0.95
		p.local_coords = false
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 6.0
		p.initial_velocity_min = 150.0
		p.initial_velocity_max = 450.0
		p.damping_min = 200.0
		p.damping_max = 400.0

	add_child(p)
	p.emitting = true
	# 파티클이 다 사라진 뒤 이펙트 제거
	get_tree().create_timer(life + 0.3).timeout.connect(queue_free)
