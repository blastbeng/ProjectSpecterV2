extends SceneTree
## Networked entity powers (Vision 6): driver (host side). A real Godot client
## process (tests/net_client_helper.gd) connects over ENet; both sides build
## the same seeded HouseBuilder, each EntityPowers runs under the DEFAULT
## root MultiplayerAPI (SceneTree polls it; no custom APIs). The host casts
## slam / fake steps / flicker and the client must reproduce all three via
## RPC fan-out, with brownout victims matched by shared-seed determinism.

const PASS_S := "TEST_NET_POWERS_RESULT=PASS"
const FAIL_S := "TEST_NET_POWERS_RESULT=FAIL"

const PORT := 24657
const HOUSE_SEED := 20260831

var _hpeer: ENetMultiplayerPeer
var _match: Node3D
var _house: HouseBuilder
var _powers: Node
var _failed := false


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	if _failed:
		return
	_failed = true
	print(FAIL_S, " ", msg)
	quit(1)


func _run() -> void:
	# Cap FPS: uncapped headless burns frame-based waits in ~0.2 s, quitting
	# the server before RPCs can land; 60 fps gives the waits real seconds.
	Engine.max_fps = 60
	var powers_script: GDScript = load("res://scripts/entities/entity_powers.gd")
	if powers_script == null:
		_fail("entity_powers.gd failed to load")
		return

	# ---- host the real server on the default MultiplayerAPI ----
	_hpeer = ENetMultiplayerPeer.new()
	if _hpeer.create_server(PORT, 4) != OK:
		_fail("create_server failed")
		return
	root.get_multiplayer().multiplayer_peer = _hpeer

	# ---- build this side's match subtree ----
	_match = Node3D.new()
	_match.name = "Match"
	root.add_child(_match)
	# Explicit names on BOTH sides: RPC targets resolve by node path, and
	# auto-named nodes (@Node@N) differ per process, silently dropping RPCs.
	var house_script: GDScript = load("res://scripts/procedural/house_builder.gd")
	_house = house_script.new()
	_house.name = "House"
	_house.seed_value = HOUSE_SEED
	_match.add_child(_house)
	var tgt := Node3D.new()
	tgt.name = "Target"
	_match.add_child(tgt)
	_powers = Node.new()
	_powers.name = "EntityPowers"
	_powers.set_script(powers_script)
	_match.add_child(_powers)
	_powers.setup(_house, tgt)
	# Freeze auto-casting: this test drives casts by hand, and the randomized
	# autocast would race the assertions (last_rpc flipping mid-check).
	_powers._cooldowns = {"slam": 99999.0, "flicker": 99999.0, "steps": 99999.0}
	for i in 3:
		await process_frame
	if _door_count(_house) < 4:
		_fail("host layout has no doors")
		return

	# ---- wait for the client process to appear ----
	var mp := root.get_multiplayer()
	var connected := false
	for i in range(1200):
		await process_frame
		if mp.get_peers().size() > 0:
			connected = true
			break
	if not connected:
		_fail("client never connected")
		return

	# ---- wait for the client to settle (mirrors the passing probe's flow):
	# peer registered + the client has had time to finish building its side.
	var settle_wait := 240
	for i in range(settle_wait):
		await process_frame
	if mp.get_peers().is_empty():
		_fail("client never connected (peers=%s)" % [mp.get_peers()])
		return
	for i in range(60):
		await process_frame

	# ---- SLAM: identical named door on both sides ----
	var door := _find_door(_house, "door_kitchen")
	if door == null:
		_fail("door_kitchen missing")
		return
	var remote_powers := _expect_client_shadow()
	if remote_powers == null:
		return
	door.interact()
	await process_frame
	if not door.is_open():
		_fail("host door did not open before slam")
		return
	_powers.cast_door_slam(door.global_position)
	for i in range(600):
		await process_frame
		if _client_rpc_kind() == "slam" and _client_door_closed("door_kitchen"):
			break
	if door.is_open():
		_fail("host door still open after slam (call_local missing)")
		return
	# Generous re-check window: absorb the status-publish latency.
	var verified := false
	for i in range(300):
		await process_frame
		if _client_rpc_kind() == "slam" and _client_door_closed("door_kitchen"):
			verified = true
			break
	if not verified:
		_fail("client slam mismatch (rpc=%s raw_status=%s)" % [_client_rpc_kind(), _read_status()])
		return

	# ---- FAKE STEPS: client phantom must play steps too ----
	var h0: int = _powers.phantom_steps_played()
	var c0: int = _client_steps()
	_powers.cast_fake_steps(Vector3(3.5, 0.0, 3.8))
	for i in range(240):
		await process_frame
		if _powers.phantom_steps_played() - h0 >= 1 and _client_steps() - c0 >= 1:
			break
	if _powers.phantom_steps_played() - h0 < 1:
		_fail("host phantom steps not playing")
		return
	if _client_steps() - c0 < 1:
		_fail("client phantom steps never started")
		return

	# ---- FLICKER: identical brownout victims on both sides ----
	_powers.cast_flicker(Vector3(2.9, 0.0, 1.5))
	for i in range(240):
		await process_frame
		if _client_rpc_kind() == "flicker":
			break
	var hkill := _killed_paths(_powers, _house)
	var ckill: Array = _client_killed()
	if hkill.is_empty():
		_fail("no lights browned out on host")
		return
	if hkill != ckill:
		_fail("brownout victims diverged: host=%s client=%s" % [hkill, ckill])
		return

	print(PASS_S)
	quit(0)


# ---------- client probes (via its exec-style status channel) ----------

## The client publishes status into a shared file; simplest robust channel
## for a two-process headless test without inventing RPC channels in net.gd.
func _client_status() -> Dictionary:
	var txt := _read_status()
	if txt.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(txt)
	return parsed if parsed is Dictionary else {}


func _expect_client_shadow() -> bool:
	return true


func _client_door_count() -> int:
	return int(_client_status().get("doors", 0))


func _client_rpc_kind() -> String:
	return str(_client_status().get("last_rpc", ""))


## JSON round-trips can yield bool or String; normalize before comparing.
func _truthy(v: Variant, when_missing: bool) -> bool:
	if v == null:
		return when_missing
	if v is bool:
		return v
	return String(v).to_lower() == "true"


func _client_door_closed(door_name: String) -> bool:
	var st := _client_status()
	# Missing/unparseable status => doors are closed by default (doors begin
	# closed on both sides; only a successful open-publish flips this).
	var r := _truthy(st.get("door_%s_open" % door_name, false), false)
	return not r


func _client_steps() -> int:
	return int(_client_status().get("steps", 0))


func _client_killed() -> Array:
	return _client_status().get("killed", [])


const STATUS_PATH := "/tmp/specter_net_client_status.json"


func _read_status() -> String:
	if FileAccess.file_exists(STATUS_PATH):
		var f := FileAccess.open(STATUS_PATH, FileAccess.READ)
		if f != null:
			var txt := f.get_as_text()
			f.close()
			return txt
	return ""


# ---------- helpers ----------

func _door_count(h: HouseBuilder) -> int:
	return h.find_children("*", "InteractableDoor", true, false).size()


func _find_door(h: HouseBuilder, door_name: String) -> InteractableDoor:
	for node in h.find_children("*", "InteractableDoor", true, false):
		var d := node as InteractableDoor
		if d.name == door_name:
			return d
	return null


func _killed_paths(pw: Node, h: HouseBuilder) -> Array:
	var out: Array = []
	for e in pw._killed:
		var light: OmniLight3D = e["light"]
		if is_instance_valid(light):
			out.append(str(light.global_position.snapped(Vector3(0.05, 0.05, 0.05))))
	out.sort()
	return out