extends SceneTree
## Fear system headless check (Vision 6): darkness + isolation ramp fear,
## lit+company decays it, heartbeat audio plays, sway engages past threshold,
## entity power manifests bump fear. Uses the real Match scene.

const PASS_S := "TEST_FEAR_RESULT=PASS"
const FAIL_S := "TEST_FEAR_RESULT=FAIL"


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

	var match_node: Node = root.get_node("Match")
	var fear: FearMeter = match_node.get_node("FearMeter")
	if fear == null:
		_fail("FearMeter missing from Match")
		return
	var player: Node3D = match_node.get_node("Player")

	# Heartbeat audible: count played beats by watching the player.
	var beats := [0]
	var hp: AudioStreamPlayer = fear._heart
	hp.finished.connect(func() -> void: pass)  # playback signal exists
	var orig_play := hp.play
	hp.set_meta("plays", 0)
	hp.finished.connect(func() -> void:
		hp.set_meta("plays", int(hp.get_meta("plays", 0)) + 1))

	# Force maximally scary conditions: kill all nearby lights + lone player.
	for node in player.get_tree().get_nodes_in_group("fear_lights"):
		(node as OmniLight3D).light_energy = 0.0
	# Stash the demo teammate far away (isolation).
	var demo: Node3D = match_node.get("_demo_avatar")
	if is_instance_valid(demo):
		demo.global_position = Vector3(30, 0, 30)
	# Flashlight OFF (Match spawns it enabled): darkness probe counts it.
	player.get("flashlight").enabled = false
	player.get("flashlight")._spot.visible = false
	# Teleport player far from any lamp (defensive).
	player.global_position = Vector3(3.5, 0.1, 3.85)

	var f0: float = fear.fear
	for i in 240:  # ~4 s at 60 fps
		await process_frame
	var f1: float = fear.fear
	if f1 <= f0:
		_fail("fear not rising (t0=%f t1=%f)" % [f0, f1])
		return
	if f1 < 4.0:
		_fail("fear ramp too slow (%f after 4 s)" % f1)
		return

	# Entity power manifest bumps activity -> faster rise.
	var before: float = fear.fear
	fear.on_entity_power_near(player.global_position, player)
	fear.sample(1.0, player, [], null)
	var after: float = fear.fear
	if after - before < 1.5:
		_fail("entity activity did not spike fear (%f -> %f)" % [before, after])
		return

	# Safety: restore lights, teleport the demo ally back -> fear decays.
	for node in player.get_tree().get_nodes_in_group("fear_lights"):
		var l := node as OmniLight3D
		l.light_energy = l.get_meta("base_energy", 2.0)
	if is_instance_valid(demo):
		demo.global_position = player.global_position + Vector3(1, 0, 0)
	fear._probe_timer = 0.0
	var d0: float = fear.fear
	for i in 240:
		await process_frame
		fear.sample(1.0 / 60.0, player, [demo] if is_instance_valid(demo) else [], null)
	var d1: float = fear.fear
	if d1 >= d0:
		_fail("fear not decaying in safety (%f -> %f)" % [d0, d1])
		return

	# Sway: with fear driven high, camera roll engages; PlayerController hook.
	player.get("camera").rotation = Vector3.ZERO
	fear.fear = 90.0
	var sw: float = fear.sway_offset()
	if absf(sw) < 0.001:
		_fail("no camera sway at high fear")
		return
	player.set_fear_sway(sw)
	if absf(player.get("camera").rotation.z - sw) > 0.0001:
		_fail("player did not apply fear sway")
		return
	player.set_fear_sway(0.0)

	# Heartbeat: directly drive several beats and confirm the player fires.
	var plays0: int = int(hp.get_meta("plays", 0))
	fear.fear = 80.0
	for i in 200:
		await process_frame
	var plays1: int = int(hp.get_meta("plays", 0))
	if plays1 <= plays0:
		_fail("no heartbeat audio played at high fear (%d -> %d)" % [plays0, plays1])
		return

	print(PASS_S)
	quit(0)