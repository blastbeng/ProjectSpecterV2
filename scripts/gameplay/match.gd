extends Node3D
## Match scene: assembles night environment, the first dressed room and the
## player spawn. Procedural building grows here iteration by iteration.
## Objective pipeline (Vision 6): get into the locked room -> restore power
## (unlock) -> arm extraction -> survive a 60 s loud countdown to escape.

const PLAYER_SPAWN := Vector3(2.9, 0.1, 4.1)
const HOUSE_SEED := 20260831
const EXTRACT_TIME_S := 60.0

var _hud: MatchHUD
var _player: PlayerController
var _journal: Journal
var _powers: EntityPowers
var _house: HouseBuilder
var _demo_avatar: InvestigatorAvatar
var _extract_gate: ExtractionGate
var _fear: FearMeter
# peer id -> remote avatar (Vision 5.2)
var _remote_avatars := {}
var _toast_cooldown := 0.0
# Objective stage machine: "locked_room" -> "power" -> "extract" -> "flee".
var _stage := "locked_room"
var _extract_left := 0.0
var _extract_running := false
# Panic interactions engaged (Vision 6): E becomes hold-to-interact.
var _panic_interact := false


func _ready() -> void:
	print("MATCH: scene ready, house seed %d" % HOUSE_SEED)
	add_child(NightEnvironment.new())
	var house := HouseBuilder.new()
	house.seed_value = HOUSE_SEED
	add_child(house)
	_house = house
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
	# Entity presence (Vision 6 powers v1): acts on the house near the target.
	_powers = EntityPowers.new()
	_powers.name = "EntityPowers"
	add_child(_powers)
	_powers.setup(house, _player)
	_powers.power_manifest.connect(_on_entity_power_felt)
	# Objective pipeline (Vision 6): breaker inside the locked room + the
	# extraction gate at the hall's west end unlock the escape countdown.
	if house.breaker != null:
		house.breaker.power_restored.connect(_on_power_restored)
	for door in house.doors_for_room(house.locked_room()):
		(door as InteractableDoor).state_changed.connect(_on_locked_door_opened)
	_spawn_extract_gate()
	_hud.set_objective(_objective_text())
	# Fear system (Vision 6): darkness + isolation + entity activity.
	_fear = FearMeter.new()
	_fear.name = "FearMeter"
	add_child(_fear)
	_fear.fear_changed.connect(func(v01: float) -> void: _hud.set_fear(v01))
	# Tag lamps so the darkness probe can find lights cheaply.
	for node in house.find_children("*", "OmniLight3D", true, false):
		node.add_to_group("fear_lights")


func _process(delta: float) -> void:
	if is_instance_valid(_player) and is_instance_valid(_hud):
		if _toast_cooldown > 0.0:
			_toast_cooldown -= delta
		else:
			_hud.prompt_label.text = _player.current_prompt()
		_hud.stamina_bar.value = _player.stamina_ratio()
		_hud.battery_bar.value = _player.flashlight.battery_ratio()
		_hud.set_emf(_player.emf.strength, _player.emf.level)
	if _extract_running:
		_extract_left -= delta
		_hud.set_extract_timer(maxf(_extract_left, 0.0))
		if _extract_left <= 0.0:
			_extract_running = false
			_hud.show_extract_failed()
	if is_instance_valid(_fear):
		var crowd: Array = _remote_avatars.values()
		if is_instance_valid(_demo_avatar):
			crowd.append(_demo_avatar)
		_fear.sample(delta, _player, crowd, _powers)
		_player.set_fear_sway(_fear.sway_offset() + _player.panic_shake())
		# Panic hysteresis: hold-to-interact engages above 82, releases below 75
		# so meter wobble near the line does not flicker the mechanic (Vision 6).
		if not _panic_interact and _fear.fear >= 82.0:
			_panic_interact = true
			_player.set_panic(true)
			AudioServer.set_bus_volume_db(
				AudioServer.get_bus_index("Master"),
				linear_to_db(0.6))
		elif _panic_interact and _fear.fear < 75.0:
			_panic_interact = false
			_player.set_panic(false)
			AudioServer.set_bus_volume_db(
				AudioServer.get_bus_index("Master"),
				linear_to_db(1.0))
	_maybe_stage_panic_demo()


## Evidence staging for --panic-demo: pins the staged state against the
## fear system's own decay (re-pins fear each couple of frames), kills
## nearby lamps + flashlight so the darkness keeps fear up, aims the
## camera at the nearest door and synthesizes a held-E key so the
## hold-to-interact charge is visibly mid-progress for grim screenshots.
var _panic_demo_t := 0.0

func _maybe_stage_panic_demo() -> void:
	if not ("--panic-demo" in OS.get_cmdline_user_args()):
		return
	_panic_demo_t += 1.0 / 60.0
	if _panic_demo_t > 12.0:
		return  # staged state stays alive for the whole capture window
	var player := _player
	var house := _house
	if _panic_demo_t <= 1.0 / 60.0 or _panic_demo_t > 11.5:
		return
	# Stage once, then keep re-pinning fear while the shots are taken.
	var door: InteractableDoor = null
	var best := 999.0
	for d in house.find_children("*", "InteractableDoor", true, false):
		var dist: float = (d as Node3D).global_position.distance_to(player.global_position)
		if dist < best:
			best = dist
			door = d
	if door == null:
		return
	if _panic_demo_t <= 3.0 * 1.0 / 60.0:
		player.global_position = door.global_position + Vector3(0, 0, 1.2)
		player.camera.look_at(door.global_position + Vector3(0, 1.0, 0))
		var flash = player.get("flashlight")
		if flash != null:
			flash.enabled = false
			flash._spot.visible = false
		for node in player.get_tree().get_nodes_in_group("fear_lights"):
			var l := node as OmniLight3D
			if l.global_position.distance_to(door.global_position) < 6.0:
				l.light_energy = 0.0
	_fear.fear = 88.0
	_player.set_panic(true)
	player.panic_hold_target_s = 3.2
	if _panic_demo_t <= 4.0 * 1.0 / 60.0:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ev.pressed = true
		Input.parse_input_event(ev)


func _objective_text() -> String:
	match _stage:
		"locked_room":
			return "Find a way into the %s" % _house.locked_room().to_lower()
		"power":
			return "Restore power (breaker is in the %s)" % _house.locked_room().to_lower()
		"extract":
			return "Reach the extraction gate (hall, west end)"
		"flee":
			return "ESCAPE — through the gate, NOW!"
	return ""


func _on_locked_door_opened(_open: bool) -> void:
	# The padlocked objective room's door moved; if it is now open and not
	# locked, the investigators found their way in: advance to power stage.
	if _stage != "locked_room":
		return
	var door := _house.door_to(_house.locked_room())
	if door != null and not door.is_locked() and door.is_open():
		_stage = "power"
		_hud.set_objective(_objective_text())


func _on_power_restored() -> void:
	if _stage == "done":
		return
	# Power back: the locked room's door unlocks, extraction activates.
	for door in _house.doors_for_room(_house.locked_room()):
		(door as InteractableDoor).unlock()
	_stage = "extract"
	_extract_gate.activate()
	_hud.set_objective(_objective_text())
	_toast("Power restored — extraction is active")


func _on_extraction_started() -> void:
	_extract_running = true
	_extract_left = EXTRACT_TIME_S
	_stage = "flee"
	_hud.show_extract_countdown(EXTRACT_TIME_S)
	_hud.set_objective(_objective_text())


func _spawn_extract_gate() -> void:
	_extract_gate = ExtractionGate.new()
	_extract_gate.name = "ExtractionGate"
	add_child(_extract_gate)
	# West end of the hall, facing along the corridor (z-run ends at x=0).
	_extract_gate.position = Vector3(0.55, 0.0, 3.85)
	_extract_gate.rotation.y = deg_to_rad(-90.0)
	_extract_gate.extraction_started.connect(_on_extraction_started)
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
		if event.physical_keycode == KEY_J:
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


func _on_entity_power_felt(_kind: String, at: Vector3) -> void:
	if is_instance_valid(_fear):
		_fear.on_entity_power_near(at, _player)


func _on_capture_added(kind: String, room: String) -> void:
	_toast("Logged: %s — %s" % [kind, room])