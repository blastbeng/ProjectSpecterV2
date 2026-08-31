extends SceneTree
## Headless interaction test: door prompt, toggle swing, creak stream present.

const MATCH_SCENE := "res://scenes/match.tscn"
const PASS_S := "TEST_INTERACTION_RESULT=PASS"
const FAIL_S := "TEST_INTERACTION_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame

	var player: Node3D = root.get_node_or_null("Match/Player")
	if player == null:
		print(FAIL_S, " no player")
		quit(1)
		return

	# Stand in the hallway in front of the bathroom door (spans x 1.0..2.0 at
	# z = 4.7, hinge at the east jamb), face it.
	player.position = Vector3(1.5, 0.1, 4.25)
	player.rotation.y = PI
	for i in 12:
		await physics_frame

	var door: Node = root.get_node("Match").find_child("door_bathroom", true, false)
	if door == null:
		door = null
	var found: Array = root.get_node("Match").find_children("*", "InteractableDoor", true, false)
	if door == null and found.size() > 0:
		door = found[0]
	if door == null:
		print(FAIL_S, " door not found")
		quit(1)
		return

	var prompt: String = player.current_prompt()
	if prompt != "E — open door":
		print(FAIL_S, " prompt was '%s'" % prompt)
		quit(1)
		return

	player.try_interact()
	for i in 60:
		await physics_frame
	if not door.is_open():
		print(FAIL_S, " door did not open")
		quit(1)
		return
	var pivot: Node3D = door._pivot
	if absf(pivot.rotation.y) < 1.0:
		print(FAIL_S, " pivot not swung: %f" % pivot.rotation.y)
		quit(1)
		return
	var prompt_close: String = player.current_prompt()
	if prompt_close != "E — close door":
		print(FAIL_S, " close prompt was '%s'" % prompt_close)
		quit(1)
		return

	# Creak stream present and 3D player exists on the door.
	
	var found_audio := false
	for child in door.get_children():
		if child is AudioStreamPlayer3D and child.stream != null:
			found_audio = true
	if not found_audio:
		print(FAIL_S, " no creak audio player with stream")
		quit(1)
		return

	player.try_interact()
	for i in 60:
		await physics_frame
	if door.is_open():
		print(FAIL_S, " door did not close")
		quit(1)
		return

	print(PASS_S)
	quit(0)