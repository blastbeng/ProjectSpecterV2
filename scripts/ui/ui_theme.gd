class_name UITheme
extends RefCounted
## One code-generated Theme for ALL screens (Vision 5.9): dark bg, styled
## buttons with hover/press/focus states. No font files (no-asset rule) —
## default font with size/color overrides.

const BG := Color("0d0f14")
const ACCENT := Color("c9b458")
const ACCENT_DIM := Color("8f8340")
const TEXT := Color("d6d9e0")
const TEXT_DIM := Color("84899a")

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()

	# Panel: dark translucent slate used by every overlay container.
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(BG.r, BG.g, BG.b, 0.86)
	panel_bg.set_corner_radius_all(8)
	panel_bg.set_expand_margin_all(6.0)
	panel_bg.content_margin_left = 18.0
	panel_bg.content_margin_right = 18.0
	panel_bg.content_margin_top = 12.0
	panel_bg.content_margin_bottom = 14.0
	panel_bg.set_border_width_all(1)
	panel_bg.border_color = Color(1, 1, 1, 0.06)
	t.set_stylebox("panel", "PanelContainer", panel_bg)

	# Buttons: recessed dark slab, accent border on hover/focus, pressed inset.
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.098, 0.11, 0.145)
	normal.set_corner_radius_all(5)
	normal.set_border_width_all(1)
	normal.border_color = Color(1, 1, 1, 0.08)
	normal.content_margin_left = 22.0
	normal.content_margin_right = 22.0
	normal.content_margin_top = 10.0
	normal.content_margin_bottom = 10.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.13, 0.15, 0.2)
	hover.border_color = ACCENT_DIM
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.06, 0.07, 0.1)
	pressed.border_color = ACCENT
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.06, 0.065, 0.09)
	disabled.border_color = Color(1, 1, 1, 0.04)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", hover)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_font_size("Button", "Button", 17)
	t.set_font_size("Label", "Label", 15)
	t.set_font_size("LineEdit", "LineEdit", 15)

	# Labels: readable default colors + soft shadow.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 1)

	# LineEdit (lobby name entry / settings fields later).
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.06, 0.07, 0.1)
	le.set_corner_radius_all(4)
	le.set_border_width_all(1)
	le.border_color = Color(1, 1, 1, 0.07)
	le.content_margin_left = 10.0
	le.content_margin_right = 10.0
	le.content_margin_top = 7.0
	le.content_margin_bottom = 7.0
	var le_focus: StyleBoxFlat = le.duplicate()
	le_focus.border_color = ACCENT
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_DIM)
	_theme = t
	return _theme


## Full-screen animated fog backdrop behind menus: three additive scrolling
## noise layers. Ignores mouse so buttons stay clickable.
static func ambient_fog_layer() -> FogLayer:
	var fog := FogLayer.new()
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return fog


class FogLayer:
	extends Control
	## Three additive scrolling NoiseTexture2D layers (Vision 5.9 splash fog).
	var _t := 0.0
	var _layers: Array = []

	func _ready() -> void:
		var tints := [Color(0.16, 0.19, 0.24), Color(0.11, 0.14, 0.17), Color(0.07, 0.09, 0.11)]
		var speeds := [0.018, 0.031, 0.052]
		var drifts := [61.7, 191.3, 337.9]
		for i in range(3):
			var tex := NoiseTexture2D.new()
			var n := FastNoiseLite.new()
			n.seed = 700 + i * 13
			n.frequency = 0.0045
			n.fractal_octaves = 4
			tex.noise = n
			tex.width = 256
			tex.height = 256
			tex.seamless = true
			# Dark noise -> alpha via modulate; light spots become faint fog.
			var s := TextureRect.new()
			s.texture = tex
			s.stretch_mode = TextureRect.STRETCH_TILE
			s.size = Vector2(1920.0, 1440.0)
			s.modulate = Color(tints[i].r, tints[i].g, tints[i].b, 0.55)
			var mm := CanvasItemMaterial.new()
			mm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			s.material = mm
			add_child(s)
			_layers.append({"rect": s, "speed": speeds[i], "drift": drifts[i]})

	func _process(delta: float) -> void:
		_t = fposmod(_t + delta, 3600.0)
		for layer in _layers:
			var s: TextureRect = layer.rect
			var sx: float = layer.speed
			var sy: float = layer.speed * 0.6
			s.position.x = -960.0 + fposmod(layer.drift + _t * 340.0 * sx, 960.0)
			s.position.y = -544.0 + fposmod(_t * 120.0 * sy, 544.0)