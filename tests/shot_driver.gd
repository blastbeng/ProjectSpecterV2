extends Node
## Screenshot driver (evidence tooling, Vision 8 gate 2): loads a target
## scene inside a normal windowed project boot (autoloads active), waits for
## frames, saves the framebuffer, reports counters.
## Run: godot --path . res://tests/shot_driver.tscn -- shot=<scene> out=/tmp/shot.png
## Pure evidence collection — NOT a gameplay test; tools/test.sh does not load it.

var _frames := 0
var _wait := 40
var _out := "/tmp/shot.png"
var _shot_name := "match"


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
	if not FileAccess.file_exists(shot_scene_path):
		push_error("shot driver: missing scene %s" % shot_scene_path)
		get_tree().quit(1)
		return
	var ps: PackedScene = load(shot_scene_path)
	get_tree().root.add_child(ps.instantiate())
	get_tree().root.move_child(get_tree().root.get_children()[-1], 0)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames >= _wait:
		var img := get_viewport().get_texture().get_image()
		var ok := false
		if img and not img.is_empty():
			ok = img.save_png(_out) == OK
		print("CAPTURE result=%s path=%s scene=%s size=%dx%d" % [
			"OK" if ok else "FAIL", _out, _shot_name,
			img.get_width() if img else 0, img.get_height() if img else 0])
		get_tree().quit(0 if ok else 1)