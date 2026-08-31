class_name MatchHUD
extends CanvasLayer
## HUD per Vision 5.9 base: interaction prompt near the crosshair.
## Fear meter, objectives and extraction status are layered later.

var prompt_label: Label

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