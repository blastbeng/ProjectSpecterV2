class_name Flashlight
extends Node3D
## Flashlight per Vision 5.8: viewmodel mesh + arm attached to the camera,
## SpotLight (~25 deg, ~12 m), battery drain/regen while off, click SFX,
## subtle viewmodel sway toward mouse motion and bob with movement.

signal battery_changed(ratio: float)

const DRAIN_PER_SEC := 2.2      # seconds of light per battery unit
const REGEN_PER_SEC := 0.8
const BATTERY_MAX := 100.0
const SPOT_ANGLE := 25.0
const SPOT_RANGE := 12.0

var _spot: SpotLight3D
var _arm_pivot: Node3D
var _off_arm: Node3D
var _click: AudioStreamWAV
var _click_player: AudioStreamPlayer
var _sway := Vector2.ZERO
var _bob_phase := 0.0
var enabled := true
var battery := BATTERY_MAX


func _ready() -> void:
	_build_viewmodel()
	_spot = SpotLight3D.new()
	_spot.spot_range = SPOT_RANGE
	# ~25 degree cone per Vision 5.8.
	_spot.spot_angle = SPOT_ANGLE
	_spot.light_color = Color(1.0, 0.94, 0.82)
	_spot.light_energy = 4.5
	_spot.spot_attenuation = 1.2
	_spot.shadow_enabled = true
	_spot.position = Vector3(0.0, -0.02, -0.05)
	_arm_pivot.add_child(_spot)

	_click = SfxGenerator.click()
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = _click
	add_child(_click_player)


func _build_viewmodel() -> void:
	# Arm pivot sits low-right of the camera view.
	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0.28, -0.25, -0.35)
	add_child(_arm_pivot)

	# Off-hand: second forearm rising from bottom-left to steady the
	# flashlight body (Vision 5.7: local player viewmodel arms).
	_off_arm = Node3D.new()
	_off_arm.position = Vector3(-0.30, -0.34, -0.33)
	add_child(_off_arm)
	var off_material := StandardMaterial3D.new()
	off_material.albedo_color = Color("39445c")
	off_material.roughness = 0.85
	var off_forearm := MeshInstance3D.new()
	var ofm := CapsuleMesh.new()
	ofm.radius = 0.037
	ofm.height = 0.36
	off_forearm.mesh = ofm
	off_forearm.material_override = off_material
	off_forearm.rotation_degrees = Vector3(62, 0, -38)
	off_forearm.position = Vector3(-0.06, -0.04, 0.12)
	_off_arm.add_child(off_forearm)
	var off_hand := MeshInstance3D.new()
	var ohm := BoxMesh.new()
	ohm.size = Vector3(0.075, 0.08, 0.12)
	off_hand.mesh = ohm
	var off_skin := StandardMaterial3D.new()
	off_skin.albedo_color = Color("c8a284")
	off_skin.roughness = 0.7
	off_hand.material_override = off_skin
	off_hand.position = Vector3(-0.005, 0.01, -0.055)
	off_hand.rotation_degrees = Vector3(12, 8, -6)
	_off_arm.add_child(off_hand)

	# Forearm: capsule angled forward, sleeve color dark.
	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color("3a4356")
	arm_mat.roughness = 0.85
	var arm := MeshInstance3D.new()
	var am := CapsuleMesh.new()
	am.radius = 0.035
	am.height = 0.34
	arm.mesh = am
	arm.material_override = arm_mat
	arm.rotation_degrees = Vector3(78, 0, 8)
	arm.position = Vector3(0.02, 0.02, 0.10)
	_arm_pivot.add_child(arm)

	# Hand block + flashlight cylinder body.
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color("c8a284")
	skin_mat.roughness = 0.7
	var hand := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.07, 0.075, 0.11)
	hand.mesh = hm
	hand.material_override = skin_mat
	hand.position = Vector3(0.0, 0.0, -0.06)
	_arm_pivot.add_child(hand)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color("2a2d33")
	body_mat.metallic = 0.35
	body_mat.roughness = 0.45
	var body := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.024
	bm.bottom_radius = 0.028
	bm.height = 0.17
	body.mesh = bm
	body.material_override = body_mat
	body.rotation_degrees = Vector3(90, 0, 0)
	body.position = Vector3(0.0, 0.01, -0.155)
	_arm_pivot.add_child(body)

	# Lens ring at the front, slightly emissive when on.
	var lens := MeshInstance3D.new()
	var lm := CylinderMesh.new()
	lm.top_radius = 0.03
	lm.bottom_radius = 0.026
	lm.height = 0.02
	lens.mesh = lm
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.85, 0.88, 0.9)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(0.9, 0.92, 0.95)
	lens_mat.emission_energy_multiplier = 1.4
	lens.material_override = lens_mat
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = Vector3(0.0, 0.01, -0.245)
	_arm_pivot.add_child(lens)


func toggle() -> void:
	if battery <= 0.0 and not enabled:
		return
	enabled = not enabled
	_spot.visible = enabled
	_click_player.pitch_scale = randf_range(0.9, 1.1)
	_click_player.play()


func is_on() -> bool:
	return enabled


func battery_ratio() -> float:
	return battery / BATTERY_MAX


## Called by the controller every frame with look delta and movement speed.
func update_viewmodel(look_delta: Vector2, speed: float, delta: float) -> void:
	# sway toward look motion, springing back
	_sway = _sway.lerp(-look_delta * 0.0006, clampf(10.0 * delta, 0.0, 1.0))
	if _sway.length() > 0.03:
		_sway = _sway.normalized() * 0.03
	_arm_pivot.position.x = 0.25 + _sway.x
	_arm_pivot.position.y = -0.25 + _sway.y * 0.6
	# slight bob while moving
	_bob_phase += delta * (6.0 + speed * 1.2)
	var move01 := clampf(speed / 4.0, 0.0, 1.0)
	_arm_pivot.position.z = -0.35 + sin(_bob_phase) * 0.008 * move01
	# Off-hand steadies the light: mirrors main-arm sway/bob, plus a slow
	# breathing drift when idle so the rig never looks frozen.
	_off_arm.position.x = -0.30 + _sway.x * 0.7 - sin(_bob_phase) * 0.006 * move01
	_off_arm.position.y = -0.34 + _sway.y * 0.45 + sin(_bob_phase + 0.9) * 0.005 * move01
	_off_arm.position.z = -0.33 + sin(_bob_phase * 0.5) * 0.004 * move01
	_off_arm.rotation.z = _sway.x * 0.5 + sin(_bob_phase * 0.33) * 0.01


func _physics_process(delta: float) -> void:
	if enabled and _spot.visible:
		battery = maxf(battery - delta * DRAIN_PER_SEC, 0.0)
		if battery <= 0.0:
			enabled = false
			_spot.visible = false
	else:
		battery = minf(battery + delta * REGEN_PER_SEC, BATTERY_MAX)
	battery_changed.emit(battery_ratio())