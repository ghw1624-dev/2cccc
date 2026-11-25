extends CanvasLayer
# 스킬 / 궁극기 쿨타임 UI (Godot 4.x): 왼쪽 위 체력바 바로 아래에 E, R, T 칸을 보여줍니다.
# 칸은 코드가 만들어요. 씬에 이 스크립트만 붙이면 됩니다.
#
# 사용법: 메인 씬에 CanvasLayer 노드를 추가하고 이 스크립트를 붙이세요.
# "player" 그룹의 캐릭터(misa.gd)를 자동으로 찾아서 쿨타임을 읽어요.
#
# 칸의 모양
#   - 사용 가능: 초록 테두리, 숫자 없음
#   - 쿨타임 중: 회색 테두리, 어두운 가림막이 점점 줄어들고 남은 시간(초)이 숫자로 표시됨
#   - 쿨타임 중이지만 스택으로 바로 재사용 가능: 노란 테두리 (스킬1은 스택 1개, 궁극기는 스택 3개 필요)

@export var player_group: StringName = &"player"
@export var margin: Vector2 = Vector2(20, 60)       # 화면 왼쪽 위에서 떨어진 위치 (체력바 아래가 되도록 조절)
@export var slot_size: Vector2 = Vector2(56, 56)
@export var spacing: float = 8.0                    # 칸 사이 간격

# 직접 그린 아이콘이 있으면 넣으세요 (선택)
@export var dash_icon: Texture2D
@export var skill1_icon: Texture2D
@export var skill2_icon: Texture2D
@export var ultimate_icon: Texture2D

@export var ready_color: Color = Color(0.3, 0.8, 0.4)      # 사용 가능
@export var cooldown_color: Color = Color(0.45, 0.45, 0.45) # 쿨타임 중
@export var recast_color: Color = Color(1.0, 0.8, 0.2)     # 스택으로 재사용 가능

var _player: Node = null
var _container: Control
var _slots: Array[Dictionary] = []


func _ready() -> void:
	layer = 10

	_container = Control.new()
	_container.visible = false  # 플레이어를 찾기 전에는 숨김
	add_child(_container)

	# 각 칸이 읽을 미사의 변수 이름: 남은 쿨타임 / 전체 쿨타임 / 스택 재사용에 필요한 스택 수
	var configs: Array[Dictionary] = [
		{"key": "Q", "left": "dash_cooldown_left", "total": "dash_cooldown", "cost": "", "icon": dash_icon},
		{"key": "E", "left": "skill1_cooldown_left", "total": "skill1_cooldown", "cost": "skill1_recast_cost", "icon": skill1_icon},
		{"key": "R", "left": "skill2_cooldown_left", "total": "skill2_cooldown", "cost": "", "icon": skill2_icon},
		{"key": "T", "left": "ultimate_cooldown_left", "total": "ultimate_cooldown", "cost": "ultimate_recast_cost", "icon": ultimate_icon},
	]
	for i in configs.size():
		_slots.append(_build_slot(configs[i], i))


func _build_slot(cfg: Dictionary, index: int) -> Dictionary:
	var root := Control.new()
	root.position = margin + Vector2(index * (slot_size.x + spacing), 0.0)
	root.size = slot_size
	_container.add_child(root)

	# 배경 + 테두리
	var bg := Panel.new()
	bg.size = slot_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.85)
	style.border_color = ready_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", style)
	root.add_child(bg)

	# 아이콘 (선택)
	var icon_tex: Texture2D = cfg["icon"]
	if icon_tex != null:
		var icon := TextureRect.new()
		icon.texture = icon_tex
		icon.size = slot_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(icon)

	# 쿨타임 가림막: 위쪽부터 남은 비율만큼 덮고, 시간이 지날수록 줄어듦
	var cover := ColorRect.new()
	cover.color = Color(0.0, 0.0, 0.0, 0.6)
	cover.size = slot_size
	cover.visible = false
	root.add_child(cover)

	# 남은 시간 숫자 (가운데)
	var time_label := Label.new()
	time_label.size = slot_size
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.add_theme_font_size_override("font_size", 20)
	time_label.add_theme_color_override("font_outline_color", Color.BLACK)
	time_label.add_theme_constant_override("outline_size", 4)
	root.add_child(time_label)

	# 키 이름 (왼쪽 위 구석)
	var key_label := Label.new()
	key_label.text = cfg["key"]
	key_label.position = Vector2(5.0, 1.0)
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_outline_color", Color.BLACK)
	key_label.add_theme_constant_override("outline_size", 4)
	root.add_child(key_label)

	return {
		"left": cfg["left"], "total": cfg["total"], "cost": cfg["cost"],
		"style": style, "cover": cover, "time": time_label,
	}


func _process(_delta: float) -> void:
	# 플레이어가 없거나 사라졌으면 그룹에서 다시 찾기
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group)
	_container.visible = _player != null
	if _player == null:
		return

	var stacks = _player.get("stacks")
	for slot in _slots:
		var left = _player.get(slot["left"])
		var total = _player.get(slot["total"])
		if left == null or total == null:
			continue

		# 스택으로 쿨타임 없이 재사용할 수 있는지
		var can_recast: bool = false
		var cost_name: String = slot["cost"]
		if cost_name != "" and stacks != null:
			var cost = _player.get(cost_name)
			can_recast = cost != null and stacks >= cost

		var cover: ColorRect = slot["cover"]
		var time_label: Label = slot["time"]
		var style: StyleBoxFlat = slot["style"]
		if left > 0.0:
			var ratio: float = clampf(left / maxf(total, 0.001), 0.0, 1.0)
			cover.visible = true
			cover.size.y = slot_size.y * ratio
			time_label.text = "%.1f" % left if left < 10.0 else str(ceili(left))
			style.border_color = recast_color if can_recast else cooldown_color
		else:
			cover.visible = false
			time_label.text = ""
			style.border_color = ready_color
