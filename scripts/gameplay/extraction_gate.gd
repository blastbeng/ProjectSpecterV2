class_name ExtractionGate
extends StaticBody3D
## Extraction gate (Vision 6 loop end): a marked doorway device in the hall.
## Inactive = red emissive sign, solid frame blocker. activate() flips the
## sign green and lets the player interact to start the escape countdown;
## Match owns the timer (HUD) and the escape outcome.

signal extraction_started

var _active := false
var _started := false
var _sign_mat: StandardMaterial3D
var _sign: MeshInstance3D
var _barrier: StaticBody3D
var _audio: AudioStreamPlayer3D
var _beep: AudioStreamWAV
var _led_mat: StandardMaterial3D


func _init() -> void:
	# Frame: two jambs + head, warm trim; stands free in the hall.
	var trim := MaterialFactory.trim()
	var metal := MaterialFactory.metal()
	for jx in [-0.62, 0.62]:
		var jamb := MeshInstance3D.new()
		var jm := BoxMesh.new()
		jm.size = Vector3(0.16, 2.5, 0.22)
		jamb.mesh = jm
		jamb.material_override = trim
		jamb.position = Vector3(jx, 1.25, 0)
		add_child(jamb)
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(1.56, 0.18, 0.22)
	head.mesh = hm
	head.material_override = trim
	head.position = Vector3(0, 2.5, 0)
	add_child(head)

	# Emissive sign plate above the head: red standby / green live.
	_sign = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.9, 0.24, 0.05)
	_sign.mesh = sm
	_sign_mat = StandardMaterial3D.new()
	_sign_mat.albedo_color = Color("1a0808")
	_sign_mat.emission_enabled = true
	_sign_mat.emission = Color("6e1010")
	_sign_mat.emission_energy_multiplier = 2.4
	_sign.material_override = _sign_mat
	_sign.position = Vector3(0, 2.82, 0)
	add_child(_sign)
	# Sign backboard (dark frame).
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, 0.3, 0.03)
	board.mesh = bm
	board.material_override = metal
	board.position = Vector3(0, 2.82, -0.02)
	add_child(board)

	# Device box under the sign on the active side.
	var device := MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.34, 0.5, 0.16)
	device.mesh = dm
	device.material_override = metal
	device.position = Vector3(0.52, 1.4, 0.14)
	add_child(device)
	var led := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.03
	lm.height = 0.06
	led.mesh = lm
	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = Color("200808")
	_led_mat.emission_enabled = true
	_led_mat.emission = Color("6e1010")
	_led_mat.emission_energy_multiplier = 2.0
	led.material_override = _led_mat
	led.position = Vector3(0.52, 1.62, 0.23)
	add_child(led)

	# Collision: jamb bars always block; the middle barrier drops on escape.
	for jx in [-0.52, 0.52]:
		var jbody := CollisionShape3D.new()
		var jshape := BoxShape3D.new()
		jshape.size = Vector3(0.2, 2.5, 0.24)
		jbody.shape = jshape
		jbody.position = Vector3(jx, 1.25, 0)
		add_child(jbody)
	_barrier = StaticBody3D.new()
	_barrier.name = "Barrier"
	var bcs := CollisionShape3D.new()
	var bshape := BoxShape3D.new()
	bshape.size = Vector3(0.86, 2.4, 0.14)
	bcs.shape = bshape
	bcs.position = Vector3(0, 1.2, 0)
	_barrier.add_child(bcs)
	add_child(_barrier)
	# Device box solid collision.
	var dcs := CollisionShape3D.new()
	var dshape := BoxShape3D.new()
	dshape.size = Vector3(0.36, 0.52, 0.18)
	dcs.shape = dshape
	dcs.position = Vector3(0.52, 1.4, 0.14)
	add_child(dcs)


func _ready() -> void:
	_beep = SfxGenerator.click()
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _beep
	_audio.position = Vector3(0.52, 1.7, 0.1)
	_audio.max_db = 4.0
	add_child(_audio)


func is_active() -> bool:
	return _active


func is_started() -> bool:
	return _started


func interaction_prompt() -> String:
	if _started:
		return ""
	if _active:
		return "E — start extraction countdown"
	return ""


## Objectives complete: sign turns green, countdown can be armed.
func activate() -> void:
	if _active or _started:
		return
	_active = true
	_sign_mat.emission = Color("2f9e44")
	_sign_mat.emission_energy_multiplier = 2.8
	_led_mat.emission = Color("2f9e44")
	_audio.pitch_scale = 1.4
	_audio.play()


func interact() -> void:
	if not _active or _started:
		return
	_started = true
	_barrier.collision_layer = 0  # drop the middle barrier: escape is open
	_audio.pitch_scale = 1.9
	_audio.play()
	extraction_started.emit()


func deactivate() -> void:
	_active = false
	_sign_mat.emission = Color("6e1010")
	_sign_mat.emission_energy_multiplier = 2.4
	_led_mat.emission = Color("6e1010")