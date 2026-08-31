extends SceneTree
## test_journal.gd — evidence journal + deduction test (Vision 6).
## Checks: capture add/dedupe, kind+room attribution from the EMF hotspot,
## deduction candidates from the entity table, vote state, sync RPC shape.

const MATCH_SCENE := "res://scenes/match.tscn"
const PASS_S := "TEST_JOURNAL_RESULT=PASS"
const FAIL_S := "TEST_JOURNAL_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures := 0

	# --- capture add / dedupe / vote -------------------------------------------------
	var j := Journal.new()
	root.add_child(j)
	await process_frame

	# Lambdas capture locals by VALUE, so a plain int counter would stay 0;
	# mutate an array instead.
	var added_log: Array = []
	j.capture_added.connect(func(_k: String, _r: String) -> void: added_log.append(1))
	var votes: Array[String] = []
	j.vote_changed.connect(func(e: String) -> void: votes.append(e))

	j.host_add_capture("cold spot", "Kitchen")
	j.host_add_capture("cold spot", "Kitchen")  # must dedupe
	j.host_add_capture("electrical hum", "Kitchen")
	if j.captures.size() != 2 or added_log.size() != 2:
		print(FAIL_S, " captures=%d added=%d (want 2/2)" % [j.captures.size(), added_log.size()])
		failures += 1

	var cands := j.possible_entities()
	# cold spot matches wraith AND mimic; electrical hum matches wraith only.
	if not ("wraith" in cands and "mimic" in cands):
		print(FAIL_S, " candidates missing wraith/mimic: %s" % [cands])
		failures += 1

	j.host_add_capture("object poltergeist", "Storage")
	cands = j.possible_entities()
	if not ("poltergeist" in cands):
		print(FAIL_S, " poltergeist evidence did not surface: %s" % [cands])
		failures += 1

	j.set_vote("wraith")
	if j.vote != "wraith" or votes.size() != 1 or votes[0] != "wraith":
		print(FAIL_S, " vote state wrong: %s votes=%s" % [j.vote, votes])
		failures += 1
	j.set_vote("wraith")  # idempotent, no second signal
	if votes.size() != 1:
		print(FAIL_S, " vote_changed emitted twice for same vote")
		failures += 1

	# --- sync RPC keeps roster journals identical -----------------------------------
	var j2 := Journal.new()
	root.add_child(j2)
	await process_frame
	j2.sync_journal(j.captures, "poltergeist")
	if j2.captures.size() != j.captures.size() or j2.vote != "poltergeist":
		print(FAIL_S, " sync_journal did not mirror state")
		failures += 1
	if j2.possible_entities() != j.possible_entities():
		print(FAIL_S, " deduction diverged after sync")
		failures += 1

	# --- panel open/close (UI sanity) -------------------------------------------------
	j.toggle(true)
	if not j.is_open():
		print(FAIL_S, " journal panel does not open")
		failures += 1
	j.close()
	if j.is_open():
		print(FAIL_S, " journal panel does not close")
		failures += 1
	j.sync_journal([], "")  # empty list must not crash _refresh
	j._refresh()

	# --- full in-match loop: EMF reading near a hotspot -> log path ------------------
	var match_scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(match_scene)
	for i in 6:
		await process_frame

	var match_node: Node = root.get_node("Match")
	var player: Node3D = match_node.get_node("Player")
	var house: Node3D = null
	for child in match_node.get_children():
		if child is HouseBuilder:
			house = child
	if house == null or house.emf_hotspots.is_empty():
		print(FAIL_S, " house/hotspots missing")
		quit(1)
		return

	var hs: Dictionary = house.emf_hotspots[0]
	player.position = Vector3(hs["pos"].x, 0.1, hs["pos"].z)
	var mj: Journal = match_node.get_node("Journal")
	if mj == null:
		print(FAIL_S, " match has no Journal node")
		quit(1)
		return
	for i in 8:
		await physics_frame
	if player.emf.strongest_hotspot.is_empty():
		print(FAIL_S, " standing on a hotspot, reader saw nothing")
		failures += 1
	elif String(player.emf.strongest_hotspot["room"]) != String(hs["room"]) \
			or String(player.emf.strongest_hotspot["kind"]) != String(hs["kind"]):
		print(FAIL_S, " strongest_hotspot kind/room mismatch: %s vs %s" % [player.emf.strongest_hotspot, hs])
		failures += 1
	else:
		# The F-key route in match.gd calls exactly this with these values.
		mj.player_captured(String(player.emf.strongest_hotspot["kind"]),
				String(player.emf.strongest_hotspot["room"]))
		if mj.captures.size() != 1:
			print(FAIL_S, " player_captured did not add a capture")
			failures += 1

	if failures == 0:
		print(PASS_S)
	else:
		print(FAIL_S)
	quit(1 if failures > 0 else 0)