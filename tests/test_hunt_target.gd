extends SceneTree
## Entity hunt targeting test (Vision 6 fear->gameplay part 2b): the entity
## must prefer ISOLATED HIGH-FEAR investigators over comfortable ones.
## Feeds a candidate board with a scared isolated player + a fearless
## teammate avatar, ticks EntityPowers._process, and asserts _pick_target
## picks the scared one; then flips the board (crowded fearless player +
## isolated scared avatar) and asserts it switches. Also checks
## FearMeter.estimate_fear darkness/isolation deltas.

const PASS_S := "TEST_HUNT_RESULT=PASS"
const FAIL_S := "TEST_HUNT_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print(FAIL_S, " ", msg)
	quit(1)


func _run() -> void:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	for i in 6:
		await process_frame

	var m: Node = root.get_node("Match")
	var player: PlayerController = m.get_node("Player")
	var powers: EntityPowers = m.get_node("EntityPowers")
	var fm: FearMeter = m.get_node("FearMeter")

	# Stand the player somewhere lit-agnostic; board values are forced anyway.
	player.global_position = Vector3(3.0, 0.0, 3.85)

	# 1) Scared isolated player vs fearless demo teammate.
	fm.fear = 85.0
	powers.candidates = [
		{"node": player, "fear": 85.0, "isolated": true},
		{"node": m._demo_avatar, "fear": 5.0, "isolated": false},
	]
	powers._cand_refresh = 0.001
	powers._process(0.016)
	if powers._target != player:
		_fail("hunt did not pick scared isolated player: %s" % powers._target.name)
		return
	if powers.hunted_last != player.name:
		_fail("hunted_last not player: %s" % powers.hunted_last)
		return

	# 2) Flip: player comfortable+crowded, avatar isolated+scared.
	fm.fear = 10.0
	powers.candidates = [
		{"node": player, "fear": 10.0, "isolated": false},
		{"node": m._demo_avatar, "fear": 80.0, "isolated": true},
	]
	powers._cand_refresh = 0.001
	powers._process(0.016)
	if powers._target != m._demo_avatar:
		_fail("hunt did not switch to scared isolated avatar: %s" % powers._target.name)
		return

	# 3) Empty board falls back to the default target (no crash, keeps aim).
	powers.candidates = []
	powers._cand_refresh = 0.001
	powers._process(0.016)
	if powers._target == null:
		_fail("empty board nulled the target")
		return

	# 4) estimate_fear: darkness + isolation must beat lit+company.
	var house: HouseBuilder = m.find_children("*", "HouseBuilder", true, false)[0]
	var others: Array = [m._demo_avatar]
	var est_dark: float = FearMeter.estimate_fear(Vector3(50.0, 0.0, 50.0), others, house)
	var est_safe: float = FearMeter.estimate_fear(player.global_position, [m._demo_avatar], house)
	if not (est_dark > est_safe + 30.0):
		_fail("estimate_fear spread too small: dark=%.1f safe=%.1f" % [est_dark, est_safe])
		return

	print(PASS_S, " hunt=%s est_dark=%.0f est_safe=%.0f" % [powers.hunted_last, est_dark, est_safe])
	quit(0)