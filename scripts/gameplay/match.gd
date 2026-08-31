extends Node3D
## Match scene: assembles night environment, the first dressed room and the
## player spawn. Procedural building grows here iteration by iteration.

const PLAYER_SPAWN := Vector3(2.9, 0.1, 4.1)
const HOUSE_SEED := 20260831

var _hud: MatchHUD
var _player: PlayerController
var _journal: Journal
var _demo_avatar: InvestigatorAvatar
# peer id -> remote avatar (Vision 5.2)
var _remote_avatars := {}
var _toast_cooldown := 0.0


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
	_player.add_child(PeerController.new())
	_hud = MatchHUD.new()
	add_child(_hud)
	# Evidence journal (Vision 6): TAB opens it; F logs EMF readings.
	_journal = Journal.new()
	add_child(_journal)
	_journal.capture_added.connect(_on_capture_added)
	# EMF reading strength comes in via player controller's sample() calls.
	# Demo teammate in the hallway until a real remote peer replaces it.
	_demo_avatar = InvestigatorAvatar.new()
	_demo_avatar.player_index = 1
	_demo_avatar.display_name = "Demo Investigator"
	add_child(_demo_avatar)
	_demo_avatar.position = Vector3(3.6, 0.0, 3.85)
	_demo_avatar.rotation.y = deg_to_rad(-105.0)  # face card toward the hall camera
	# Evidence layer (Vision 6): house hotspots feed our reader; J toggles it.
	_player.emf.set_hotspots(house.emf_hotspots)
	_player.emf.toggle(false)
	_hud.set_emf(0.0, 1)
	# Spawn avatars for peers already registered (joiner case) and future ones.
	for id in Net.players:
		_spawn_remote_avatar(id, Net.players[id])
	Net.player_registered.connect(_on_player_registered)
	Net.player_left.connect(_on_player_left)


func _process(delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_hud):
		if _toast_cooldown > 0.0:
			_toast_cooldown -= delta
		else:
			_hud.prompt_label.text = _player.current_prompt()
		_hud.stamina_bar.value = _player.stamina_ratio()
		_hud.battery_bar.value = _player.flashlight.battery_ratio()
		_hud.set_emf(_player.emf.strength, _player.emf.level)
	# Drive remote avatars from the latest relayed motion.
	for id in _remote_avatars:
		if Net.remote_motion.has(id):
			var mo: Dictionary = Net.remote_motion[id]
			var av: InvestigatorAvatar = _remote_avatars[id]
			av.global_position = mo["p"]
			av.rotation.y = mo["ry"]
			av.drive(mo["sp"], false, mo["cr"])


func _on_player_registered(id: int, info: Dictionary) -> void:
	if id == multiplayer.get_unique_id():
		return  # our own registration; the local body is the player camera
	# First real peer replaces the placeholder teammate (Vision 5.9 lobby).
	if is_instance_valid(_demo_avatar):
		_demo_avatar.queue_free()
		_demo_avatar = null
	_spawn_remote_avatar(id, info)


## Lobby identity -> avatar: team-color jacket + name plate (Vision 5.9).
func _apply_team_tint(av: InvestigatorAvatar, info: Dictionary) -> void:
	var c := str(info.get("color", ""))
	if c.begins_with("#") and c.length() >= 7:
		av.cloth_color = Color(c)
	av.display_name = str(info.get("name", av.display_name))


func _on_player_left(id: int) -> void:
	if _remote_avatars.has(id):
		_remote_avatars[id].queue_free()
		_remote_avatars.erase(id)


func _spawn_remote_avatar(id: int, info: Dictionary) -> void:
	# Skip our own registration (host stores itself under id 1) and dupes.
	if id == multiplayer.get_unique_id() or _remote_avatars.has(id):
		return
	var av := InvestigatorAvatar.new()
	av.player_index = id % 4
	_apply_team_tint(av, info)
	add_child(av)
	av.position = PLAYER_SPAWN + Vector3(0.9, 0.0, 0.4)
	_remote_avatars[id] = av


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			_player.try_interact()
		elif event.physical_keycode == KEY_J:
			_player.emf.toggle(not _player.emf.is_on())
			_hud.show_emf(_player.emf.is_on())
		elif event.physical_keycode == KEY_TAB:
			if _journal.is_open():
				_journal.close()
			else:
				_journal.toggle(true)
		elif event.physical_keycode == KEY_F:
			# Evidence logging: only counts while the reader is on and sees a
			# real hotspot; dedupe is the journal's job.
			if not _player.emf.is_on() or _player.emf.strongest_hotspot.is_empty():
				_toast("EMF reader off — press J near a reading")
			elif _player.emf.strength < 0.12:
				_toast("reading too faint to identify")
			else:
				var hs := _player.emf.strongest_hotspot
				_journal.player_captured(String(hs["kind"]), String(hs["room"]))
				_toast("Logged: %s (%s)" % [hs["kind"], hs["room"]])


func _toast(text: String) -> void:
	_hud.prompt_label.text = text
	_toast_cooldown = 2.2


func _on_capture_added(kind: String, room: String) -> void:
	_toast("Logged: %s — %s" % [kind, room])