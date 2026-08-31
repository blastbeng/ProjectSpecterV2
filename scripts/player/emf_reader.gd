class_name EmfReader
extends Node3D
## EMF reader (Vision 5.8 + 6): handheld viewmodel tool held low-left by the
## camera, a five-bar LED screen texture updated live, and a beeper that
## pulses with reading strength. Reads strength from seeded EMF hotspots
## (planted by HouseBuilder) - readings scale with proximity to the nearest
## hotspot so investigators can triangulate the haunted room.

signal reading_changed(level_1to5: int, strength: float)

const BATTERY_MAX := 100.0
const DRAIN_PER_SEC := 0.9
## Level thresholds on strength [0..1] (Phasmophobia-style stepped meter).
const LEVELS: Array[float] = [0.0, 0.15, 0.38, 0.62, 0.85]
const READ_RATE := 3.5   # meters of falloff for a full-strength reading

var strength := 0.0
var level := 1
var battery := BATTERY_MAX
var enabled := true
var hotspots: Array = []  # Array of Dictionary {pos: Vector3, kind: String, room: String}
## Strongest hotspot of the latest sample() — {kind, room} for logging (F).
var strongest_hotspot: Dictionary = {}

var _screen_mat: StandardMaterial3D
var _img: Image
var _tex: ImageTexture
var _arm: Node3D
var _sway := Vector2.ZERO
var _bob_phase := 0.0
var _last_speed := 0.0
var _beep_player: AudioStreamPlayer
var _beep_cooldown := 0.0
var _on := false


func _ready() -> void:
	_img = Image.create(64, 128, false, Image.FORMAT_RGB8)
	_img.fill(Color(0.03, 0.07, 0.05))
	_tex = ImageTexture.create_from_image(_img)
	_build_viewmodel()
	_redraw_screen()
	_beep_player = AudioStreamPlayer.new()
	add_child(_beep_player)


func toggle(on_off: bool) -> void:
	_on = on_off


func is_on() -> bool:
	return _on


func set_hotspots(hs: Array) -> void:
	hotspots = hs


func battery_ratio() -> float:
	return battery / BATTERY_MAX


## Sample the environment every physics tick from the camera position.
func sample(camera_pos: Vector3, delta: float) -> void:
	if not enabled:
		return
	if _on and battery > 0.0:
		battery = maxf(battery - delta * DRAIN_PER_SEC, 0.0)
	if battery <= 0.0:
		if level != 1:
			level = 1
			reading_changed.emit(level, 0.0)
			_redraw_screen()
		return
	# Strength = closeness to the strongest hotspot (linear falloff, squared
	# so readings drop off sharply away from the source). The winning hotspot
	# is remembered so the journal logger knows WHAT was measured, not just
	# how strongly.
	var best := 0.0
	var best_hs: Dictionary = {}
	for hs in hotspots:
		var pos: Vector3 = hs["pos"]
		var s := 1.0 - clampf(camera_pos.distance_to(pos) / READ_RATE, 0.0, 1.0)
		s *= s
		if s > best:
			best = s
			best_hs = hs
	strength = best
	strongest_hotspot = best_hs
	var new_level := 1
	for i in range(LEVELS.size(), 0, -1):
		if strength >= LEVELS[i - 1] + 0.001:
			new_level = i
			break
	if new_level != level:
		level = new_level
		reading_changed.emit(level, strength)
		_redraw_screen()
	_tick_beep(delta)


func _tick_beep(delta: float) -> void:
	# Beeper pulses faster the stronger the reading; silent at level 1 or off.
	if not _on or level <= 1:
		_beep_cooldown = 0.35
		return
	if _beep_player.playing:
		return
	_beep_cooldown -= delta
	if _beep_cooldown <= 0.0:
		_beep_cooldown = lerpf(1.1, 0.14, clampf((level - 1) / 4.0, 0.0, 1.0))
		if _beep_player.stream == null:
			_beep_player.stream = SfxGenerator.emf_beep()
		_beep_player.pitch_scale = 1.0 + 0.12 * (level - 1)
		_beep_player.play()


## Five vertical LED bars + a blocky level digit, drawn bottom-up into the
## 64x128 image re-uploaded to the live screen texture.
func _redraw_screen() -> void:
	_img.fill(Color(0.02, 0.05, 0.04))
	var lit := level - 1  # 0..4 bars glowing
	for b in range(5):
		var x0 := 4 + b * 12
		var fill_height := int(96.0 * float(b + 1) / 5.0)
		var y0 := 118 - fill_height
		var c := Color(0.06, 0.14, 0.10)
		if b < lit:
			c = Color(0.25, 0.9, 0.35)
			if b >= 2:
				c = Color(0.95, 0.85, 0.25)
			if b == 4:
				c = Color(0.95, 0.3, 0.2)
		for y in range(y0, 119):
			for x in range(x0, x0 + 9):
				_img.set_pixel(x, y, c)
	_digit(48, 104, level)
	# Scanline shading for a cheap CRT feel.
	for y in range(0, 128, 3):
		for x in range(64):
			_img.set_pixel(x, y, _img.get_pixel(x, y).darkened(0.35))
	_tex.update(_img)


func _digit(ox: int, oy: int, digit: int) -> void:
	# 3x5 blocky glyphs for 1..5 (3 px cell, 2 px row pitch).
	var glyphs := {
		1: [[0, 1], [1, 1], [2, 1], [1, 0], [1, 2], [1, 3], [0, 4], [1, 4], [2, 4]],
		2: [[0, 0], [1, 0], [2, 0], [2, 1], [0, 2], [1, 2], [2, 2], [0, 3], [0, 4], [1, 4], [2, 4]],
		3: [[0, 0], [1, 0], [2, 0], [2, 1], [0, 2], [1, 2], [2, 2], [2, 3], [0, 4], [1, 4], [2, 4]],
		4: [[0, 0], [0, 1], [1, 1], [2, 1], [0, 2], [1, 2], [2, 2], [2, 3], [2, 4]],
		5: [[0, 0], [1, 0], [2, 0], [0, 1], [0, 2], [1, 2], [2, 2], [2, 3], [0, 4], [1, 4], [2, 4]],
	}
	var g: Array = glyphs.get(maxi(1, mini(5, digit)), [])
	var c := Color(0.9, 0.95, 0.8) if level > 1 else Color(0.08, 0.2, 0.14)
	for cell in g:
		for dy in range(2):
			for dx in range(3):
				_img.set_pixel(ox + cell[0] * 3 + dx, oy + cell[1] * 2 + dy, c)


func update_viewmodel(look_delta: Vector2, speed: float, delta: float) -> void:
	if _arm == null:
		return
	_last_speed = speed
	_sway = _sway.lerp(-look_delta * 0.0006, clampf(10.0 * delta, 0.0, 1.0))
	if _sway.length() > 0.03:
		_sway = _sway.normalized() * 0.03
	_bob_phase += delta * (6.0 + speed * 1.2)
	var move01 := clampf(speed / 4.0, 0.0, 1.0)
	_arm.position.x = 0.24 + _sway.x
	_arm.position.y = -0.13 + _sway.y * 0.6 + sin(_bob_phase) * 0.008 * move01
	_arm.position.z = -0.32 + sin(_bob_phase + 0.7) * 0.006 * move01
	# Held upright while powered; rolled 30 deg down when stowed.
	_arm.rotation.z = lerpf(_arm.rotation.z, -0.12 if _on else 0.5, clampf(8.0 * delta, 0.0, 1.0))


## Left-hand rig: forearm rising from bottom-left, hand gripping the reader
## box, live screen quad facing the camera (Vision 5.8 tool pattern).
func _build_viewmodel() -> void:
	_arm = Node3D.new()
	_arm.position = Vector3(0.24, -0.13, -0.32)
	add_child(_arm)

	var arm_mat := StandardMaterial3D.new()
	arm_mat.albedo_color = Color("39445c")
	arm_mat.roughness = 0.85
	var forearm := MeshInstance3D.new()
	var fm := CapsuleMesh.new()
	fm.radius = 0.036
	fm.height = 0.34
	forearm.mesh = fm
	forearm.material_override = arm_mat
	forearm.rotation_degrees = Vector3(64, 6, -30)
	forearm.position = Vector3(0.04, -0.09, 0.10)
	_arm.add_child(forearm)

	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color("c8a284")
	skin_mat.roughness = 0.7
	var hand := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.09, 0.07, 0.09)
	hand.mesh = hm
	hand.material_override = skin_mat
	hand.position = Vector3(0.0, 0.0, -0.02)
	_arm.add_child(hand)

	# Reader body: dark case + antenna.
	var case_mat := StandardMaterial3D.new()
	case_mat.albedo_color = Color("23262c")
	case_mat.metallic = 0.3
	case_mat.roughness = 0.5
	var case_mi := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.085, 0.15, 0.045)
	case_mi.mesh = cm
	case_mi.material_override = case_mat
	case_mi.position = Vector3(0.0, 0.075, -0.045)
	_arm.add_child(case_mi)

	var ant := MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.003
	am.bottom_radius = 0.004
	am.height = 0.09
	ant.mesh = am
	ant.material_override = case_mat
	ant.position = Vector3(0.03, 0.18, -0.05)
	_arm.add_child(ant)

	# Live screen (emissive so it reads in the dark).
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.albedo_texture = _tex
	_screen_mat.roughness = 0.35
	_screen_mat.emission_enabled = true
	_screen_mat.emission = Color(0.9, 1.0, 0.92)
	_screen_mat.emission_energy_multiplier = 1.5
	var screen := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(0.056, 0.112)
	screen.mesh = sq
	screen.material_override = _screen_mat
	screen.position = Vector3(0.0, 0.082, -0.019)
	_arm.add_child(screen)
	_arm.rotation.x = 0.28  # tilt toward the eye axis for legibility


func _process(_delta: float) -> void:
	# Screen flicker breathes with reading strength so the tool feels alive.
	if _screen_mat != null:
		_screen_mat.emission_energy_multiplier = 1.2 + 0.6 * strength + 0.1 * sin(Time.get_ticks_msec() / 60.0)