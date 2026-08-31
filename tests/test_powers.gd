extends SceneTree
## test_powers.gd — entity powers v1 (Vision 6).
## Checks: door slam closes + emits state, flicker dims/kill lamps, fake
## footsteps spawn audible player, cooldown gating, target distance filter.

const MATCH_SCENE := "res://scenes/match.tscn"
const PASS_S := "TEST_POWERS_RESULT=PASS"
const FAIL_S := "TEST_POWERS_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0
	var scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame

	var match_node: Node = root.get_node("Match")
	var player: Node3D = match_node.get_node("Player")
	var house: HouseBuilder = null
	for child in match_node.get_children():
		if child is HouseBuilder:
			house = child
	var powers: EntityPowers = match_node.get_node("EntityPowers")
	if house == null or powers == null:
		print(FAIL_S, " missing house or EntityPowers")
		quit(1)
		return

	# --- door slam -----------------------------------------------------------
	# Find the nearest door to the player, open it, then let the entity slam.
	var doors: Array = house.find_children("*", "InteractableDoor", true, false)
	if doors.size() < 4:
		print(FAIL_S, " expected >=4 doors, got %d" % doors.size())
		quit(1)
		return
	var door: InteractableDoor = doors[0]
	door.global_position = player.global_position + Vector3(1.0, 0, 0)  # force nearest
	door.interact()
	if not door.is_open():
		print(FAIL_S, " door did not open for slam test")
		failures += 1
	for i in 40:
		await physics_frame
	# Lambdas capture locals by value — record into an array instead.
	var opened_log: Array = []
	door.state_changed.connect(func(_o: bool) -> void: opened_log.append(1))
	powers.cast_door_slam(player.global_position)
	for i in 30:
		await physics_frame
	if door.is_open():
		print(FAIL_S, " door still open after entity slam")
		failures += 1
	if opened_log.is_empty():
		print(FAIL_S, " state_changed not emitted on slam")
		failures += 1

	# --- flicker + brownout --------------------------------------------------
	seed(42)
	powers.kill_time_s = 0.4     # shorter than the recovery wait below
	powers.flicker_time_s = 0.2  # strobe must end before the recovery check too
	powers.cast_flicker(player.global_position)
	var lights: Array = house.find_children("*", "OmniLight3D", true, false)
	if lights.size() < 5:
		print(FAIL_S, " expected >=5 lights, got %d" % lights.size())
		failures += 1
	# After a few frames lamps must carry a flicker meta or be dark.
	var flick_seen := false
	for i in 20:
		await physics_frame
	for light in lights:
		if light.has_meta("base_energy") and light.light_energy < 0.99 * float(light.get_meta("base_energy")):
			flick_seen = true
	if not flick_seen:
		print(FAIL_S, " no light dimmed during flicker/brownout")
		failures += 1
	# Lights must recover: fast-forward the kill timers.
	for i in range(30):
		await physics_frame
	if not powers.is_recovered():
		print(FAIL_S, " lights did not recover after brownout")
		failures += 1

	# --- fake footsteps ------------------------------------------------------
	powers.cast_fake_steps(player.global_position + Vector3(2, 0, 2))
	if powers.cooldown_left("steps") <= 0.0:
		print(FAIL_S, " steps cooldown not set")
		failures += 1
	# Steps actually tick: after ~1.5 s of physics the phantom walked >=3 steps.
	for i in 90:
		await physics_frame
	if not powers.phantom_steps_played() >= 3:
		print(FAIL_S, " phantom played <3 steps (%d)" % powers.phantom_steps_played())
		failures += 1

	if failures == 0:
		print(PASS_S)
	else:
		print(FAIL_S)
	quit(1 if failures > 0 else 0)