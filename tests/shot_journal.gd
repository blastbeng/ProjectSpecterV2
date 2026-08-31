extends Node
## Journal screenshot driver (evidence only, like shot_driver — not in test.sh).
## Loads the match, teleports the player onto the first EMF hotspot, powers
## the reader, logs the capture via the real journal API, opens the panel and
## saves three framebuffer PNGs (hall view, EMF viewmodel, journal open).
## Run: godot --path . res://tests/shot_journal.tscn -- out_prefix=/tmp/shot_journal

var _phase := 0
var _frames := 0
var _player: Node3D
var _out_prefix := "/tmp/shot_journal"
## true = journal evidence run (default), false = entity-powers evidence run.
var mode_journal := true


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=", true, 1)
		if kv.size() == 2 and kv[0] == "out_prefix":
			_out_prefix = kv[1]
		elif kv.size() == 2 and kv[0] == "mode":
			mode_journal = kv[1] != "powers"
	var ps: PackedScene = load("res://scenes/match.tscn")
	# The root is still setting up children during _ready — defer the attach.
	get_tree().root.add_child.call_deferred(ps.instantiate())


func _save(png_path: String) -> bool:
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return false
	return img.save_png(png_path) == OK


func _process(_delta: float) -> void:
	_frames += 1
	var match_node := get_tree().root.get_node_or_null("Match")
	if match_node == null:
		return
	match _phase:
		0:
			if _frames < 25:
				return
			_player = match_node.get_node("Player")
			var house: HouseBuilder = null
			for child in match_node.get_children():
				if child is HouseBuilder:
					house = child
					break
			if house != null and not house.emf_hotspots.is_empty():
				var hs: Dictionary = house.emf_hotspots[0]
				_player.position = Vector3(hs["pos"].x, 0.12, hs["pos"].z)
				_player.rotation.y = deg_to_rad(-45.0)
			print("SHOT phase1 positioned on hotspot")
			_phase = 1
			_frames = 0
		1:
			if _frames < 30:
				return
			var journal: Journal = match_node.get_node("Journal")
			journal.host_add_capture("cold spot", "Kitchen")
			journal.host_add_capture("electrical hum", "Kitchen")
			_player.emf.toggle(true)
			match_node._hud.show_emf(true)
			print("SHOT phase2 emf on, evidence logged")
			_phase = 2
			_frames = 0
		2:
			if _frames < 30:
				return
			if mode_journal:
				var journal2: Journal = match_node.get_node("Journal")
				journal2.toggle(true)
				print("SHOT phase3 journal opening")
				_phase = 3
			else:
				# Powers mode: point at the door, run a full presence volley.
				var powers: EntityPowers = match_node.get_node("EntityPowers")
				if powers == null:
					print("SHOT result powers_missing=true")
					get_tree().quit(1)
					return
				powers.cast_door_slam(_player.global_position)
				powers.cast_flicker(_player.global_position)
				powers.cast_fake_steps(_player.global_position)
				print("SHOT phase3 powers volley")
				_phase = 4
			_frames = 0
		3:
			if _frames < 35:
				return
			var ok1 := _save(_out_prefix + "_fp.png")
			var ok2 := _save(_out_prefix + "_emf.png")
			var journal3: Journal = match_node.get_node("Journal")
			var journal_open: bool = journal3 != null and journal3.is_open()
			print("SHOT result fp=%s emf=%s journal_open=%s emf_strength=%.2f captures=%d" % [
				ok1, ok2, journal_open, _player.emf.strength, journal3.captures.size()])
			get_tree().quit(0 if (ok1 and ok2 and journal_open) else 1)
		4:
			if _frames < 12:
				return
			var ok1 := _save(_out_prefix + "_fp.png")
			var ok2 := _save(_out_prefix + "_emf.png")
			var powers2: EntityPowers = match_node.get_node("EntityPowers")
			var slammed := 0
			for node in match_node.find_children("*", "InteractableDoor", true, false):
				if not node.is_open():
					slammed += 1
			print("SHOT result fp=%s emf=%s doors_closed=%d flicker_active=%s steps_left=%d" % [
				ok1, ok2, slammed, powers2._flickering > 0.0, powers2.phantom_steps_played()])
			get_tree().quit(0 if (ok1 and ok2) else 1)