extends Camera2D
# "player" 그룹의 캐릭터를 따라가는 카메라 (Godot 4.x)
# 멀리 있을수록 빠르게, 가까워질수록 느리게 다가갑니다.
#
# 사용법: 메인 씬에 Camera2D 노드를 추가하고 이 스크립트를 붙이세요.
# (캐릭터의 자식으로 넣지 말고 메인 씬 루트 바로 아래에 두세요.)

@export var player_group: StringName = &"player"
@export var follow_speed: float = 4.0     # 클수록 빠르게 따라붙음 (거리에 비례해 속도가 변함)
@export var min_speed: float = 20.0       # 아주 가까울 때 최소 이동 속도(px/s). 0이면 끝에서 한없이 느려짐
@export var snap_on_first_target: bool = true  # 플레이어를 처음 찾았을 때 카메라를 바로 그 위치로 이동

var target: Node2D = null


var _shake_strength: float = 0.0
var _shake_duration: float = 0.0
var _shake_time_left: float = 0.0


# 화면 흔들기: strength(px) 세기로 시작해서 duration(초) 동안 점점 약해지며 흔들림
func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_duration = duration
	_shake_time_left = duration


func _update_shake(delta: float) -> void:
	if _shake_time_left > 0.0:
		_shake_time_left = maxf(_shake_time_left - delta, 0.0)
		var ratio: float = _shake_time_left / maxf(_shake_duration, 0.001)
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * ratio
	elif offset != Vector2.ZERO:
		offset = Vector2.ZERO


func _process(delta: float) -> void:
	_update_shake(delta)
	# 대상이 없거나 사라졌으면 그룹에서 다시 찾기 (캐릭터가 생성된 뒤에도 자동으로 찾음)
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(player_group) as Node2D
		if target == null:
			return
		if snap_on_first_target:
			global_position = target.global_position
			return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	if dist < 0.01:
		return

	# 거리에 비례한 속도: 멀면 빠르고, 가까우면 느림
	var speed: float = max(dist * follow_speed, min_speed)
	var step: float = min(speed * delta, dist)  # 목표를 지나치지 않게 제한
	global_position += to_target / dist * step
