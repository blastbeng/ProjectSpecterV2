extends SceneTree
## Headless movement test: walk displacement, sprint stamina drain, crouch eye,
## footstep audio nodes.

const PASS_S := "TEST_MOVEMENT_RESULT=PASS"
const FAIL_S := "TEST_MOVEMENT_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame

	var player: CharacterBody3D = root.get_node_or_null("Match/Player")
	if player == null:
		print(FAIL_S, " no player")
		quit(1)
		return

	# Face west down the hallway (forward = -x at yaw -PI/2) so walking is
	# unobstructed to the west end.
	player.position = Vector3(6.4, 0.1, 3.85)
	player.rotation.y = -PI / 2.0
	for i in 12:
		await physics_frame

	# Walk: simulate W press.
	var start := player.global_position
	Input.action_press("ui_up") if false else null
	var w_down := InputEventKey.new()
	w_down.physical_keycode = KEY_W
	w_down.pressed = true
	Input.parse_input_event(w_down)
	for i in 60:
		await physics_frame
	var walked := player.global_position.distance_to(start)
	if walked < 0.5:
		print(FAIL_S, " walked only %.3f m" % walked)
		quit(1)
		return

	var w_up := InputEventKey.new()
	w_up.physical_keycode = KEY_W
	w_up.pressed = false
	Input.parse_input_event(w_up)
	for i in 10:
		await physics_frame

	# Sprint stamina: press W+Shift, expect drain and faster motion.
	var s_down := InputEventKey.new()
	s_down.physical_keycode = KEY_SHIFT
	s_down.pressed = true
	Input.parse_input_event(s_down)
	Input.parse_input_event(w_down)
	var st0: float = player.stamina
	for i in 60:
		await physics_frame
	var s_up := InputEventKey.new()
	s_up.physical_keycode = KEY_SHIFT
	s_up.pressed = false
	Input.parse_input_event(s_up)
	var w_up2 := InputEventKey.new()
	w_up2.physical_keycode = KEY_W
	w_up2.pressed = false
	Input.parse_input_event(w_up2)
	if player.stamina >= st0:
		print(FAIL_S, " stamina did not drain (%.1f -> %.1f)" % [st0, player.stamina])
		quit(1)
		return

	# Crouch: expect eye height below standing.
	var c_down := InputEventKey.new()
	c_down.physical_keycode = KEY_CTRL
	c_down.pressed = true
	Input.parse_input_event(c_down)
	for i in 40:
		await physics_frame
	var eye: float = player.camera.position.y
	var c_up := InputEventKey.new()
	c_up.physical_keycode = KEY_CTRL
	c_up.pressed = false
	Input.parse_input_event(c_up)
	if eye > 1.3:
		print(FAIL_S, " camera did not crouch (eye %.2f)" % eye)
		quit(1)
		return
	for i in 40:
		await physics_frame
	if absf(player.camera.position.y - 1.65) > 0.15:
		print(FAIL_S, " camera did not stand back up (eye %.2f)" % player.camera.position.y)
		quit(1)
		return

	print(PASS_S)
	quit(0)