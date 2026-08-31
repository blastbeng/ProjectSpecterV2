extends Node3D
## Match scene: assembles night environment, the first dressed room and the
## player spawn. Procedural building grows here iteration by iteration.

const PLAYER_SPAWN := Vector3(3.9, 0.1, 2.2)

var _hud: MatchHUD
var _player: PlayerController

func _ready() -> void:
	print("MATCH: scene ready")
	add_child(NightEnvironment.new())
	add_child(RoomBuilder.new())
	_player = PlayerController.new()
	_player.name = "Player"
	add_child(_player)
	_player.position = PLAYER_SPAWN
	# Face the window / counter side of the room.
	_player.rotation.y = deg_to_rad(-155.0)
	_hud = MatchHUD.new()
	add_child(_hud)


func _process(_delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_hud):
		_hud.prompt_label.text = _player.current_prompt()
		_hud.stamina_bar.value = _player.stamina_ratio()
		_hud.battery_bar.value = _player.flashlight.battery_ratio()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_player.try_interact()