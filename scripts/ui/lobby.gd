extends Control
## Lobby (Vision 5.9): name entry, team-color pick, host/join with a real IP
## field, live roster status line. Flow: menu -> lobby -> match. When the
## roster grows past one player the lobby auto-launches the match after a
## 2 s beat so both peers land in the house together.

@onready var name_edit: LineEdit = $Center/Table/Rows/NameRow/NameEdit
@onready var color_button: Button = $Center/Table/Rows/ColorRow/ColorSwatchButton
@onready var ip_edit: LineEdit = $Center/Table/Rows/IpRow/IpEdit
@onready var host_button: Button = $Center/Table/Rows/ButtonRow/HostButton
@onready var join_button: Button = $Center/Table/Rows/ButtonRow/JoinButton
@onready var back_button: Button = $Center/Table/Rows/BackButton
@onready var status_line: Label = $Center/Table/Rows/StatusLine

## Team tints (drawn in code, 5.10 family); cycled by the swatch button.
const TEAM_COLORS: Array[String] = [
	"#c8a284", "#8fa3c2", "#9dbd8a", "#c2918a",
]

var _color_index := 0
var _launch_timer: SceneTreeTimer
var _launch_pending := false


func _ready() -> void:
	theme = UITheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UITheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	add_child(UITheme.ambient_fog_layer())

	_color_index = maxi(TEAM_COLORS.find(Net.player_color), 0)
	name_edit.text = Net.player_name
	host_button.pressed.connect(_on_host)
	join_button.pressed.connect(_on_join)
	back_button.pressed.connect(_on_back)
	color_button.pressed.connect(_cycle_color)
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.text_submitted.connect(func(_t: String) -> void: _on_host())
	_apply_swatch()
	_update_status()
	Net.player_registered.connect(_on_roster_changed)
	Net.player_left.connect(_on_roster_changed)
	name_edit.grab_focus()


func _process(_delta: float) -> void:
	# Pulsing accent while waiting so the status line reads "live"; steady
	# once online. Auto-launch shortly after the second investigator joins.
	if Net.is_online():
		status_line.modulate.a = 1.0
		if Net.players.size() > 1 and not _launch_pending:
			_launch_pending = true
			_launch_timer = get_tree().create_timer(2.0)
			_launch_timer.timeout.connect(_launch_match)
	else:
		_launch_pending = false
		status_line.modulate.a = 0.65 + 0.35 * absf(sin(Time.get_ticks_msec() / 1000.0 * 2.2))


func _launch_match() -> void:
	if Net.is_online() and Net.players.size() > 1:
		SceneRouter.goto("res://scenes/match.tscn")
	else:
		_launch_pending = false


func _cycle_color() -> void:
	_color_index = (_color_index + 1) % TEAM_COLORS.size()
	_apply_swatch()
	_save_identity()


func _apply_swatch() -> void:
	var c := Color(TEAM_COLORS[_color_index])
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 1, 1, 0.15)
	color_button.add_theme_stylebox_override("normal", sb)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.border_color = UITheme.ACCENT
	color_button.add_theme_stylebox_override("hover", hover)
	color_button.add_theme_stylebox_override("focus", hover)
	var pressed: StyleBoxFlat = sb.duplicate()
	pressed.bg_color = c.darkened(0.25)
	color_button.add_theme_stylebox_override("pressed", pressed)


func _on_name_changed(new_text: String) -> void:
	var ok := not new_text.strip_edges().is_empty()
	host_button.disabled = not ok
	join_button.disabled = not ok
	_save_identity()


func _save_identity() -> void:
	Net.set_local_player(name_edit.text.strip_edges(), TEAM_COLORS[_color_index])
	_update_status()


func _update_status() -> void:
	var n := 0
	for id in Net.players:
		n += 1
	if Net.is_online():
		status_line.text = "connected · %d investigator(s) present" % max(n, 1)
	elif Net.multiplayer_peer != null and not Net.is_online():
		status_line.text = "connecting to %s ..." % ip_edit.text.strip_edges()
	else:
		status_line.text = "waiting · pick a name, host or join"


func _on_roster_changed(_id: int, _info: Dictionary = {}) -> void:
	_update_status()


func _on_host() -> void:
	if host_button.disabled:
		return
	_save_identity()
	Net.host_game(Net.player_name, Net.player_color)
	_update_status()


func _on_join() -> void:
	if join_button.disabled:
		return
	_save_identity()
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	if not Net.join_game(ip, Net.player_name, Net.player_color):
		status_line.text = "join failed · bad address?"
		return
	_update_status()


func _on_back() -> void:
	Net.leave()
	SceneRouter.goto("res://scenes/main_menu.tscn")