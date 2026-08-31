extends Node
## Screenshot driver (evidence tooling, Vision 8 gate 2): loads a target
## scene inside a normal windowed project boot (autoloads active), waits for
## frames, saves the framebuffer, reports counters.
## Run: godot --path . res://tests/shot_driver.tscn -- shot=<scene> out=/tmp/shot.png
## Pure evidence collection — NOT a gameplay test; tools/test.sh does not load it.

var _frames := 0
var _wait := 40
var _pass := 1
var _out := "/tmp/shot.png"
var _out2 := ""
var _shot_name := "match"
var _panic := false


func _ready() -> void:
	var shot_scene_path := "res://scenes/match.tscn"
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "shot":
			_shot_name = kv[1]
			shot_scene_path = "res://scenes/%s.tscn" % kv[1]
		elif kv[0] == "out":
			_out = kv[1]
		elif kv[0] == "wait":
			_wait = int(kv[1])
		elif kv[0] == "panic":
			_panic = bool(kv[1])
		elif kv[0] == "out2":
			_out2 = kv[1]
	if not FileAccess.file_exists(shot_scene_path):
		push_error("shot driver: missing scene %s" % shot_scene_path)
		get_tree().quit(1)
		return
	var ps: PackedScene = load(shot_scene_path)
	get_tree().root.add_child(ps.instantiate())
	get_tree().root.move_child(get_tree().root.get_children()[-1], 0)


func _process(_delta: float) -> void:
	_frames += 1
	if _panic and _frames == 4 and _pass == 1:
		_stage_panic()
	if _frames < _wait:
		return
	var path := _out if _pass == 1 else _out2
	var img := get_viewport().get_texture().get_image()
	var ok := false
	if img and not img.is_empty():
		ok = img.save_png(path) == OK
	print("CAPTURE result=%s path=%s scene=%s size=%dx%d" % [
		"OK" if ok else "FAIL", path, _shot_name,
		img.get_width() if img else 0, img.get_height() if img else 0])
	if _pass == 1 and _out2 != "":
		_pass = 2
		_frames = 0
		return
	get_tree().quit(0 if ok else 1)


## Panic staging (Vision 6 evidence): teleport before the nearest door, aim
## the camera at it, force fear past the hysteresis on-ramp, then synthesize
## a held E key so the hold-to-interact charge is visibly mid-progress.
func _stage_panic() -> void:
	var m: Node = get_tree().root.get_node_or_null("Match")
	if m == null:
		print("CAPTURE panic=NO_MATCH")
		return
	var player: PlayerController = m.get_node("Player")
	var house: HouseBuilder = m.get("_house")
	var door: InteractableDoor = null
	var best := 999.0
	for d in house.find_children("*", "InteractableDoor", true, false):
		var dist: float = (d as Node3D).global_position.distance_to(player.global_position)
		if dist < best:
			best = dist
			door = d
	if door == null:
		print("CAPTURE panic=NO_DOOR")
		return
	player.global_position = door.global_position + Vector3(0, 0, 1.2)
	var cam: Camera3D = player.camera
	cam.look_at(door.global_position + Vector3(0, 1.0, 0))
	var fear: FearMeter = m.get_node("FearMeter")
	fear.fear = 88.0
	player.set_panic(true)
	player.panic_hold_target_s = 3.2
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	ev.pressed = true
	Input.parse_input_event(ev)