extends Control
## Splash per Vision 5.9: animated fog + drifting dust + title, any key skip,
## auto-advance to the menu after a few seconds.

var _elapsed := 0.0
var _finished := false
var _title: Label
var _prompt: Label
var _tip: Label
var _dust: Array = []


func _ready() -> void:
	theme = UITheme.get_theme()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var dark := ColorRect.new()
	dark.color = UITheme.BG
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dark)
	add_child(UITheme.ambient_fog_layer())
	# Faint drifting dust motes (GPUParticles need a world; rects suffice here).
	for i in range(30):
		var mote := ColorRect.new()
		mote.size = Vector2(2, 2)
		mote.position = Vector2(rng.randf_range(10, 1270), rng.randf_range(20, 700))
		mote.color = Color(0.75, 0.78, 0.85, rng.randf_range(0.05, 0.3))
		add_child(mote)
		_dust.append(mote)

	_title = Label.new()
	_title.text = "PROJECT SPECTER"
	_title.add_theme_font_size_override("font_size", 52)
	_title.add_theme_color_override("font_color", UITheme.ACCENT)
	_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_title.add_theme_constant_override("shadow_offset_x", 2)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	add_child(_title)
	_center_col(_title, 0.26)

	_prompt = Label.new()
	_prompt.text = "an asymmetric horror investigation"
	_prompt.add_theme_font_size_override("font_size", 15)
	_prompt.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	add_child(_prompt)
	_center_col(_prompt, 0.40)

	_tip = Label.new()
	_tip.text = "press any key"
	_tip.add_theme_font_size_override("font_size", 14)
	_tip.add_theme_color_override("font_color", UITheme.TEXT_DIM)
	add_child(_tip)
	_center_col(_tip, 0.80)
	_tip.modulate.a = 0.0


## Horizontally centered column label at a vertical anchor fraction.
func _center_col(c: Label, ay: float) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _process(delta: float) -> void:
	_elapsed += delta
	_title.modulate.a = minf(_elapsed / 1.2, 1.0)
	_prompt.modulate.a = minf(maxf(_elapsed - 0.4, 0.0) / 1.2, 1.0)
	if _elapsed > 1.6:
		_tip.modulate.a = (0.45 + 0.55 * absf(sin(_elapsed * 2.0))) * minf((_elapsed - 1.6) / 0.8, 1.0)
	for mote in _dust:
		mote.position.y += delta * 12.0
		if mote.position.y > 720:
			mote.position.y = -3.0
	if _elapsed > 5.5:
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	SceneRouter.goto("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_finish()
	elif event is InputEventJoypadButton and event.pressed:
		_finish()