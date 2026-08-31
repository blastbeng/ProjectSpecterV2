extends Node3D
## Match scene: assembles night environment, the first dressed room and the
## player spawn. Procedural building grows here iteration by iteration.

const PLAYER_SPAWN := Vector3(2.9, 0.1, 4.1)
const HOUSE_SEED := 20260831

var _hud: MatchHUD
var _player: PlayerController
var _demo_avatar: InvestigatorAvatar

func _ready() -> void:
	print("MATCH: scene ready, house seed %d" % HOUSE_SEED)
	add_child(NightEnvironment.new())
	var house := HouseBuilder.new()
	house.seed_value = HOUSE_SEED
	add_child(house)
	_player = PlayerController.new()
	_player.name = "Player"
	add_child(_player)
	_player.position = PLAYER_SPAWN
	# Face the window / counter side of the room.
	_player.rotation.y = deg_to_rad(-155.0)
	_hud = MatchHUD.new()
	add_child(_hud)
	# Demo teammate in the hallway until remote player avatars are wired.
	_demo_avatar = InvestigatorAvatar.new()
	_demo_avatar.player_index = 1
	_demo_avatar.display_name = "Demo Investigator"
	add_child(_demo_avatar)
	_demo_avatar.position = Vector3(3.6, 0.0, 3.85)
	_demo_avatar.rotation.y = deg_to_rad(-105.0)  # face card toward the hall camera


func _process(_delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_hud):
		_hud.prompt_label.text = _player.current_prompt()
		_hud.stamina_bar.value = _player.stamina_ratio()
		_hud.battery_bar.value = _player.flashlight.battery_ratio()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_player.try_interact()