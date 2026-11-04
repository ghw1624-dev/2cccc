extends Node2D
# 메인 씬 루트에 붙이는 스크립트: 선택한 캐릭터를 생성해서 배치합니다. (Godot 4.x)
#
# 씬 구조:
# Main (Node2D)  <- 이 스크립트
# ├─ PlayerSpawn (Marker2D)   <- 캐릭터가 나타날 위치
# └─ ... (맵, 보스 등)

# 선택창을 거치지 않고 main.tscn을 바로 실행해 테스트할 때 쓸 캐릭터 (비워두면 생성 안 함)
@export var default_character_scene: PackedScene

@onready var spawn_point: Marker2D = $PlayerSpawn


func _ready() -> void:
	var scene: PackedScene = GameState.get_character_scene()
	if scene == null:
		scene = default_character_scene
	if scene == null:
		push_warning("생성할 캐릭터가 없어요. 선택창을 거쳐 오거나 default_character_scene을 지정하세요.")
		return

	var player := scene.instantiate()
	add_child(player)
	if player is Node2D:
		player.global_position = spawn_point.global_position
