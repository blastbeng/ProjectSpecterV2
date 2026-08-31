class_name NightEnvironment
extends Node3D
## Global night atmosphere per Vision 5.1: dark sky, low ambient, ACES tonemap,
## subtle glow, fog, faint moonlight. Added once by the match scene.

func _ready() -> void:
	_build_environment()
	_build_moonlight()

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.01, 0.014, 0.028)
	sky_mat.sky_horizon_color = Color("10141c")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_bottom_color = Color(0.005, 0.006, 0.01)
	sky_mat.ground_horizon_color = Color("0b0e14")
	sky_mat.sun_angle_max = 8.0

	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("10141c")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color("0b0e14")
	env.fog_density = 0.022
	env.fog_sky_affect = 0.15

	# Desktop-only extras per Vision 5.1 (never on Android quality).
	if not OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.03
		env.volumetric_fog_albedo = Color("0b0e14")

	var we := WorldEnvironment.new()
	we.name = "NightWorldEnvironment"
	we.environment = env
	add_child(we)

func _build_moonlight() -> void:
	var moon := DirectionalLight3D.new()
	moon.name = "Moonlight"
	moon.light_color = Color(0.55, 0.65, 0.85)
	moon.light_energy = 0.12
	moon.light_indirect_energy = 0.4
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-38.0, 32.0, 0.0)
	add_child(moon)