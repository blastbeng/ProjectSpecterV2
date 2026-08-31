extends Node
## SceneRouter: central scene switcher for Project Specter 3D.
## All screen changes go through SceneRouter.goto() so each scene can prepare
## its own UI/state. Kept intentionally small; gameplay routing is added later.

signal scene_changed(scene_path: String)

var current_scene_path: String = ""

func goto(scene_path: String) -> void:
	if scene_path == current_scene_path:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: unknown scene %s" % scene_path)
		return
	var tree := get_tree()
	# Deferred: callers may route during _ready(), when the tree is busy.
	tree.change_scene_to_file.call_deferred(scene_path)
	current_scene_path = scene_path
	scene_changed.emit(scene_path)