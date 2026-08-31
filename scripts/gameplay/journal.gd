class_name Journal
extends Node
## Investigation journal (Vision 6): collects captured evidence across a match
## and turns it into deductions. TAB slides the panel in; TAB again flips to
## the deduction view where a button votes the entity type in — host decides,
## synced to every peer so the roster shares one journal. Evidence kinds
## beyond the seeded five and more entity powers arrive with the next layers.

signal capture_added(kind: String, room: String)
signal vote_changed(entity_type: String)

const KINDS: Array[String] = [
	"cold spot", "electrical hum", "object poltergeist", "door rattle", "static breath",
]

## Entity identification table (Vision 6). Wraith is the implemented entity;
## Poltergeist/Mimic arrive with their power sets (Mimic fakes evidence).
const ENTITY_TABLE := {
	"wraith": ["cold spot", "electrical hum"],
	"poltergeist": ["object poltergeist", "door rattle"],
	"mimic": ["static breath", "cold spot"],
}

const ENTITY_HINTS := {
	"wraith": "chilled air, electronics whine near its haunt",
	"poltergeist": "thrown objects, rattling doors",
	"mimic": "a liar — mimics warmer evidence; only breath static is truly its own",
}

var captures: Array = []   # [{kind: String, room: String}] — shared roster-wide
var vote: String = ""      # current entity vote, "" = none yet

var _panel_root: Control
var _sheet: PanelContainer
var _list_label: RichTextLabel
var _deduce_label: Label
var _vote_buttons: Array[Button] = []
var _show_deduce := false
var _open01 := 0.0         # slide animation 0 = hidden, 1 = fully in


func _ready() -> void:
	name = "Journal"
	_build_panel()


func _build_panel() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.theme = UITheme.get_theme()
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.visible = false
	add_child(_panel_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(dim)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(UITheme.BG)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = UITheme.ACCENT
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0

	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", sb)
	_sheet.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_sheet.offset_top = 50.0
	_sheet.offset_bottom = -50.0
	_sheet.offset_right = -24.0
	_sheet.offset_left = -620.0   # updated per-frame by the slide anim
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_sheet)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_sheet.add_child(rows)

	var title := Label.new()
	title.text = "INVESTIGATION JOURNAL"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	rows.add_child(title)
	rows.add_child(HSeparator.new())

	_list_label = RichTextLabel.new()
	_list_label.bbcode_enabled = true
	_list_label.fit_content = true
	_list_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_label.add_theme_font_size_override("normal_font_size", 16)
	_list_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(_list_label)

	var hint := Label.new()
	hint.text = "J — EMF reader · near a reading, F — log evidence"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.52))
	rows.add_child(hint)
	rows.add_child(HSeparator.new())

	_deduce_label = Label.new()
	_deduce_label.text = "DEDUCTION"
	_deduce_label.add_theme_font_size_override("font_size", 17)
	_deduce_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.7))
	rows.add_child(_deduce_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	rows.add_child(btn_row)
	for et in ["wraith", "poltergeist", "mimic"]:
		var b := Button.new()
		b.text = et.capitalize()
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_vote_pressed.bind(et))
		btn_row.add_child(b)
		_vote_buttons.append(b)

	_refresh()


## ---- state ---------------------------------------------------------------

func is_open() -> bool:
	return _panel_root.visible


func close() -> void:
	_panel_root.visible = false
	_open01 = 0.0


## Capture from the local player (Match calls this on F). Solo/host logs
## directly; clients ask the host, who broadcasts the merged journal back.
func player_captured(kind: String, room: String) -> void:
	if multiplayer.get_unique_id() == 1:
		host_add_capture(kind, room)
	else:
		request_capture.rpc_id(1, kind, room)


## Host-side capture (solo path too). Dedupes kind+room; broadcasts to peers.
func host_add_capture(kind: String, room: String) -> void:
	for c in captures:
		if c["kind"] == kind and c["room"] == room:
			return
	captures.append({"kind": kind, "room": room})
	capture_added.emit(kind, room)
	_sync_to_peers()
	_refresh()


func set_vote(entity_type: String) -> void:
	if vote == entity_type:
		return
	vote = entity_type
	vote_changed.emit(vote)
	_sync_to_peers()
	_refresh()


## Evidence → entity candidates from what we actually captured.
func possible_entities() -> Array[String]:
	var counts := {}
	for c in captures:
		counts[c["kind"]] = counts.get(c["kind"], 0) + 1
	var out: Array[String] = []
	for et in ENTITY_TABLE:
		var matched: int = 0
		for k in counts:
			if k in ENTITY_TABLE[et]:
				matched += counts[k]
		if matched > 0:
			out.append(et)
	return out


func _on_vote_pressed(entity_type: String) -> void:
	if multiplayer.get_unique_id() == 1:
		set_vote(entity_type)
	else:
		request_vote.rpc_id(1, entity_type)


## ---- network sync (host authoritative) ------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_capture(kind: String, room: String) -> void:
	if multiplayer.get_unique_id() == 1:
		host_add_capture(kind, room)


@rpc("any_peer", "call_remote", "reliable")
func request_vote(entity_type: String) -> void:
	if multiplayer.get_unique_id() == 1:
		set_vote(entity_type)


func _sync_to_peers() -> void:
	# Autoloads are not visible at global-class compile time, so resolve the
	# Net singleton at runtime instead of referencing its identifier.
	var net := get_node_or_null("/root/Net")
	if net != null and net.is_online():
		sync_journal.rpc(captures, vote)


@rpc("authority", "call_remote", "reliable")
func sync_journal(items: Array, current_vote: String) -> void:
	captures = items
	if vote != current_vote:
		vote = current_vote
		vote_changed.emit(vote)
	_refresh()


## ---- UI -------------------------------------------------------------------

func toggle(show_deduce := false, force := false) -> void:
	if force or not _panel_root.visible:
		_show_deduce = show_deduce
		_panel_root.visible = true
		_sheet.modulate.a = 0.0
	else:
		_show_deduce = show_deduce


func _process(delta: float) -> void:
	if not _panel_root.visible:
		return
	# Slide the sheet in from the right, fade it up.
	_open01 = minf(_open01 + delta * 5.0, 1.0)
	var s := ease(_open01, -2.2)
	_sheet.offset_left = lerpf(40.0, -644.0, s)
	_sheet.modulate.a = s
	if _show_deduce and s >= 1.0:
		_deduce_label.text = "DEDUCTION — vote the entity in"
		_refresh()


func _refresh() -> void:
	if _list_label == null:
		return
	if captures.is_empty():
		_list_label.text = "[i]No evidence yet.[/i]\nSwitch the EMF reader on (J), walk the house\nuntil bars rise, then log the reading (F)."
	else:
		var counts := {}
		var rooms_by_kind := {}
		for c in captures:
			var k: String = c["kind"]
			counts[k] = counts.get(k, 0) + 1
			if not rooms_by_kind.has(k) or not rooms_by_kind[k].has(c["room"]):
				if not rooms_by_kind.has(k):
					rooms_by_kind[k] = []
				rooms_by_kind[k].append(c["room"])
		var lines: Array[String] = []
		for k in counts:
			var rooms: String = ", ".join(rooms_by_kind[k])
			lines.append("[color=#c9b458]● %s[/color]  —  %s" % [k, rooms])
		_list_label.text = "\n".join(lines)

	var cands := possible_entities()
	if cands.is_empty():
		_deduce_label.text = "DEDUCTION — no matches yet"
	elif cands.size() == 1:
		_deduce_label.text = "DEDUCTION — %s: %s" % [cands[0], ENTITY_HINTS.get(cands[0], "")]
	else:
		_deduce_label.text = "DEDUCTION — could be: %s" % ", ".join(cands)

	for i in _vote_buttons.size():
		var et: String = _vote_buttons[i].text.to_lower()
		if et == vote:
			_vote_buttons[i].text = "%s  ✓" % et.capitalize()
			_vote_buttons[i].modulate = UITheme.ACCENT
			_vote_buttons[i].add_theme_color_override("font_color", UITheme.ACCENT)
		else:
			_vote_buttons[i].text = et.capitalize()
			_vote_buttons[i].modulate = Color(1, 1, 1)
			_vote_buttons[i].remove_theme_color_override("font_color")