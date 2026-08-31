class_name MatchHUD
extends CanvasLayer
## HUD per Vision 5.9 base: interaction prompt near the crosshair.
## Fear meter, objectives and extraction status are layered later.

var prompt_label: Label
var stamina_bar: ProgressBar
var battery_bar: ProgressBar

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