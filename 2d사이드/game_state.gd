extends Node
# 오토로드(싱글톤) 스크립트: 씬이 바뀌어도 선택 내용을 유지합니다. (Godot 4.x)
# 프로젝트 설정 > 오토로드 에서 이 스크립트를 "GameState" 이름으로 등록하세요.

const MAIN_SCENE_PATH := "res://main.tscn"

# 캐릭터 목록: { "id": "캐릭터 씬 경로" }
# id는 캐릭터 선택창의 버튼 이름과 똑같이 맞춰야 합니다. 경로는 실제 씬 경로로 바꿔주세요.
const CHARACTERS: Dictionary = {
	"dimo": "res://player.tscn",
	"misa": "res://misa.tscn",
	"vergil": "res://vergil.tscn",
}

# 선택 내용 (나중에 맵, 아이템도 여기에 등록)
var selected_character: String = ""
var selected_map: String = ""            # 나중에 맵 선택용
var selected_items: Array[String] = []   # 나중에 아이템 선택용


func select_character(id: String) -> void:
	if CHARACTERS.has(id):
		selected_character = id
	else:
		push_warning("CHARACTERS에 '%s'가 없어요. 버튼 이름과 id를 확인하세요." % id)


func get_character_scene() -> PackedScene:
	if selected_character == "" or not CHARACTERS.has(selected_character):
		return null
	return load(CHARACTERS[selected_character]) as PackedScene


func can_start() -> bool:
	# 나중에 맵/아이템도 필수라면 여기에 조건을 추가하세요.
	return selected_character != ""


func start_game() -> void:
	if can_start():
		get_tree().change_scene_to_file(MAIN_SCENE_PATH)
