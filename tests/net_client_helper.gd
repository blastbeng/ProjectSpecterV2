extends SceneTree
## Client half of the networked-powers net test (Vision 6). NOT collected by
## tools/test.sh (filename lacks the test_ prefix); the driver
## tests/test_net_powers.gd launches this process via tools/net_powers_test.sh,
## reads its status file, and both scripts quit when the check completes.
## The helper lives NET_CLIENT_LIFETIME_S wall-clock seconds (default 75) in
## headless uncapped-FPS mode, frames are cheap; wall clock is the budget.

const PORT := 24657
const HOUSE_SEED := 20260831
const STATUS_PATH := "/tmp/specter_net_client_status.json"

var _cpeer: ENetMultiplayerPeer
var _match: Node3D
var _house: HouseBuilder
var _powers: Node
var _deadline_ms := 0


func _init() -> void:
	var life := 75.0
	var env_life := OS.get_environment("NET_CLIENT_LIFETIME_S")
	if env_life != "":
		life = float(env_life)
	print("NET_CLIENT_HELPER: starting (lifetime %.1fs)" % life)
	# Diagnose any connection drop (the driver kicks nothing, so a drop is a bug).
	# NOTE: root is not available in _init for a SceneTree script; hook in _run.
	_deadline_ms = Time.get_ticks_msec() + int(life * 1000.0)
	call_deferred("_run")


func _timed_out() -> bool:
	return Time.get_ticks_msec() >= _deadline_ms


func _run() -> void:
	_cpeer = ENetMultiplayerPeer.new()
	if _cpeer.create_client("127.0.0.1", PORT) != OK:
		_quit_fail("create_client failed")
		return
	var mp := root.get_multiplayer()
	# Drop diagnostics: nothing on either side ever kicks the client, so any
	# disconnect event here points at an engine-side network bug.
	mp.peer_disconnected.connect(func(id: int) -> void:
		print("NET_CLIENT_HELPER: peer_disconnected ", id))
	mp.server_disconnected.connect(func() -> void:
		print("NET_CLIENT_HELPER: SERVER DISCONNECTED"))
	mp.multiplayer_peer = _cpeer

	var connected := false
	while not _timed_out():
		await process_frame
		if mp.get_peers().size() > 0 and mp.get_unique_id() >= 2:
			connected = true
			break
	if not connected:
		_quit_fail("never connected")
		return

	# Same seeded building (identical node names + light positions).
	# Explicit names identical to the host side (RPC paths must match).
	var house_script: GDScript = load("res://scripts/procedural/house_builder.gd")
	_match = Node3D.new()
	_match.name = "Match"
	root.add_child(_match)
	_house = house_script.new()
	_house.name = "House"
	_house.seed_value = HOUSE_SEED
	_match.add_child(_house)
	var tgt := Node3D.new()
	tgt.name = "Target"
	_match.add_child(tgt)
	_powers = Node.new()
	_powers.name = "EntityPowers"
	_powers.set_script(load("res://scripts/entities/entity_powers.gd"))
	_match.add_child(_powers)
	_powers.setup(_house, tgt)
	# Mirror the host: only driver-cast events are allowed to fire RPCs.
	_powers._cooldowns = {"slam": 99999.0, "flicker": 99999.0, "steps": 99999.0}
	for i in 3:
		await process_frame

	if _door_count(_house) < 4:
		_quit_fail("client layout has no doors")
		return

	# Live for the whole test; publish ~10x/s (headless runs uncapped FPS,
	# and thousands of file writes per second starve the ENet poll).
	# Cap FPS: uncapped headless spins can starve the ENet event pump.

	var publish_gap := 6
	var since_publish := 0
	var last_keepalive := 0
	while not _timed_out():
		await process_frame
		since_publish += 1
		if since_publish >= publish_gap:
			since_publish = 0
			_publish()
		# Keepalive: raw ENet packet every second — an idle ENet association
		# that never sends can be reaped on the server side mid-wait.
		var now := Time.get_ticks_msec()
		if now - last_keepalive > 500:
			last_keepalive = now
			_cpeer.put_var("ka")
	# Budget exhausted: exit cleanly (the driver reports missing events).
	quit(0)


func _quit_fail(msg: String) -> void:
	push_error("NET_CLIENT_HELPER: %s" % msg)
	var f := FileAccess.open(STATUS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"error": msg}))
		f.close()
	print("NET_CLIENT_HELPER_FAIL: %s" % msg)
	quit(1)


func _publish() -> void:
	# Guard: after a server disconnect the peer is torn down and get_unique_id
	# spams errors each call; publish "disconnected" once and freeze.
	if _published_disconnect:
		return
	var mp := root.get_multiplayer()
	if mp.multiplayer_peer == null:
		_published_disconnect = true
		print("NET_CLIENT_HELPER: peer gone while publishing (SERVER LOST)")
	_publish_state(mp)


var _published_disconnect := false


func _publish_state(mp: MultiplayerAPI) -> void:
	var killed: Array = []
	for e in _powers._killed:
		var light: OmniLight3D = e["light"]
		if is_instance_valid(light):
			killed.append(str(light.global_position.snapped(Vector3(0.05, 0.05, 0.05))))
	var door := _find_door("door_kitchen")
	# Atomic publish: write to a temp file, then rename over the real one —
	# the driver polls mid-flight and must never see a half-written document.
	var tmp_path := STATUS_PATH + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"doors": _door_count(_house),
			"last_rpc": _powers._last_rpc_kind,
			"steps": _powers.phantom_steps_played(),
			"killed": killed,
			"door_kitchen_open": true if door == null else door.is_open(),
			"peer_id": mp.get_unique_id(),
		}))
		f.close()
		DirAccess.rename_absolute(tmp_path, STATUS_PATH)


func _door_count(h: HouseBuilder) -> int:
	return h.find_children("*", "InteractableDoor", true, false).size()


func _find_door(door_name: String) -> InteractableDoor:
	for node in _house.find_children("*", "InteractableDoor", true, false):
		var d := node as InteractableDoor
		if d.name == door_name:
			return d
	return null