class_name MatchHUD
extends CanvasLayer
## HUD per Vision 5.9 base: interaction prompt near the crosshair.
## Fear meter, objectives and extraction status are layered later.

var prompt_label: Label
var stamina_bar: ProgressBar
var battery_bar: ProgressBar
var emf_bar: ProgressBar
var emf_label: Label
var objective_label: Label
var extract_label: Label

func _ready() -> void:
	prompt_label = Label.new()
	prompt_label.text = ""
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_top = 0.62
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_bottom = 0.62
	prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_label.add_theme_color_override("font_color", Color("c9b458"))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(prompt_label)

	var crosshair := ColorRect.new()
	crosshair.color = Color(0.9, 0.88, 0.8, 0.6)
	crosshair.anchor_left = 0.5
	crosshair.anchor_top = 0.5
	crosshair.anchor_right = 0.5
	crosshair.anchor_bottom = 0.5
	crosshair.offset_left = -1.5
	crosshair.offset_right = 1.5
	crosshair.offset_top = -1.5
	crosshair.offset_bottom = 1.5
	add_child(crosshair)

	stamina_bar = ProgressBar.new()
	stamina_bar.min_value = 0
	stamina_bar.max_value = 1.0
	stamina_bar.value = 1.0
	stamina_bar.show_percentage = false
	stamina_bar.anchor_left = 0.5
	stamina_bar.anchor_right = 0.5
	stamina_bar.anchor_top = 0.93
	stamina_bar.anchor_bottom = 0.93
	stamina_bar.offset_left = -90
	stamina_bar.offset_right = 90
	stamina_bar.offset_top = -5
	stamina_bar.offset_bottom = 5
	stamina_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("c9b458")
	sb.set_corner_radius_all(3)
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.05, 0.06, 0.08, 0.8)
	stamina_bar.add_theme_stylebox_override("fill", sb)
	stamina_bar.add_theme_stylebox_override("background", sb_bg)
	add_child(stamina_bar)

	# Battery bar above the stamina bar (flashlight charge).
	battery_bar = ProgressBar.new()
	battery_bar.min_value = 0
	battery_bar.max_value = 1.0
	battery_bar.value = 1.0
	battery_bar.show_percentage = false
	battery_bar.anchor_left = 0.5
	battery_bar.anchor_right = 0.5
	battery_bar.anchor_top = 0.905
	battery_bar.anchor_bottom = 0.905
	battery_bar.offset_left = -60
	battery_bar.offset_right = 60
	battery_bar.offset_top = -4
	battery_bar.offset_bottom = 4
	battery_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color("d8e2ea")
	bb.set_corner_radius_all(3)
	battery_bar.add_theme_stylebox_override("fill", bb)
	battery_bar.add_theme_stylebox_override("background", sb_bg)
	add_child(battery_bar)

	# EMF meter bottom-left (Vision 5.9 HUD): warm accent fill + level tag.
	# Hidden until the reader is switched on with J.
	var emf_fill := StyleBoxFlat.new()
	emf_fill.bg_color = Color("c9b458")
	emf_fill.set_corner_radius_all(3)
	emf_bar = ProgressBar.new()
	emf_bar.min_value = 0.0
	emf_bar.max_value = 1.0
	emf_bar.value = 0.0
	emf_bar.show_percentage = false
	emf_bar.anchor_left = 0.0
	emf_bar.anchor_right = 0.0
	emf_bar.anchor_top = 0.93
	emf_bar.anchor_bottom = 0.93
	emf_bar.offset_left = 24.0
	emf_bar.offset_right = 144.0
	emf_bar.offset_top = -5.0
	emf_bar.offset_bottom = 5.0
	emf_bar.add_theme_stylebox_override("fill", emf_fill)
	emf_bar.add_theme_stylebox_override("background", sb_bg)
	emf_bar.visible = false
	add_child(emf_bar)
	emf_label = Label.new()
	emf_label.text = ""
	emf_label.anchor_left = 0.0
	emf_label.anchor_right = 0.0
	emf_label.anchor_top = 0.93
	emf_label.anchor_bottom = 0.93
	emf_label.offset_left = 152.0
	emf_label.offset_right = 240.0
	emf_label.offset_top = -11.0
	emf_label.offset_bottom = 11.0
	emf_label.add_theme_font_size_override("font_size", 14)
	emf_label.add_theme_color_override("font_color", Color("c9b458"))
	emf_label.visible = false
	add_child(emf_label)

	# Objective tracker, top-center (Vision 5.9).
	objective_label = Label.new()
	objective_label.text = ""
	objective_label.anchor_left = 0.5
	objective_label.anchor_right = 0.5
	objective_label.anchor_top = 0.0
	objective_label.anchor_bottom = 0.0
	objective_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	objective_label.offset_top = 14.0
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.add_theme_font_size_override("font_size", 17)
	objective_label.add_theme_color_override("font_color", Color("c9b458"))
	objective_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	objective_label.add_theme_constant_override("shadow_offset_x", 1)
	objective_label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(objective_label)

	# Extraction countdown, big and alarming, appears under the objective.
	extract_label = Label.new()
	extract_label.text = ""
	extract_label.anchor_left = 0.5
	extract_label.anchor_right = 0.5
	extract_label.anchor_top = 0.0
	extract_label.anchor_bottom = 0.0
	extract_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	extract_label.offset_top = 40.0
	extract_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extract_label.add_theme_font_size_override("font_size", 30)
	extract_label.add_theme_color_override("font_color", Color("d84a3a"))
	extract_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	extract_label.add_theme_constant_override("shadow_offset_x", 2)
	extract_label.add_theme_constant_override("shadow_offset_y", 2)
	extract_label.visible = false
	add_child(extract_label)

	# Bottom-right hint line (Vision 5.9 HUD) — mirrors keybinds to the player.
	var hint := Label.new()
	hint.text = "WASD move · SHIFT sprint · CTRL crouch · E use · TAB journal"
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = -470.0
	hint.offset_right = -16.0
	hint.offset_top = -26.0
	hint.offset_bottom = -8.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.78, 0.76, 0.66, 0.75))
	hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("shadow_offset_x", 1)
	hint.add_theme_constant_override("shadow_offset_y", 1)
	add_child(hint)


func show_emf(on: bool) -> void:
	emf_bar.visible = on
	emf_label.visible = on


func set_emf(strength01: float, level5: int) -> void:
	emf_bar.value = clampf(strength01, 0.0, 1.0)
	emf_label.text = "LV %d" % level5 if strength01 > 0.02 else ""


## Objective tracker line, top-center.
func set_objective(text: String) -> void:
	objective_label.text = "◆ %s" % text if text != "" else ""


## Loud countdown under the objective once extraction is armed.
func show_extract_countdown(seconds: float) -> void:
	extract_label.visible = true
	extract_label.add_theme_color_override("font_color", Color("d84a3a"))
	set_extract_timer(seconds)


func set_extract_timer(seconds: float) -> void:
	extract_label.text = "ESCAPE IN %d" % int(ceilf(seconds))


func show_extract_failed() -> void:
	extract_label.text = "EXTRACTION LOST"
	extract_label.add_theme_color_override("font_color", Color("8a2020"))