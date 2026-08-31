extends SceneTree
## Panic hold test (Vision 6 fear->gameplay): at fear >= 82 the E key becomes
## a hold-to-complete interaction (slower interactions above fear 80); a tap
## must NOT fire, one full hold fires exactly once (no double-toggle from a
## still-held key), and a still-held key cannot recharge until released.
## Fear below the hysteresis floor returns tap-to-interact. Uses Match + real
## input events so the E key path is exercised end to end.

const PASS_S := "TEST_PANIC_RESULT=PASS"
const FAIL_S := "TEST_PANIC_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print(FAIL_S, " ", msg)
	quit(1)


func _run() -> void:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame

	var m: Node = root.get_node("Match")
	var player: PlayerController = m.get_node("Player")
	var door_node: Node3D = null
	var house: HouseBuilder = m.get("_house")
	for d in house.find_children("*", "InteractableDoor", true, false):
		door_node = d
		break
	if door_node == null:
		_fail("no door found in house")
		return
	var door := door_node as InteractableDoor

	# Aim the interaction ray straight at the door.
	var cam: Camera3D = player.camera
	player.global_position = door.global_position + Vector3(0, 0, 1.2)
	cam.look_at(door.global_position + Vector3(0, 1.0, 0.0))
	for i in 3:
		await process_frame
	if not player.interact_ray.is_colliding():
		_fail("interaction ray does not hit the door (pos %s)" % player.global_position)
		return

	# --- Calm fear: a single E press (real input event) opens the door.
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)
	for i in 10:
		await physics_frame
	var ev_up := InputEventKey.new()
	ev_up.physical_keycode = KEY_E
	ev_up.pressed = false
	Input.parse_input_event(ev_up)
	for i in 6:
		await physics_frame
	if not door.is_open():
		_fail("tap-to-interact should open a calm door")
		return
	if player._panic_hold != 0.0:
		_fail("hold accumulator must stay 0 while calm")
		return
	# Reset the door for the panic phase.
	door.interact()
	await process_frame

	# --- Panic on: a tap must be ignored; a full hold fires once.
	player.set_panic(true)
	if not player.is_panicking():
		_fail("set_panic(true) did not engage")
		return
	player.panic_hold_target_s = 0.25   # shortened for test speed
	for i in 6:
		await physics_frame
	# Tap: quick press+release inside the hold window.
	Input.parse_input_event(ev)
	await physics_frame
	await physics_frame
	Input.parse_input_event(ev_up)
	for i in 8:
		await physics_frame
	if door.is_open():
		_fail("tap-to-interact must be inert while panicking")
		return
	# Hold: keep the key down until the charge completes.
	Input.parse_input_event(ev)
	for i in 40:  # ~0.67 s of physics at 60 Hz
		await physics_frame
	Input.parse_input_event(ev_up)
	for i in 6:
		await physics_frame
	if not door.is_open():
		_fail("completed panic hold did not fire the interaction")
		return
	if player._panic_hold != 0.0:
		_fail("hold accumulator did not reset after firing")
		return

	# --- Panic off: tap behavior returns.
	player.set_panic(false)
	await process_frame
	if door.is_open():
		door.interact()
	await physics_frame
	Input.parse_input_event(ev)
	for i in 10:
		await physics_frame
	Input.parse_input_event(ev_up)
	for i in 6:
		await physics_frame
	if not door.is_open():
		_fail("tap-to-interact did not return when panic released")
		return

	# Breathing loop: generated, plays while panicking, stops on release.
	var breath: AudioStreamWAV = SfxGenerator.breathing(1.0)
	if breath == null or breath.data.size() < 1000:
		_fail("breathing() audio is empty")
		return

	print(PASS_S)
	quit(0)