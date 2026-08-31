extends Control
## Main menu (Vision 5.9 pass): themed buttons over an animated night backdrop
## (fog layers, moon, manor silhouette, bare tree), version footer.

@onready var host_button: Button = $VBox/PlayButton
@onready var join_button: Button = $VBox/JoinButton
@onready var quit_button: Button = $VBox/QuitButton


func _ready() -> void:
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)  # bg must sit below the tscn UI children or it hides them
	add_child(UITheme.ambient_fog_layer())
	_build_backdrop()
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	quit_button.pressed.connect(_on_quit)
	host_button.grab_focus()
	# Footer: build tag so every menu screenshot is traceable to a build.
	var ver := Label.new()
	ver.text = "specter v0.3 · playtester build"
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.45, 0.47, 0.55, 0.7))
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -300
	ver.offset_right = -12
	ver.offset_top = -30
	ver.offset_bottom = -10
	add_child(ver)


## Code-drawn night backdrop: moon + halo, manor silhouette on the horizon,
## bare tree at the left edge, bottom vignette. All positions are fractions
## of the actual control size, so any window resolution works.
func _build_backdrop() -> void:
	var layer := Control.new()
	layer.name = "BackdropLayer"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	move_child(layer, 1)
	# Wait one frame so anchors resolve and size is real.
	await get_tree().process_frame
	var w := layer.size.x
	var h := layer.size.y

	# Moon + halo (upper right).
	_rect(layer, Vector2(0.66, 0.115), Vector2(0.24, 0.24) * Vector2(w, h) * 0.0 + Vector2(w * 0.16, h * 0.30), Color(0.75, 0.8, 0.9, 0.05))
	_rect(layer, Vector2(0.72, 0.18), Vector2(w * 0.075, h * 0.13), Color(0.88, 0.91, 0.95, 0.9))

	# Manor silhouette across the horizon (fractions of the reference 1280x720).
	var body := PackedVector2Array([
		Vector2(0.234, 0.983), Vector2(0.234, 0.778), Vector2(0.266, 0.757),
		Vector2(0.266, 0.722), Vector2(0.328, 0.722), Vector2(0.328, 0.667),
		Vector2(0.367, 0.597), Vector2(0.406, 0.667), Vector2(0.406, 0.722),
		Vector2(0.469, 0.722), Vector2(0.469, 0.757), Vector2(0.500, 0.778),
		Vector2(0.500, 0.983),
	])
	_poly(layer, body, Vector2(w, h), Color(0.03, 0.035, 0.055))
	var wing := PackedVector2Array([
		Vector2(0.500, 0.983), Vector2(0.500, 0.833), Vector2(0.594, 0.806),
		Vector2(0.688, 0.833), Vector2(0.688, 0.983),
	])
	_poly(layer, wing, Vector2(w, h), Color(0.025, 0.03, 0.045))
	var chim := PackedVector2Array([
		Vector2(0.336, 0.642), Vector2(0.336, 0.583), Vector2(0.353, 0.583),
		Vector2(0.353, 0.642),
	])
	_poly(layer, chim, Vector2(w, h), Color(0.03, 0.035, 0.05))

	# One warm lit window in the wing — flickers slowly in _process.
	var win := ColorRect.new()
	win.name = "FlickerWindow"
	win.anchor_left = 0.605
	win.anchor_top = 0.875
	win.anchor_right = 0.625
	win.anchor_bottom = 0.93
	win.color = Color(1.0, 0.85, 0.45, 0.75)
	layer.add_child(win)

	# Bare tree at the left edge (branch triangles), anchored to the ground.
	var base := Vector2(w * 0.12, h * 0.995)
	var s := minf(w / 1280.0, h / 720.0)
	var branches := [
		[Vector2(-40, 0), Vector2(-8, -230), Vector2(10, -236), Vector2(46, 0)],
		[Vector2(-6, -150), Vector2(70, -220), Vector2(84, -214), Vector2(8, -128)],
		[Vector2(4, -170), Vector2(56, -262), Vector2(66, -256), Vector2(10, -150)],
		[Vector2(0, -210), Vector2(-44, -300), Vector2(-30, -308), Vector2(12, -196)],
		[Vector2(6, -230), Vector2(48, -306), Vector2(58, -298), Vector2(10, -214)],
	]
	for pts in branches:
		var p := Polygon2D.new()
		var vs := PackedVector2Array()
		for pt in pts:
			vs.append(pt * s)
		p.polygon = vs
		p.position = base
		p.color = Color(0.015, 0.02, 0.03)
		layer.add_child(p)

	# Bottom vignette to seat the UI column.
	var shade := _rect(layer, Vector2(0.0, 0.72), Vector2(0, 0), Color(0.02, 0.025, 0.04, 0.5))
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)


func _rect(parent: Control, anchor: Vector2, size_px: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = Vector2(anchor.x * parent.size.x, anchor.y * parent.size.y)
	r.size = size_px
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _poly(parent: Control, pts: PackedVector2Array, span: Vector2, color: Color) -> void:
	var p := Polygon2D.new()
	var vs := PackedVector2Array()
	for pt in pts:
		vs.append(Vector2(pt.x * span.x, pt.y * span.y))
	p.polygon = vs
	p.color = color
	parent.add_child(p)


func _process(_delta: float) -> void:
	var win := get_node_or_null("BackdropLayer/FlickerWindow") as ColorRect
	if win != null:
		var t := Time.get_ticks_msec() / 1000.0
		win.modulate.a = 0.55 + 0.45 * absf(sin(t * 2.7) * sin(t * 0.9 + 1.3))


func _on_host() -> void:
	# Both now land in the lobby (Vision 5.9 flow); the lobby holds the
	# real name/color/IP flow (auto-test path stays: Net host first).
	SceneRouter.goto("res://scenes/lobby.tscn")


func _on_join() -> void:
	SceneRouter.goto("res://scenes/lobby.tscn")


func _on_quit() -> void:
	get_tree().quit()