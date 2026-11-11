extends CanvasLayer
# 왼쪽 상단 체력바 HUD (Godot 4.x)
# 체력바(ProgressBar)와 "체력: 70 / 100" 글자를 코드로 만들어서, 씬에 이 스크립트만 붙이면 됩니다.
#
# 사용법: 메인 씬에 CanvasLayer 노드를 추가하고 이 스크립트를 붙이세요.
# "player" 그룹의 캐릭터를 자동으로 찾아서 health_changed 시그널에 연결합니다.
# (캐릭터 선택창에서 나중에 생성되는 캐릭터도 자동으로 찾아요)

@export var player_group: StringName = &"player"
@export var margin: Vector2 = Vector2(20, 20)          # 화면 왼쪽 위에서 떨어진 거리
@export var bar_size: Vector2 = Vector2(260, 28)
@export var fill_color: Color = Color(0.85, 0.2, 0.2)  # 체력바 색
@export var smooth_time: float = 0.2                   # 체력이 변할 때 부드럽게 줄어드는 시간(초)

var _player: Node = null
var _bar: ProgressBar
var _label: Label
var _tween: Tween


func _ready() -> void:
	layer = 10  # 다른 화면 요소 위에 표시

	_bar = ProgressBar.new()
	_bar.position = margin
	_bar.size = bar_size
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", fill)
	add_child(_bar)

	# 체력 숫자 글자 (체력바 위에 겹쳐서 표시)
	_label = Label.new()
	_label.position = margin
	_label.size = bar_size
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_update_label(100.0, 100.0)


func _process(_delta: float) -> void:
	# 플레이어가 없거나 사라졌으면 그룹에서 다시 찾기
	if is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group(player_group)
	if _player == null:
		return
	if _player.has_signal("health_changed") and not _player.is_connected("health_changed", _on_health_changed):
		_player.connect("health_changed", _on_health_changed)
	# 연결 시점의 현재 체력을 바로 반영
	var current = _player.get("health")
	var maximum = _player.get("max_health")
	if current != null and maximum != null:
		_bar.max_value = maximum
		_bar.value = current
		_update_label(current, maximum)


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_bar, "value", current, smooth_time)  # 늘거나 줄 때 부드럽게
	_update_label(current, maximum)


func _update_label(current: float, maximum: float) -> void:
	_label.text = "체력: %d / %d" % [roundi(current), roundi(maximum)]
