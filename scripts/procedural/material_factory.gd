class_name MaterialFactory
extends RefCounted
## Central procedural material generator (Vision 5.2 / 5.11).
## Nothing visible keeps a default material: every surface asks this factory.
## All materials are cached and shared, so repeat surfaces hit the same GPU
## resource instead of duplicating textures.

const WALL_C := Color("8b8378")
const DARK_WOOD := Color("4a3b2d")
const FLOOR_WOOD := Color("6b5237")
const CONCRETE := Color("8f9296")
const CEILING_C := Color("7d7a74")
const METAL := Color("6d7378")
const LAMP_LIGHT := Color("ffd9a0")
const DANGER := Color("6e1010")
const FOG := Color("0b0e14")

static var _cache: Dictionary = {}


static func _cached(key: Variant, maker: Callable) -> Material:
	if _cache.has(key):
		return _cache[key]
	var m: Material = maker.call()
	_cache[key] = m
	return m


## Painted wall with grime noise (Vision 5.11 pattern).
static func grime(base: Color, rough := 0.9, freq := 0.05) -> StandardMaterial3D:
	var key := "grime:%s/%.2f/%.3f" % [base.to_html(), rough, freq]
	if _cache.has(key):
		return _cache[key]
	var noise := FastNoiseLite.new()
	noise.frequency = freq
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 256
	tex.height = 256
	var m := StandardMaterial3D.new()
	m.albedo_color = base   # albedo_color multiplies albedo_texture
	m.albedo_texture = tex
	m.roughness = rough
	_cache[key] = m
	return m


## Vertical wood planks (Vision 5.11 pattern). Tiling: enable repeat + uv scale.
static func planks(base := Color("6b5237")) -> StandardMaterial3D:
	var key := "planks:%s" % base.to_html()
	if _cache.has(key):
		return _cache[key]
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.5, 1.0])
	grad.colors = PackedColorArray([base, base.darkened(0.2), base.darkened(0.4), base])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 512
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.repeat = GradientTexture2D.REPEAT
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.albedo_texture = tex
	m.roughness = 0.85
	_cache[key] = m
	return m


## Painted wallpaper: vertical tone bands over grime for a lived-in wall.
static func wallpaper(base := WALL_C) -> StandardMaterial3D:
	var key := "wallpaper:%s" % base.to_html()
	if _cache.has(key):
		return _cache[key]
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.4, 0.75, 0.8, 1.0])
	grad.colors = PackedColorArray([
		base, base.darkened(0.06), base, base.lightened(0.04), base, base.darkened(0.05),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 512
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 0)
	tex.repeat = GradientTexture2D.REPEAT
	var noise := FastNoiseLite.new()
	noise.frequency = 0.04
	var grain := NoiseTexture2D.new()
	grain.noise = noise
	grain.width = 256
	grain.height = 256
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.albedo_texture = tex
	m.roughness = 0.88
	_cache[key] = m
	return m


static func wall() -> Material:
	return wallpaper(WALL_C)


static func wall_stained() -> Material:
	var key := "wall_stained"
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 5
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width = 512
	tex.height = 512
	m.albedo_color = WALL_C.darkened(0.25)
	m.albedo_texture = tex
	m.roughness = 0.95
	_cache[key] = m
	return m


static func floor_wood() -> StandardMaterial3D:
	var key := "floor_wood"
	if _cache.has(key):
		return _cache[key]
	var m := planks(FLOOR_WOOD)
	m.uv1_scale = Vector3(3, 4, 1)  # repeat planks across the floor slab
	m.roughness = 0.8
	_cache[key] = m
	return m


static func concrete_floor() -> Material:
	var m := grime(CONCRETE, 0.95, 0.015)
	_cast(m)
	return m


static func concrete_wall() -> Material:
	return grime(CONCRETE.darkened(0.15), 0.92, 0.03)


static func ceiling() -> Material:
	return grime(CEILING_C.darkened(0.1), 0.95, 0.02)


static func wood_dark() -> Material:
	return grime(DARK_WOOD, 0.75, 0.09)


static func metal() -> Material:
	return grime(METAL, 0.5, 0.11)


static func metal_dark() -> Material:
	return grime(METAL.darkened(0.3), 0.45, 0.08)


## Emissive warm bulb / small light fixtures.
static func bulb() -> StandardMaterial3D:
	var key := "bulb"
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = LAMP_LIGHT
	m.emission_enabled = true
	m.emission = LAMP_LIGHT
	m.emission_energy_multiplier = 2.2
	_cache[key] = m
	return m


## Night window glass: translucent pale blue, faint self-glow.
static func glass() -> StandardMaterial3D:
	var key := "glass"
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.72, 0.8, 0.92, 0.18)
	m.emission_enabled = true
	m.emission = Color(0.3, 0.38, 0.5)
	m.emission_energy_multiplier = 0.7
	m.roughness = 0.1
	m.metallic = 0.2
	_cache[key] = m
	return m


## Baseboard / trim.
static func trim() -> Material:
	return grime(DARK_WOOD.darkened(0.2), 0.7, 0.12)


## Code-made abstract picture for frames (ImageTexture from a pixel loop).
static func picture_texture(seed_value: int) -> ImageTexture:
	var img := Image.create(128, 96, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	img.fill(Color(0.16, 0.13, 0.1))
	# Muted background blocks
	for i in range(5):
		var c := Color(rng.randf_range(0.25, 0.55), rng.randf_range(0.2, 0.4), rng.randf_range(0.15, 0.4))
		var x0 := rng.randi_range(4, 80)
		var y0 := rng.randi_range(4, 50)
		var w := rng.randi_range(24, 46)
		var h := rng.randi_range(18, 38)
		for y in range(y0, mini(y0 + h, 96)):
			for x in range(x0, mini(x0 + w, 128)):
				if (x + y) % 7 != 0:  # slight dither so it is not a flat block
					img.set_pixel(x, y, c)
	# Dark vignette edges for age
	for y in range(96):
		for x in range(128):
			var edge := float(mini(mini(x, 127 - x), mini(y, 95 - y)))
			if edge < 6.0:
				var px := img.get_pixel(x, y).darkened(0.35)
				img.set_pixel(x, y, px)
	return ImageTexture.create_from_image(img)


## Face texture per Vision 5.11 (verbatim pattern).
static func face_texture(skin := Color("c8a284")) -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.fill(skin)
	var eye := Color(0.04, 0.04, 0.06)
	for y in range(50, 62):
		for x in range(38, 52): img.set_pixel(x, y, eye)   # left eye
		for x in range(76, 90): img.set_pixel(x, y, eye)  # right eye
	for x in range(46, 82): img.set_pixel(x, 88, Color(0.32, 0.12, 0.12))  # mouth
	return ImageTexture.create_from_image(img)


static func _cast(m: StandardMaterial3D) -> StandardMaterial3D:
	return m