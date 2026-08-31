class_name InvestigatorAvatar
extends Node3D
## Investigator humanoid (Vision 5.7): primitive segments hung on Node3D
## pivots, code-made detailed face texture, procedural walk/idle animation.
## Mesh child of every pivot is offset half its length down, so rotating the
## pivot swings the limb. Used for remote players, bots and a demo avatar.

const HEAD_Y := 1.58
const SHOULDER_Y := 1.42
const HIP_Y := 0.99

const SKINS: Array[Color] = [Color("c8a284"), Color("d3ac8c"), Color("a8764f"), Color("7c4a2d")]
const JACKETS: Array[Color] = [Color("41506b"), Color("4a443b"), Color("474f44"), Color("5a4550")]
const PANTS_C := Color("2c3138")
const BOOT_C := Color("1e2126")
const HAIR_C := Color("241a12")

static var _face_cache: Dictionary = {}

var player_index := 0
var display_name := ""
var _speed := 0.0
var _crouching := false

var _rig: Node3D
var _torso: Node3D
var _head: Node3D
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _phase := 0.0
var _breath := 0.0
var _walk01 := 0.0
var _crouch01 := 0.0


## Public drive API (network avatars / bots call this every frame).
func drive(speed: float, sprinting := false, crouching := false) -> void:
	_speed = speed
	_crouching = crouching and not sprinting


func _ready() -> void:
	_build_rig()


func _cloth(color: Color, rough := 0.88) -> StandardMaterial3D:
	return MaterialFactory.grime(color, rough, 0.18)


func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	return mi


## Detailed face per Vision 5.7/5.11: shading, brows, eyes with whites+iris,
## nose, lips, stubble and hair band — all from a pixel loop; cached per skin.
static func face_texture_detailed(skin: Color, seed_value := 0) -> ImageTexture:
	var key := "faced:%s/%d" % [skin.to_html(), seed_value]
	if _face_cache.has(key):
		return _face_cache[key]
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 17
	# Base skin with left/right shading, jaw shadow, brow highlight.
	for y in range(128):
		for x in range(128):
			var shade := 1.0 - 0.14 * absf(float(x) / 127.0 - 0.5)
			shade -= 0.10 * float(y > 98)
			shade += 0.05 * float(y < 30)
			img.set_pixel(x, y, Color(skin.r * shade, skin.g * shade, skin.b * shade))
	# Eye sockets (dark) then whites then iris.
	for y in range(52, 66):
		for x in range(32, 52):
			img.set_pixel(x, y, skin.darkened(0.4))
		for x in range(76, 96):
			img.set_pixel(x, y, skin.darkened(0.4))
	for y in range(55, 63):
		for x in range(35, 49):
			img.set_pixel(x, y, Color(0.75, 0.76, 0.72))
		for x in range(79, 93):
			img.set_pixel(x, y, Color(0.75, 0.76, 0.72))
	for y in range(57, 62):
		for x in range(40, 43):
			img.set_pixel(x, y, Color(0.28, 0.34, 0.38))
		for x in range(84, 87):
			img.set_pixel(x, y, Color(0.28, 0.34, 0.38))
		for x in range(42, 44):
			img.set_pixel(x, y, Color(0.1, 0.1, 0.12))
		for x in range(86, 88):
			img.set_pixel(x, y, Color(0.1, 0.1, 0.12))
	# Brows.
	for x in range(33, 51):
		img.set_pixel(x, 50, skin.darkened(0.62))
		img.set_pixel(x, 51, skin.darkened(0.62))
		img.set_pixel(x + 44, 50, skin.darkened(0.62))
		img.set_pixel(x + 44, 51, skin.darkened(0.62))
	# Nose bridge + nostrils.
	for y in range(68, 77):
		for x in range(61, 67):
			img.set_pixel(x, y, skin.darkened(0.12))
	for x in range(60, 63):
		img.set_pixel(x, 76, skin.darkened(0.5))
	for x in range(65, 68):
		img.set_pixel(x, 76, skin.darkened(0.5))
	# Lips.
	for x in range(48, 80):
		img.set_pixel(x, 88, Color(0.34, 0.13, 0.13))
	for x in range(51, 77):
		img.set_pixel(x, 90, Color(0.245, 0.1, 0.1))
	# Stubble speckle on jaw.
	for i in range(420):
		var x := rng.randi_range(38, 90)
		var y := rng.randi_range(93, 112)
		img.set_pixel(x, y, skin.darkened(rng.randf_range(0.22, 0.38)))
	# Hair band across the top + sideburns.
	for y in range(0, 15):
		for x in range(8, 120):
			img.set_pixel(x, y, HAIR_C if x % 9 != 0 else HAIR_C.lightened(0.08))
	for y in range(15, 24):
		for x in range(10, 28):
			if rng.randf() < 0.55: img.set_pixel(x, y, HAIR_C)
		for x in range(100, 118):
			if rng.randf() < 0.55: img.set_pixel(x, y, HAIR_C)
	var tex := ImageTexture.create_from_image(img)
	_face_cache[key] = tex
	return tex


func _build_rig() -> void:
	var skin := SKINS[player_index % SKINS.size()]
	var jacket_c := JACKETS[player_index % JACKETS.size()]
	var jacket := _cloth(jacket_c)
	var pants := _cloth(PANTS_C)
	var boots := _cloth(BOOT_C, 0.6)
	var skin_m := MaterialFactory.grime(skin, 0.72, 0.35)

	_rig = Node3D.new()
	add_child(_rig)

	# Torso: hip block + chest block + backpack silhouette.
	_torso = Node3D.new()
	_rig.add_child(_torso)
	var hip_box := _mesh(BoxMesh.new(), pants)
	(hip_box.mesh as BoxMesh).size = Vector3(0.34, 0.26, 0.21)
	hip_box.position = Vector3(0, 1.06, 0)
	_torso.add_child(hip_box)
	var chest := _mesh(BoxMesh.new(), jacket)
	(chest.mesh as BoxMesh).size = Vector3(0.40, 0.38, 0.24)
	chest.position = Vector3(0, 1.31, 0)
	_torso.add_child(chest)
	var pack := _mesh(BoxMesh.new(), _cloth(Color("2a2d24"), 0.9))
	(pack.mesh as BoxMesh).size = Vector3(0.26, 0.30, 0.13)
	pack.position = Vector3(0, 1.28, 0.16)
	_torso.add_child(pack)

	# Head: skull sphere, textured face card slightly proud of it, hair cap.
	_head = Node3D.new()
	_head.position = Vector3(0, HEAD_Y, 0)
	_rig.add_child(_head)
	var skull := _mesh(SphereMesh.new(), skin_m)
	(skull.mesh as SphereMesh).radius = 0.115
	(skull.mesh as SphereMesh).height = 0.23
	_head.add_child(skull)
	# Neck between shoulders and skull.
	var neck := _mesh(CylinderMesh.new(), skin_m)
	(neck.mesh as CylinderMesh).top_radius = 0.045
	(neck.mesh as CylinderMesh).bottom_radius = 0.055
	(neck.mesh as CylinderMesh).height = 0.12
	neck.position = Vector3(0, 1.50, 0)
	_rig.add_child(neck)
	var face := _mesh(BoxMesh.new(), null)
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_texture = face_texture_detailed(skin, player_index)
	face_mat.roughness = 0.7
	face.material_override = face_mat
	# Avatar forward is -z (Godot look_at convention), so the face card sits
	# proud of the skull on the -z side, rotated to face outward.
	(face.mesh as BoxMesh).size = Vector3(0.225, 0.22, 0.03)
	face.position = Vector3(0, 0.004, -0.102)
	face.rotation.y = PI
	_head.add_child(face)
	var hair := _mesh(CylinderMesh.new(), _cloth(HAIR_C, 0.95))
	(hair.mesh as CylinderMesh).top_radius = 0.098
	(hair.mesh as CylinderMesh).bottom_radius = 0.126
	(hair.mesh as CylinderMesh).height = 0.075
	hair.position = Vector3(0, 0.088, -0.032)
	_head.add_child(hair)

	# Arms and legs: pivot -> capsule child offset half-length down.
	for side in [-1.0, 1.0]:
		var sh := Node3D.new()
		sh.position = Vector3(0.25 * side, SHOULDER_Y, 0)
		_rig.add_child(sh)
		_shoulders.append(sh)
		var upper := _mesh(CapsuleMesh.new(), jacket)
		(upper.mesh as CapsuleMesh).radius = 0.05
		(upper.mesh as CapsuleMesh).height = 0.30
		upper.position = Vector3(0, -0.15, 0)
		sh.add_child(upper)
		var el := Node3D.new()
		el.position = Vector3(0, -0.30, 0)
		sh.add_child(el)
		_elbows.append(el)
		var fore := _mesh(CapsuleMesh.new(), jacket)
		(fore.mesh as CapsuleMesh).radius = 0.042
		(fore.mesh as CapsuleMesh).height = 0.28
		fore.position = Vector3(0, -0.14, 0)
		el.add_child(fore)
		var hand := _mesh(BoxMesh.new(), skin_m)
		(hand.mesh as BoxMesh).size = Vector3(0.06, 0.11, 0.08)
		hand.position = Vector3(0, -0.31, 0.012)
		el.add_child(hand)

		var hip := Node3D.new()
		hip.position = Vector3(0.095 * side, HIP_Y, 0)
		_rig.add_child(hip)
		_hips.append(hip)
		var thigh := _mesh(CapsuleMesh.new(), pants)
		(thigh.mesh as CapsuleMesh).radius = 0.068
		(thigh.mesh as CapsuleMesh).height = 0.48
		thigh.position = Vector3(0, -0.24, 0)
		hip.add_child(thigh)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.48, 0)
		hip.add_child(knee)
		_knees.append(knee)
		var shin := _mesh(CapsuleMesh.new(), pants)
		(shin.mesh as CapsuleMesh).radius = 0.055
		(shin.mesh as CapsuleMesh).height = 0.42
		shin.position = Vector3(0, -0.21, 0)
		knee.add_child(shin)
		var boot := _mesh(BoxMesh.new(), boots)
		(boot.mesh as BoxMesh).size = Vector3(0.11, 0.09, 0.24)
		boot.position = Vector3(0, -0.42 - 0.045, 0.05)
		knee.add_child(boot)


func _process(delta: float) -> void:
	_breath += delta
	# walk01: 0 idle, ~1 walk, ~1.45 sprint (drives amplitude).
	var walk_target := 0.0 if _speed < 0.15 else clampf(_speed / 3.2, 0.0, 1.45)
	_walk01 = lerpf(_walk01, walk_target, clampf(6.0 * delta, 0.0, 1.0))
	_crouch01 = lerpf(_crouch01, 1.0 if _crouching else 0.0, clampf(8.0 * delta, 0.0, 1.0))

	if _walk01 > 0.03:
		_phase += delta * (4.6 + _speed * 1.5)

	var swing := sin(_phase)
	# Legs: hips swing opposite phases; knees flex while the leg trails.
	_hips[0].rotation.x = swing * 0.5 * _walk01 + 0.85 * _crouch01
	_hips[1].rotation.x = -swing * 0.5 * _walk01 + 0.85 * _crouch01
	_knees[0].rotation.x = -maxf(sin(_phase - 0.6), 0.0) * 0.7 * _walk01 - 1.1 * _crouch01
	_knees[1].rotation.x = -maxf(sin(_phase + PI - 0.6), 0.0) * 0.7 * _walk01 - 1.1 * _crouch01

	# Arms: swing opposite same-side legs, elbows bend more when forward.
	_shoulder_base(0, -swing)
	_shoulder_base(1, swing)

	# Body bob + breathing + subtle roll; crouch lowers the whole rig with
	# knees folded so feet stay near the floor.
	_torso.position.y = sin(_phase * 2.0) * 0.02 * _walk01
	_torso.scale = Vector3(1, 1.0 + sin(_breath * 1.3) * 0.006, 1)
	_head.position.y = HEAD_Y + sin(_phase * 2.0 + 0.6) * 0.012 * _walk01
	_head.rotation.y = sin(_breath * 0.6) * 0.05 * (1.0 - _walk01) + sin(_phase * 0.5) * 0.04 * _walk01
	_rig.position.y = -0.18 * _crouch01
	_rig.rotation.z = -swing * 0.02 * _walk01


func _shoulder_base(i: int, s: float) -> void:
	_shoulders[i].rotation.x = 0.14 + s * 0.45 * _walk01 + 0.25 * _crouch01
	_shoulders[i].rotation.z = 0.08 if i == 0 else -0.08
	_elbows[i].rotation.x = 0.38 + maxf(s, 0.0) * 0.5 * _walk01 - 0.15 * _crouch01