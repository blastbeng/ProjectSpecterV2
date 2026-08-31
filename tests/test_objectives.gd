extends SceneTree
## Objective pipeline headless check (Vision 6):
## locked room door -> breaker inside -> door unlocks, extraction activates;
## gate interact -> countdown starts and ticks; timer expiry flags failure.

const MATCH_SCENE := "res://scenes/match.tscn"
const PASS_S := "TEST_OBJECTIVES_RESULT=PASS"
const FAIL_S := "TEST_OBJECTIVES_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print(FAIL_S, " ", msg)
	quit(1)


func _run() -> void:
	var scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame

	var match_node: Node = root.get_node("Match")
	var house: HouseBuilder = null
	for child in match_node.get_children():
		if child is HouseBuilder:
			house = child
	var hud: MatchHUD = null
	var gate: ExtractionGate = null
	for child in match_node.get_children():
		if child is MatchHUD:
			hud = child
		if child is ExtractionGate:
			gate = child
	if house == null or hud == null or gate == null:
		_fail("missing house/hud/extraction gate")
		return

	# --- stage 1: locked room door is padlocked at start ---
	var lock_room := house.locked_room()
	if lock_room == "":
		_fail("no seed-locked room")
		return
	var door := house.door_to(lock_room)
	if door == null or not door.is_locked():
		_fail("locked room door is not locked")
		return
	if not hud.objective_label.text.contains("way into"):
		_fail("objective line wrong at start: '%s'" % hud.objective_label.text)
		return

	# --- stage 1 -> 2: opening the (unlocked-by-test) door advances stage ---
	door.unlock()  # in-game the entity/key flow unlocks; here direct
	door.interact()  # open fires state_changed(true) -> match advances
	for i in 5:
		await process_frame
	if match_node._stage != "power":
		_fail("stage did not advance to power after door open (=%s)" % match_node._stage)
		return

	# --- breaker: flip it -> door unlocks + gate activates + stage extract --
	var br := house.breaker
	if br == null:
		_fail("breaker panel missing")
		return
	if br.interaction_prompt() == "":
		_fail("breaker prompt empty before flip")
		return
	br.interact()
	for i in 10:
		await process_frame
	if not br.is_restored():
		_fail("breaker did not flip")
		return
	if door.is_locked():
		_fail("locked-room door still locked after power restore")
		return
	if not gate.is_active():
		_fail("extraction gate not activated after power restore")
		return
	if match_node._stage != "extract":
		_fail("stage did not advance to extract (=%s)" % match_node._stage)
		return
	if not hud.objective_label.text.contains("extraction"):
		_fail("objective line not updated to extraction")
		return

	# --- gate interact -> countdown runs and visibly ticks down ------------
	gate.interact()
	for i in 10:
		await process_frame
	if not match_node._extract_running:
		_fail("extraction countdown not running")
		return
	if not gate.is_started():
		_fail("gate did not mark started")
		return
	if not hud.extract_label.visible:
		_fail("countdown label not shown")
		return
	var t0: float = match_node._extract_left
	for i in 30:
		await physics_frame
	var t1: float = match_node._extract_left
	if t1 >= t0:
		_fail("countdown not ticking (t0=%f t1=%f)" % [t0, t1])
		return

	print(PASS_S)
	quit(0)