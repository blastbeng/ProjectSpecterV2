class_name InteractableDoor
extends StaticBody3D
## Hinged swinging door (Vision 5.6/5.8 base): frame, paneled leaf hung on a
## Node3D pivot at the hinge edge, knob mesh, generated creak on open/close.
## Interaction (Vision 6 counterplay groundwork): E toggles with a swing tween.

signal state_changed(open: bool)
signal lock_changed()

const OPEN_ANGLE := deg_to_rad(105.0)

var _pivot: Node3D
var _open := false
var _locked := false
var _padlock: MeshInstance3D
var _has_shackle := false
var _creak: AudioStreamWAV
var _rattle: AudioStreamWAV
var _unlock: AudioStreamWAV
var _slam_stream: AudioStreamWAV
var _player: AudioStreamPlayer3D
## Rooms this door connects (portal wiring): ["Hall", "Storage"].
## Filled by HouseBuilder when the building is assembled.
var portal_rooms: PackedStringArray = []


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
	_rattle = SfxGenerator.rattle(3)
	_unlock = SfxGenerator.unlock(3)
	_player = AudioStreamPlayer3D.new()
	_player.stream = _creak
	_player.position = Vector3(0.4, 1.2, 0)
	_player.max_db = 3.0
	add_child(_player)


func is_open() -> bool:
	return _open


func is_locked() -> bool:
	return _locked


## Locked variant (Vision 6 objectives): a locked door shows a padlock on the
## hall face and refuses to swing until unlocked. Entity door-powers later
## call unlock()/lock() directly.
func set_locked(locked: bool, show_pad := true) -> void:
	_locked = locked
	if _padlock == null and show_pad:
		_add_padlock()
	if _padlock != null:
		_padlock.visible = locked
	lock_changed.emit()


## One-way entry: this room's door is always lockable from the hall side
## (Vision 6 groundwork for "entity blocks a room").
func unlock() -> void:
	if not _locked:
		return
	_locked = false
	if _padlock != null:
		_padlock.visible = false
	lock_changed.emit()


func lock() -> void:
	if _open:
		return  # cannot lock a swinging leaf
	if _padlock == null:
		_add_padlock()
	_locked = true
	if _padlock != null:
		_padlock.visible = true
	lock_changed.emit()


func toggle() -> void:
	interact()


## Unified interaction entry point: rattle -> unlock -> swing.
func interact() -> void:
	if _locked:
		_player.stream = _rattle
		_player.pitch_scale = 1.0
		_player.play()
		return
	_open = not _open
	_player.stream = _creak
	_player.pitch_scale = randf_range(0.85, 1.15)
	_player.play()
	var target := OPEN_ANGLE if _open else 0.0
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation:y", target, 0.55) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	state_changed.emit(_open)


## Entity power (Vision 6): force the leaf shut instantly with a heavy slam.
## Works even when the leaf is locked (the entity ignores padlocks).
func entity_slam() -> void:
	if not _open:
		# Closed door: hard rattle instead.
		_player.stream = _rattle
		_player.pitch_scale = 0.8
		_player.play()
		return
	_open = false
	var tw := create_tween()
	tw.tween_property(_pivot, "rotation:y", 0.0, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if _slam_stream == null:
		_slam_stream = SfxGenerator.slam(1)
	_player.stream = _slam_stream
	_player.pitch_scale = randf_range(0.92, 1.05)
	_player.play()
	state_changed.emit(false)


func interaction_prompt() -> String:
	if _locked:
		return "E — locked"
	return "E — open door" if not _open else "E — close door"


## Padlock on the hall-face knob side: body box + U-shackle made of three
## thin metal boxes, hung on the leaf so it swings with the door.
func _add_padlock() -> void:
	_has_shackle = true
	var w := 0.95
	_padlock = MeshInstance3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.10, 0.13, 0.035)
	_padlock.mesh = body
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6e6a5f")
	mat.metallic = 0.75
	mat.roughness = 0.45
	_padlock.material_override = mat
	# Hang from the knob, below it, proud of the leaf face.
	_padlock.position = Vector3(w - 0.12, 0.92, 0.075)
	var lock_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.11, 0.20, 0.05)
	cs.shape = shape
	cs.position = Vector3(0, 0.035, 0)
	lock_body.add_child(cs)
	_padlock.add_child(lock_body)
	for o in [-0.035, 0.035]:
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.012, 0.06, 0.012)
		arm.mesh = am
		arm.material_override = mat
		arm.position = Vector3(o, 0.075, 0)
		_padlock.add_child(arm)
	var arm_top := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.082, 0.012, 0.012)
	arm_top.mesh = tm
	arm_top.material_override = mat
	arm_top.position = Vector3(0, 0.10, 0)
	_padlock.add_child(arm_top)
	_pivot.add_child(_padlock)