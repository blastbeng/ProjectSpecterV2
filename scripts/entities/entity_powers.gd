class_name EntityPowers
extends Node
## Entity powers v1 (Vision 6): door slam, light flicker/brownout, fake
## footsteps. An invisible presence acts on the house on randomized
## cooldowns, biased toward the target investigator's position. Solo mode
## runs it as the entity AI once the match starts; the entity PLAYER role
## reuses these per-power methods with its own targeting later.

const NEAR_M := 14.0          # max distance for a power to be worth casting
## Seconds of violent flicker / of dead brownout lamp (vars so tests can shorten).
var flicker_time_s := 1.6
var kill_time_s := 7.0

var _house: HouseBuilder
var _target: Node3D
var _cooldowns := {"slam": 7.0, "flicker": 12.0, "steps": 4.0}
var _noise: FastNoiseLite
var _flicker_t := 0.0
var _flickering := 0.0
var _killed: Array = []       # [{light, until_msec}]
var _fake_remaining := 0
var _fake_pos := Vector3.ZERO
var _fake_dir := Vector3.RIGHT
var _fake_timer := 0.0
var _steps: AudioStreamPlayer3D
var _steps_played := 0
var last_power := ""


func setup(house: HouseBuilder, target: Node3D) -> void:
	_house = house
	_target = target
	_noise = FastNoiseLite.new()
	_noise.seed = 20260832
	_noise.frequency = 3.1
	_steps = AudioStreamPlayer3D.new()
	_steps.max_db = 6.0
	add_child(_steps)


func cooldown_left(power: String) -> float:
	return _cooldowns.get(power, 0.0)


func is_recovered() -> bool:
	return _killed.is_empty() and _flickering <= 0.0


func phantom_steps_played() -> int:
	return _steps_played


## ---- per-frame driver (host/solo only) -------------------------------------

func _process(delta: float) -> void:
	_tick_flicker(delta)
	_tick_fake_steps(delta)
	if not _is_authority():
		return
	for p in _cooldowns:
		_cooldowns[p] = maxf(_cooldowns[p] - delta, 0.0)
	_try_cast()


func _is_authority() -> bool:
	# Solo play or host runs the presence; clients just observe the results
	# (RPC fan-out arrives with the entity-player role).
	return multiplayer.get_unique_id() == 1 or _target == null


func _try_cast() -> void:
	if _target == null or _house == null:
		return
	var tpos := _target.global_position
	if tpos.distance_to(_house.global_position) > 60.0:
		return
	if _cooldowns["steps"] <= 0.0:
		cast_fake_steps(tpos)
	elif _cooldowns["slam"] <= 0.0:
		cast_door_slam(tpos)
	elif _cooldowns["flicker"] <= 0.0:
		cast_flicker(tpos)


## ---- powers ----------------------------------------------------------------

## SLAM: the nearest open door slams shut; a closed nearby door rattles hard.
func cast_door_slam(at: Vector3) -> void:
	if _house == null:
		return
	var best: InteractableDoor = null
	var best_d := NEAR_M
	for node in _house.find_children("*", "InteractableDoor", true, false):
		var d := node as InteractableDoor
		var dist := d.global_position.distance_to(at)
		if dist < best_d:
			best_d = dist
			best = d
	if best == null:
		return
	best.entity_slam()
	_cooldowns["slam"] = randf_range(14.0, 22.0)
	last_power = "slam"


## FLICKER: lamps near the target strobe, one may brown out for a while.
func cast_flicker(at: Vector3) -> void:
	if _house == null:
		return
	var hit_any := false
	for node in _house.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light.global_position.distance_to(at) > NEAR_M:
			continue
		hit_any = true
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
		# 25 % chance a lamp browns out instead of strobing.
		if randf() < 0.25:
			light.light_energy = 0.0
			_killed.append({"light": light, "until": Time.get_ticks_msec() + int(kill_time_s * 1000)})
	_flickering = flicker_time_s
	_cooldowns["flicker"] = randf_range(18.0, 26.0)
	if hit_any:
		last_power = "flicker"


## FAKE FOOTSTEPS: a phantom walks a few steps from a point near the target.
func cast_fake_steps(at: Vector3) -> void:
	var ang := randf() * TAU
	_fake_dir = Vector3(cos(ang), 0.0, sin(ang))
	_fake_pos = at + _fake_dir * 1.2
	_fake_remaining = 6
	_fake_timer = 0.0
	_cooldowns["steps"] = randf_range(13.0, 19.0)
	last_power = "steps"


## ---- effect ticks -----------------------------------------------------------

func _tick_flicker(delta: float) -> void:
	if _noise == null:
		return
	# Restore brownout-ed lamps when their time is up.
	var now := Time.get_ticks_msec()
	for i in range(_killed.size() - 1, -1, -1):
		if now >= int(_killed[i]["until"]):
			var light: OmniLight3D = _killed[i]["light"]
			if is_instance_valid(light) and light.has_meta("base_energy"):
				light.light_energy = light.get_meta("base_energy")
			_killed.remove_at(i)
	# Violent strobe during the flicker window.
	if _flickering > 0.0:
		_flickering -= delta
		_flicker_t += delta * 34.0
		for node in _house.find_children("*", "OmniLight3D", true, false):
			var light := node as OmniLight3D
			if light.has_meta("base_energy") and light.light_energy > 0.01:
				var base: float = light.get_meta("base_energy")
				var f := 0.35 + 0.65 * absf(_noise.get_noise_1d(_flicker_t))
				light.light_energy = base * f


func _tick_fake_steps(_delta: float) -> void:
	if _fake_remaining <= 0:
		return
	_fake_timer -= _delta
	if _fake_timer <= 0.0:
		_fake_timer = 0.44
		_fake_remaining -= 1
		_fake_pos += _fake_dir * 0.95
		_steps.global_position = _fake_pos
		if _steps.stream == null:
			_steps.stream = SfxGenerator.footstep(9)
		_steps.pitch_scale = randf_range(0.9, 1.05)
		_steps.play()
		_steps_played += 1