extends Node2D
# 땅에서 솟아오르며 플레이어 쪽으로 빠르게 달려가는 투사체 (Godot 4.x)
#
# 이 투사체는 앞으로 이동하면서 일정 간격마다 "솟아오름" 이펙트 씬을 바닥에 생성합니다.
# 피해는 솟아오름 이펙트의 Hitbox(skill_effect.gd)가 줍니다. 한 번 지나가는 동안 같은 대상은 한 번만 맞아요.
#
# 일반 투사체와 S! 투사체는 같은 스크립트로 씬만 따로 만들고 인스펙터 값을 다르게 설정합니다.
#   일반: Speed 500 / Eruption Spacing 70  / Eruption Scale 1.0
#   S!  : Speed 900 / Eruption Spacing 110 / Eruption Scale 1.8  (더 크고 빠르게)
#
# 씬 구조: GroundWave (Node2D) <- 이 스크립트. 머리 부분 그림 등을 보이고 싶으면 자식으로 추가하면 같이 움직여요.

@export var eruption_scene: PackedScene           # 솟아오름 이펙트 씬 (skill_effect.gd + AnimatedSprite2D + Hitbox)
@export var eruption_scale: float = 1.0           # 솟아오름 이펙트 크기 배율 (S!는 크게)
@export var speed: float = 500.0                  # 달려가는 속도(px/s)
@export var travel_distance: float = 900.0        # 이만큼 달려가면 사라짐
@export var eruption_spacing: float = 70.0        # 이 간격(px)마다 솟아오름 1번 생성
@export var damage: float = 8.0                   # 보스가 발사할 때 덮어씀
@export var direction: float = 1.0                # 보스가 발사할 때 덮어씀 (1 = 오른쪽, -1 = 왼쪽)
@export var target_group: StringName = &"player"  # 보스가 발사할 때 덮어씀

@export var flip_with_direction: bool = true      # true면 왼쪽으로 달릴 때 솟아오름 그림을 좌우반전 (그림은 오른쪽 방향 기준으로 그려주세요)

# 바닥에 맞추기: 위에서 아래로 선을 쏴서 바닥을 찾고, 거기서 솟아오르게 함
@export var snap_to_ground: bool = true
@export_flags_2d_physics var ground_mask: int = 1  # 바닥(맵)이 속한 레이어
@export var ground_ray_up: float = 60.0
@export var ground_ray_down: float = 300.0
@export var skip_when_no_ground: bool = true       # 바닥이 없는 곳(구덩이 등)에서는 솟아오르지 않음

var _traveled: float = 0.0
var _since_spawn: float = 0.0
var _first_frame: bool = true
var _hit_registry: Array = []  # 이번 투사체의 솟아오름들이 공유하는 '이미 맞은 대상' 목록 (한 번만 피해)


func _ready() -> void:
	# 왼쪽으로 달리면 투사체 머리 그림 등 자식 노드도 같이 좌우반전
	if flip_with_direction and direction < 0.0:
		scale.x *= -1.0


func _physics_process(delta: float) -> void:
	# 시작 위치에서 첫 솟아오름
	if _first_frame:
		_first_frame = false
		_spawn_eruption(global_position.x)

	var step: float = minf(speed * delta, travel_distance - _traveled)
	global_position.x += direction * step
	_traveled += step
	_since_spawn += step

	# 빠르게 달려서 한 프레임에 간격을 여러 번 넘어도 빠짐없이 같은 간격으로 생성
	while _since_spawn >= eruption_spacing:
		_since_spawn -= eruption_spacing
		_spawn_eruption(global_position.x - direction * _since_spawn)

	if _traveled >= travel_distance:
		queue_free()


func _spawn_eruption(x: float) -> void:
	if eruption_scene == null:
		return
	var pos := Vector2(x, global_position.y)
	if snap_to_ground:
		var ground_pos: Variant = _find_ground(pos)
		if ground_pos == null:
			if skip_when_no_ground:
				return
		else:
			pos = ground_pos

	var e := eruption_scene.instantiate()
	if "damage" in e:
		e.damage = damage
	if "target_group" in e:
		e.target_group = target_group
	if "_hit_targets" in e:
		e._hit_targets = _hit_registry  # 같은 목록을 공유해서 한 번 지나가는 동안 대상당 한 번만 피해
	if e is Node2D:
		if flip_with_direction and direction < 0.0:
			e.scale.x *= -1.0  # 왼쪽으로 달릴 때 솟아오름 그림과 판정을 좌우반전 (그림은 오른쪽 기준)
		e.scale *= eruption_scale  # 씬에서 정해 둔 크기에 배율만 곱함
	# 투사체가 사라져도 솟아오름 애니메이션은 끝까지 재생되도록 부모(메인 씬)에 생성
	get_parent().add_child(e)
	if e is Node2D:
		e.global_position = pos


# pos 근처에서 아래로 선을 쏴서 바닥 위치를 찾음 (없으면 null)
func _find_ground(pos: Vector2) -> Variant:
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(
		pos + Vector2(0.0, -ground_ray_up),
		pos + Vector2(0.0, ground_ray_down),
		ground_mask
	)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	return hit["position"]
