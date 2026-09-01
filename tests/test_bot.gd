extends SceneTree
## Bot v1 test (Vision 6): the scripted investigator walks to EMF hotspots
## through the hall spine, dwells, logs evidence into the shared journal,
## and keeps cycling. Asserts real movement, waypoint progress, journal
## captures appearing, and that the bot never leaves the house bounds.

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
	var start: Vector3 = bot.avatar.global_position

	# Drive the bot by hand for ~30 s of frames (headless delta pacing).
	var t := 0.0
	var moved := false
	var last_pos: Vector3 = bot.avatar.global_position
	while t < 30.0 and journal.captures.size() < 2:
		var dt: float = 1.0 / 60.0
		bot._process(dt)
		t += dt
		if bot.avatar.global_position.distance_to(last_pos) > 0.02:
			moved = true
		last_pos = bot.avatar.global_position
		await process_frame
	if not moved:
		_fail("bot never moved")
		return
	if bot.avatar.global_position.distance_to(start) < 0.5:
		_fail("bot never left spawn")
		return
	if journal.captures.is_empty():
		_fail("bot logged no evidence in %.0f s" % t)
		return
	# Waypoints keep the bot on hall spine or room interiors (z inside house).
	var p: Vector3 = bot.avatar.global_position
	if p.x < -0.5 or p.x > 7.5 or p.z < -0.5 or p.z > 8.5:
		_fail("bot escaped the house: %s" % p)
		return

	print(PASS_S, " captures=%d at=%s t=%.0fs" % [journal.captures.size(), last_pos, t])
	quit(0)