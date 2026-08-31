class_name InteractableDoor
extends StaticBody3D
## Hinged swinging door (Vision 5.6/5.8 base): frame, paneled leaf hung on a
## Node3D pivot at the hinge edge, knob mesh, generated creak on open/close.
## Interaction (Vision 6 counterplay groundwork): E toggles with a swing tween.

signal state_changed(open: bool)

const OPEN_ANGLE := deg_to_rad(105.0)

var _pivot: Node3D
var _open := false
var _creak: AudioStreamWAV
var _player: AudioStreamPlayer3D


func _init(door_width := 0.95, door_height := 2.05, face := 0.0) -> void:
	# Door assembly centered at origin; hinge (pivot) sits at the left jamb.
	_build_frame(door_width, door_height)
	_build_leaf(door_width, door_height)
	rotation.y = face


func _build_frame(w: float, h: float) -> void:
	var jamb := MaterialFactory.trim()
	for px in [-0.075, w + 0.075]:
		var side := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.15, h + 0.05, 0.22)
		side.mesh = sm
		side.material_override = jamb
		side.position = Vector3(px, (h + 0.05) / 2.0, 0.0)
		add_child(side)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(w + 0.30, 0.12, 0.22)
	head.mesh = hm
	head.material_override = jamb
	head.position = Vector3(w / 2.0, h + 0.05, 0.0)
	add_child(head)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w + 0.30, h + 0.10, 0.24)
	cs.shape = shape
	cs.position = Vector3(w / 2.0, (h + 0.10) / 2.0, 0.0)
	add_child(cs)


func _build_leaf(w: float, h: float) -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, 0, 0)  # hinge at left jamb face
	add_child(_pivot)

	var leaf_mat := MaterialFactory.grime(Color("7a6a50"), 0.7, 0.07)
	var leaf := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(w, h, 0.05)
	leaf.mesh = lm
	leaf.material_override = leaf_mat
	leaf.position = Vector3(w / 2.0, h / 2.0, 0.0)
	_pivot.add_child(leaf)

	# Two inset panels for readability
	var panel_mat := MaterialFactory.grime(Color("4a3b2d").darkened(0.12), 0.75, 0.08)
	for py in [h * 0.28, h * 0.72]:
		var panel := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(w * 0.62, h * 0.30, 0.02)
		panel.mesh = pm
		panel.material_override = panel_mat
		panel.position = Vector3(w / 2.0, py, 0.035)
		_pivot.add_child(panel)

	# Knob on both faces
	var knob_mat := MaterialFactory.metal()
	for kz in [0.05, -0.05]:
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.035
		km.height = 0.07
		knob.mesh = km
		knob.material_override = knob_mat
		knob.position = Vector3(w - 0.12, 1.02, kz)
		_pivot.add_child(knob)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, h, 0.12)
	cs.shape = shape
	cs.position = Vector3(w / 2.0, h / 2.0, 0.0)
	_pivot.add_child(cs)


func _ready() -> void:
	_creak = SfxGenerator.creak(3)
	_player = AudioStreamPlayer3D.new()
	_player.stream = _creak
	_player.position = Vector3(0.4, 1.2, 0)
	_player.max_db = 3.0
	add_child(_player)


func is_open() -> bool:
	return _open


func toggle() -> void:
	_open = not _open
	_player.pitch_scale = randf_range(0.85, 1.15)
	_player.play()
	var target := OPEN_ANGLE if _open else 0.0
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation:y", target, 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	state_changed.emit(_open)


func interaction_prompt() -> String:
	return "E — open door" if not _open else "E — close door"