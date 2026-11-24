extends CanvasLayer
# 보스 체력바 HUD (Godot 4.x): 화면 위쪽 가운데에 보스 이름과 체력바를 표시합니다.
# 체력바와 이름 글자는 코드가 만들어요. 씬에 이 스크립트만 붙이면 됩니다.
#
# 사용법: 메인 씬에 CanvasLayer 노드를 추가하고 이 스크립트를 붙이세요.
# "boss" 그룹의 보스(boss.gd)를 자동으로 찾아서 health_changed 시그널에 연결합니다.
# 이름은 보스 씬 인스펙터의 Boss Name 에서 바꿀 수 있어요. 보스가 없거나 사라지면 체력바도 숨겨져요.

@export var boss_group: StringName = &"boss"
@export var bar_size: Vector2 = Vector2(500, 26)
@export var margin_top: int = 24                         # 화면 위쪽에서 떨어진 거리
@export var fill_color: Color = Color(0.9, 0.4, 0.1)     # 체력바 색
@export var smooth_time: float = 0.2                     # 체력이 변할 때 부드럽게 줄어드는 시간(초)

var _boss: Node = null
var _box: VBoxContainer
var _name_label: Label
var _bar: ProgressBar
var _tween: Tween


func _ready() -> void:
	layer = 10

	_box = VBoxContainer.new()
	_box.custom_minimum_size = Vector2(bar_size.x, 0)
	_box.visible = false  # 보스를 찾기 전에는 숨김
	add_child(_box)
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, margin_top)

	# 보스 이름
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 5)
	_box.add_child(_name_label)

	# 체력바
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = bar_size
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
	_box.add_child(_bar)


func _process(_delta: float) -> void:
	# 보스가 없거나 사라졌으면 그룹에서 다시 찾기
	if is_instance_valid(_boss):
		return
	_box.visible = false
	_boss = get_tree().get_first_node_in_group(boss_group)
	if _boss == null:
		return
	if _boss.has_signal("health_changed") and not _boss.is_connected("health_changed", _on_health_changed):
		_boss.connect("health_changed", _on_health_changed)
	if _boss.has_signal("engaged") and not _boss.is_connected("engaged", _on_boss_engaged):
		_boss.connect("engaged", _on_boss_engaged)
	# 연결 시점의 현재 체력과 이름을 바로 반영
	var current = _boss.get("health")
	var maximum = _boss.get("max_health")
	if current != null and maximum != null:
		_bar.max_value = maximum
		_bar.value = current
	_update_name()
	# 보스가 플레이어를 감지하기 전에는 숨김. 이미 감지한 상태면 바로 표시
	_box.visible = _boss.get("is_engaged") == true


func _on_health_changed(current: float, maximum: float) -> void:
	_bar.max_value = maximum
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_bar, "value", current, smooth_time)
	_update_name()


# 보스가 플레이어를 처음 감지하면 체력바 표시
func _on_boss_engaged() -> void:
	_box.visible = true


func _update_name() -> void:
	var boss_name = _boss.get("boss_name")
	_name_label.text = str(boss_name) if boss_name != null else "보스"
