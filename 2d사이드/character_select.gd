extends Control
# 캐릭터 선택창 (Godot 4.x)
#
# 씬 구조:
# CharacterSelect (Control)  <- 이 스크립트
# ├─ CharacterButtons (HBoxContainer)
# │   ├─ Character1 (Button)   <- 버튼 이름 = GameState.CHARACTERS의 id
# │   └─ Character2 (Button)
# ├─ SelectedLabel (Label)     <- 선택한 캐릭터 표시 (선택 사항)
# └─ StartButton (Button)      <- 시작 버튼

@onready var buttons_box: Container = $CharacterButtons
@onready var start_button: Button = $StartButton
@onready var selected_label: Label = $SelectedLabel

var button_group := ButtonGroup.new()


func _ready() -> void:
	for child in buttons_box.get_children():
		if child is Button:
			var btn: Button = child
			btn.toggle_mode = true          # 눌린 상태로 선택 표시
			btn.button_group = button_group
			btn.pressed.connect(_on_character_pressed.bind(btn.name))

	start_button.pressed.connect(_on_start_pressed)
	_refresh()


func _on_character_pressed(id: String) -> void:
	GameState.select_character(id)  # 등록만 하고, 씬 이동은 시작 버튼에서
	_refresh()


func _on_start_pressed() -> void:
	GameState.start_game()


func _refresh() -> void:
	start_button.disabled = not GameState.can_start()
	selected_label.text = "선택: " + (GameState.selected_character if GameState.selected_character != "" else "없음")
