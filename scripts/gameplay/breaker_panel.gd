class_name BreakerPanel
extends StaticBody3D
## "Restore power" objective (Vision 6): a wall breaker panel inside the
## seed-locked room. Interacting flips the main breaker — lever rotates,
## screen texture turns green, a rising power-up sound plays, and the
## locked hall door into this room unlocks. Match listens to power_restored.

signal power_restored

var _screen: MeshInstance3D
var _screen_mat: StandardMaterial3D
var _lever: Node3D
var _flipped := false
var _audio: AudioStreamPlayer3D
var _on_stream: AudioStreamWAV


func _init() -> void:
	_build_panel()


func _build_panel() -> void:
	# Steel cabinet: 0.7 x 1.0 x 0.18 at chest height (Vision 5.3 scale).
	var steel := MaterialFactory.metal()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 1.0, 0.18)
	body.mesh = bm
	body.material_override = steel
	body.position = Vector3(0, 1.45, 0)
	add_child(body)

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.78, 1.08, 0.26)
	cs.shape = shape
	cs.position = Vector3(0, 1.45, 0)
	add_child(cs)

	# Dark screen with a thin bezel; switches to green on restore.
	_screen = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.5, 0.36, 0.02)
	_screen.mesh = sm
	_screen.material_override = _screen_mat_off()
	_screen.position = Vector3(0, 1.66, 0.1)
	add_child(_screen)

	# Row of breaker switches (red handled), flip to upright on restore.
	var red := MaterialFactory.grime(Color("8a2020"), 0.55, 0.2)
	for i in 4:
		var sw := MeshInstance3D.new()
		var swm := BoxMesh.new()
		swm.size = Vector3(0.07, 0.16, 0.06)
		sw.mesh = swm
		sw.material_override = red
		sw.position = Vector3(-0.18 + 0.12 * i, 1.28, 0.1)
		add_child(sw)

	# Main lever on a pivot at its base; rotates -70 -> 0 deg on flip.
	_lever = Node3D.new()
	_lever.position = Vector3(0.0, 1.2, 0.1)
	add_child(_lever)
	var stick := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(0.05, 0.26, 0.05)
	stick.mesh = stm
	stick.material_override = MaterialFactory.metal()
	stick.position = Vector3(0, 0.13, 0)
	_lever.add_child(stick)
	var grip := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.09, 0.05, 0.06)
	grip.mesh = gm
	grip.material_override = MaterialFactory.grime(Color("c9b458").darkened(0.3), 0.4, 0.3)
	grip.position = Vector3(0, 0.26, 0)
	_lever.add_child(grip)
	_lever.rotation.x = deg_to_rad(-70.0)  # tripped (down) pose


func _screen_mat_off() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("101418")
	m.emission_enabled = true
	m.emission = Color("3a1010")
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.35
	return m


func _screen_mat_on() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("0e1a10")
	m.emission_enabled = true
	m.emission = Color("2f9e44")
	m.emission_energy_multiplier = 2.2
	m.roughness = 0.35
	return m


func _ready() -> void:
	_on_stream = SfxGenerator.power_up(1)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _on_stream
	_audio.position = Vector3(0, 1.5, 0.2)
	_audio.max_db = 6.0
	add_child(_audio)


func is_restored() -> bool:
	return _flipped


func interaction_prompt() -> String:
	if _flipped:
		return ""
	return "E — restore power"


func interact() -> void:
	if _flipped:
		return
	_flipped = true
	_screen.material_override = _screen_mat_on()
	var tw := create_tween()
	tw.tween_property(_lever, "rotation:x", 0.0, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_audio.pitch_scale = randf_range(0.95, 1.05)
	_audio.play()
	power_restored.emit()