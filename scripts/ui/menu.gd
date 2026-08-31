extends Control
## Main menu (Vision 5.9 pass): themed buttons over an animated manor facade
## backdrop (fog, moon, silhouette), version footer for quick screenshot checks.

@onready var host_button: Button = $VBox/PlayButton
@onready var join_button: Button = $VBox/JoinButton
@onready var quit_button: Button = $VBox/QuitButton

func _ready() -> void:
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	add_child(UITheme.ambient_fog_layer())
	_build_backdrop()
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	quit_button.pressed.connect(_on_quit)
	host_button.grab_focus()
	# Footer: build tag so every menu screenshot is traceable to a commit.
	var ver := Label.new()
	ver.text = "specter v0.3 · remote playtester build"
	ver.add_theme_font_size_override("font_size", 12)
	ver.add_theme_color_override("font_color", Color(0.45, 0.47, 0.55, 0.7))
	ver.anchor_left = 1.0
	ver.anchor_right = 1.0
	ver.anchor_top = 1.0
	ver.anchor_bottom = 1.0
	ver.offset_left = -320
	ver.offset_right = -12
	ver.offset_top = -30
	ver.offset_bottom = -10
	add_child(ver)


## Code-drawn night backdrop: moon, manor silhouette, bare tree, vignette.
## Pure ColorRects+Polygons in a Control layer, so it costs nothing to theme.
func _build_backdrop() -> void:
	var layer := Control.new()
	layer.name = "BackdropLayer"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	move_child(layer, 1)

	# Moon: pale disc + halo.
	moon_at(layer, Vector2(0.78, 0.30), 46.0)
	# Manor silhouette along the horizon (dark wall + gabled roofline).
	manor(layer)
	# A bare tree with branch polygons at the left edge.
	tree_at(layer, Vector2(0.12, 0.99), 1.0)
	# Bottom vignette to seat the UI column.
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.04, 0.55)
	shade.anchor_left = 0.0
	shade.anchor_top = 0.72
	shade.anchor_right = 1.0
	shade.anchor_bottom = 1.0
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)

	# One flickering warm window in the manor + a tiny OmniLight-like modulation.
	var win := ColorRect.new()
	win.name = "FlickerWindow"
	win.size = Vector2(26, 34)
	win.position = Vector2(1044.0, 608.0)
	win.color = Color(1.0, 0.85, 0.45, 0.75)
	layer.add_child(win)


func moon_at(parent: Control, af: Vector2, radius: float) -> void:
	var halo := ColorRect.new()
	halo.size = Vector2(radius * 3.4, radius * 3.4)
	halo.color = Color(0.75, 0.8, 0.9, 0.05)
	halo.position = Vector2(af.x * 1280.0 - radius * 1.7, af.y * 720.0 - radius * 1.7)
	parent.add_child(halo)
	var disc := ColorRect.new()
	disc.size = Vector2(radius * 2, radius * 2)
	disc.color = Color(0.88, 0.91, 0.95, 0.9)
	disc.position = Vector2(af.x * 1280.0 - radius, af.y * 720.0 - radius)
	parent.add_child(disc)


func tree_at(parent: Control, base: Vector2, _scale: float) -> void:
	var polys := [
		[Vector2(-40, 0), Vector2(-8, -230), Vector2(10, -236), Vector2(46, 0)],
		[Vector2(-6, -150), Vector2(70, -220), Vector2(84, -214), Vector2(8, -128)],
		[Vector2(4, -170), Vector2(56, -262), Vector2(66, -256), Vector2(10, -150)],
		[Vector2(0, -210), Vector2(-44, -300), Vector2(-30, -308), Vector2(12, -196)],
		[Vector2(6, -230), Vector2(48, -306), Vector2(58, -298), Vector2(10, -214)],
	]
	for pts in polys:
		var p := Polygon2D.new()
		var vs := PackedVector2Array()
		for pt in pts:
			vs.append(pt * _scale)
		p.polygon = vs
		p.position = Vector2(base.x * 1280.0, base.y * 720.0)
		p.color = Color(0.015, 0.02, 0.03)
		parent.add_child(p)


func manor(parent: Control) -> void:
	# Body + roof as dark polygons across the horizon (y ~ 640-708).
	var body := Polygon2D.new()
	body.polygon = PackedVector2Array([
		Vector2(300, 708), Vector2(300, 560), Vector2(340, 545), Vector2(340, 520),
		Vector2(420, 520), Vector2(420, 480), Vector2(470, 430), Vector2(520, 480),
		Vector2(520, 520), Vector2(600, 520), Vector2(600, 545), Vector2(640, 560),
		Vector2(640, 708),
	])
	body.color = Color(0.03, 0.035, 0.055)
	parent.add_child(body)
	var wing := Polygon2D.new()
	wing.polygon = PackedVector2Array([
		Vector2(640, 708), Vector2(640, 600), Vector2(760, 580), Vector2(880, 600),
		Vector2(880, 708),
	])
	wing.color = Color(0.025, 0.03, 0.045)
	parent.add_child(wing)
	# Ridge chimney.
	var chim := Polygon2D.new()
	chim.polygon = PackedVector2Array([
		Vector2(430, 462), Vector2(430, 420), Vector2(452, 420), Vector2(452, 462),
	])
	chim.color = Color(0.03, 0.035, 0.05)
	parent.add_child(chim)


func _on_host() -> void:
	SceneRouter.goto("res://scenes/match.tscn")


func _on_join() -> void:
	# Networking arrives in a later iteration; join currently starts local play.
	SceneRouter.goto("res://scenes/match.tscn")


func _on_quit() -> void:
	get_tree().quit()