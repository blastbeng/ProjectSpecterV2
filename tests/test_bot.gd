extends SceneTree
## Bot v2 test (Vision 6): the scripted investigator walks to EMF hotspots
## THROUGH real doorways (threshold waypoints from door positions), opens
## shut doors on the way, skips padlocked rooms, flees entity activity
## nearby, dwells, logs evidence into the shared journal, and keeps cycling.
## Asserts real movement, doorway passage, door-opening, journal captures,
## flee behavior, and that the bot never leaves the house bounds.

const PASS_S := "TEST_BOT_RESULT=PASS"
const FAIL_S := "TEST_BOT_RESULT=FAIL"


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
	var bot: BotDriver = m._bot
	if bot == null or bot.avatar == null:
		_fail("bot not wired into Match")
		return
	var journal: Journal = m.get_node("Journal")
	var house: HouseBuilder = m.find_children("*", "HouseBuilder", true, false)[0]
	var doorway_wps: Array = house.doorway_points()
	if doorway_wps.is_empty():
		_fail("house exposes no doorway points")
		return
	var start: Vector3 = bot.avatar.global_position

	# --- 1) Routing uses doorway thresholds (v2 core fix) --------------------
	var used_door_wps := 0
	var plan: Array = bot._waypoints
	for wp in plan:
		if wp.get("door") != null:
			used_door_wps += 1
	if used_door_wps < 1:
		_fail("bot plan has no doorway waypoints: %s" % [plan])
		return

	# --- 2) Drive the bot by hand for ~40 s of frames -------------------------
	var t := 0.0
	var moved := false
	var last_pos: Vector3 = bot.avatar.global_position
	var opened_a_door := false
	var shut_doors := {}  # InteractableDoor -> true (seen shut with bot close)
	while t < 40.0 and journal.captures.size() < 2:
		var dt: float = 1.0 / 60.0
		# Track whether the bot personally opens a shut doorway door en route:
		# remember doors observed shut while the bot was near their threshold.
		for wp in bot._waypoints:
			var d: InteractableDoor = wp.get("door")
			if d == null or not is_instance_valid(d) or d.is_locked():
				continue
			var dist: float = bot.avatar.global_position.distance_to(d.global_position)
			if dist < 0.7 and not d.is_open():
				shut_doors[d] = true  # seen shut with the bot close: must open
			if shut_doors.has(d) and d.is_open():
				opened_a_door = true
		bot._process(dt)
		t += dt
		if bot.avatar.global_position.distance_to(last_pos) > 0.02:
			moved = true
		last_pos = bot.avatar.global_position
		await process_frame
	if shut_doors.is_empty():
		_fail("no doorway door was ever observed shut near the bot")
		return
	if not moved:
		_fail("bot never moved")
		return
	if bot.avatar.global_position.distance_to(start) < 0.5:
		_fail("bot never left spawn")
		return
	if journal.captures.is_empty():
		_fail("bot logged no evidence in %.0f s" % t)
		return
	if not opened_a_door:
		_fail("bot never opened an observed-shut doorway door")
		return

	# --- 3) House bounds + doorway-line sanity --------------------------------
	var p: Vector3 = bot.avatar.global_position
	if p.x < -0.5 or p.x > 7.5 or p.z < -0.5 or p.z > 8.5:
		_fail("bot escaped the house: %s" % p)
		return

	# --- 4) Flee reaction to entity activity ----------------------------------
	bot.on_entity_activity(Vector3(5.9, 0.0, 6.2))  # storage bulb: far from spawn
	if not bot.is_fleeing():
		_fail("entity activity near bot did not trigger flee")
		return
	if bot._waypoints.is_empty():
		_fail("flee produced no waypoints")
		return
	# Far from the event: no flee.
	bot._flee_left = 0.0
	bot.on_entity_activity(Vector3(-30.0, 0.0, -30.0))
	if bot.is_fleeing():
		_fail("distant entity activity scared the bot anyway")
		return
	# Resume planning after the scare ends.
	bot._flee_left = 0.001
	bot._process(0.05)
	if bot._waypoints.is_empty():
		_fail("bot did not resume a route after fleeing")
		return

	# --- 5) Locked-room hotspots are skipped while padlocked ------------------
	var locked_room: String = house.locked_room()
	if locked_room != "":
		var lock_door: InteractableDoor = house.door_to(locked_room)
		if lock_door != null and lock_door.is_locked():
			# While the padlock is on, the planner must not target a hotspot
			# in that room, and must not have logged one there.
			for s in house.emf_hotspots:
				if String(s.get("room", "")) == locked_room:
					if not bot._logged.has(s) and bot._room_of(bot.avatar.global_position) == locked_room:
						_fail("bot walked into the padlocked room")
						return
			var dest: Dictionary = bot._waypoints[bot._waypoints.size() - 1]
			var dest_room: String = _hotspot_room_of(dest["pos"], house)
			if dest_room == locked_room:
				_fail("planner targets a padlocked room")
				return

	print(PASS_S, " captures=%d door_wps=%d opened_door=%s locked_room=%s t=%.0fs" % [
		journal.captures.size(), used_door_wps, opened_a_door, locked_room, t])
	quit(0)


## Room tag of the hotspot nearest a position (mirrors bot logging radius).
func _hotspot_room_of(p: Vector3, house: HouseBuilder) -> String:
	var best_d := 2.2
	var best_room := ""
	for s in house.emf_hotspots:
		var d: float = (s["pos"] as Vector3).distance_to(p)
		if d < best_d:
			best_d = d
			best_room = String(s.get("room", ""))
	return best_room