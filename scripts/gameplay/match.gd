extends Node3D
## Match scene: assembles night environment, the first dressed room and the
## player spawn. Procedural building grows here iteration by iteration.

const PLAYER_SPAWN := Vector3(1.2, 0.1, 3.8)

func _ready() -> void:
	print("MATCH: scene ready")
	add_child(NightEnvironment.new())
	add_child(RoomBuilder.new())
	var player := PlayerController.new()
	player.name = "Player"
	add_child(player)
	player.position = PLAYER_SPAWN
	player.rotation.y = deg_to_rad(-35.0)  # face the table + counter