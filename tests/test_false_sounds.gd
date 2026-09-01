extends SceneTree
## False sounds test (Vision 6 fear->gameplay part 2): at fear >= 55 whisper
## bursts and phantom knocks fire; knocks are positioned BEHIND the player
## (opposite camera facing) and the streams are real PCM buffers. Below the
## threshold nothing fires. Drives the real FearMeter + FalseSounds via
## Match.sample loop.

const PASS_S := "TEST_FALSE_SOUNDS_RESULT=PASS"
const FAIL_S := "TEST_FALSE_SOUNDS_RESULT=FAIL"


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
	var fm: FearMeter = m.get_node("FearMeter")
	var fs: FalseSounds = fm.false_sounds
	if fs == null:
		_fail("FalseSounds child missing")
		return

	# Aim the camera down -Z (yaw 0) so "behind" is +Z; knock must land at
	# player_pos - cam_basis.z * 2.5 => z smaller than player z.
	player.rotation.y = 0.0
	player._pitch = 0.0

	# 1) Below threshold: 3 s of game time fires nothing.
	fm.fear = 30.0
	var t := 0.0
	while t < 3.0:
		var dt: float = get_root().get_process_delta_time() if get_root() else 1.0 / 60.0
		fm.sample(dt, player, [], m.get_node_or_null("EntityPowers"))
		t += dt
		await process_frame
		await process_frame
	if fs.whisper_count != 0 or fs.knock_count != 0:
		_fail("sounds fired below threshold: w=%d k=%d" % [fs.whisper_count, fs.knock_count])
		return

	# 2) Above threshold: force cooldowns to fire on the next tick.
	fm.fear = 70.0
	fs._whisper_cooldown = 0.001
	fs._knock_cooldown = 0.001
	t = 0.0
	var fired_whisper := false
	var fired_knock := false
	while t < 2.0 and not (fired_whisper and fired_knock):
		var dt: float = get_root().get_process_delta_time() if get_root() else 1.0 / 60.0
		fm.sample(dt, player, [], m.get_node_or_null("EntityPowers"))
		t += dt
		if fs.whisper_count > 0:
			fired_whisper = true
		if fs.knock_count > 0:
			fired_knock = true
			var knock: Node = fs._knock
			# Behind = opposite of camera -Z. With yaw 0 the player faces -Z,
			# so behind is +Z: knock z must be GREATER than player z.
			if knock.global_position.z <= player.global_position.z:
				_fail("knock not behind player: knock_z=%.2f player_z=%.2f" % [
					knock.global_position.z, player.global_position.z])
				return
		await process_frame
		await process_frame
	if not fired_whisper:
		_fail("whisper never fired at fear 70")
		return
	if not fired_knock:
		_fail("knock never fired at fear 70")
		return

	# 3) Streams are real generated PCM (non-empty, 22050 Hz).
	var w: AudioStreamWAV = fs._whisper.stream
	var k: AudioStreamWAV = fs._knock.stream
	if w == null or k == null or w.data.size() < 1000 or k.data.size() < 1000:
		_fail("streams missing or empty")
		return
	if w.mix_rate != 22050 or k.mix_rate != 22050:
		_fail("bad mix rates: %d %d" % [w.mix_rate, k.mix_rate])
		return

	print(PASS_S, " whisper=%d knock=%d last=%s" % [fs.whisper_count, fs.knock_count, fs.last_sound])
	quit(0)