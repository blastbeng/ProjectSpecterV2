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
var last_power := ""       # last power the entity cast (for HUD/tests)
var _last_rpc_kind := ""   # last received RPC kind (net tests poll this)
## Seeded rng so every peer independently picks the SAME brownout victims
## from the fan-out payload (no per-lamp random rolls over the wire).
var _rng: RandomNumberGenerator
var _rng_shared_seed := 990217  # one brownout-victim sequence per event


func setup(house: HouseBuilder, target: Node3D) -> void:
	_house = house
	_target = target
	_rng = RandomNumberGenerator.new()
	_rng.seed = _rng_shared_seed
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
	# Solo play or host runs the presence; clients observe via RPC fan-out.
	# Guard: early frames / tests may run before any peer is assigned, where
	# get_unique_id() errors — treat "no peer yet" as authority (harmless:
	# the OfflineMultiplayerPeer default makes solo play authoritative too).
	var mp := get_multiplayer()
	if mp == null or mp.multiplayer_peer == null:
		return true
	return mp.get_unique_id() == 1


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
	var path := String(_door_path(best))
	if _is_authority():
		_send_event("slam", {"door": path})
	_cooldowns["slam"] = randf_range(14.0, 22.0)
	last_power = "slam"


## FLICKER: lamps near the target strobe, one may brown out for a while.
func cast_flicker(at: Vector3) -> void:
	if _house == null:
		return
	var hit_any := false
	var victim_positions: Array = []
	for node in _house.find_children("*", "OmniLight3D", true, false):
		var light := node as OmniLight3D
		if light.global_position.distance_to(at) > NEAR_M:
			continue
		hit_any = true
		victim_positions.append(_light_key(light))
	if not hit_any:
		return
	# Lights are addressed by GLOBAL POSITION (auto-named nodes can differ
	# across peers; positions are deterministic from the seed).
	_send_event("flicker", {"positions": _round_positions(victim_positions), "window": flicker_time_s})
	_flickering = flicker_time_s
	_cooldowns["flicker"] = randf_range(18.0, 26.0)
	last_power = "flicker"


## FAKE FOOTSTEPS: a phantom walks a few steps from a point near the target.
func cast_fake_steps(at: Vector3) -> void:
	var ang := randf() * TAU
	_fake_dir = Vector3(cos(ang), 0.0, sin(ang))
	_fake_pos = at + _fake_dir * 1.2
	_fake_remaining = 6
	_fake_timer = 0.0
	# Applied locally by _net_event; remote peers replay the same walk.
	_send_event("steps", {"pos": _fake_pos, "dir": _fake_dir})
	_cooldowns["steps"] = randf_range(13.0, 19.0)
	last_power = "steps"


## Lights are addressed by position, not node names: lamps are auto-named
## (@OmniLight3D@N) and can differ across peers, while positions are
## deterministic from the seed. Rounded so float wire round-trips match.
func _light_key(light: OmniLight3D) -> Vector3:
	return light.global_position.snapped(Vector3(0.05, 0.05, 0.05))


func _round_positions(keys: Array) -> Array:
	var out: Array = []
	for k in keys:
		out.append(k)
	return out


## ---- network fan-out (Vision 6): clients replay host-cast powers ----------

func _door_path(d: InteractableDoor) -> NodePath:
	return _house.get_path_to(d)


## call_local executes on the caster too, so this single call applies
## locally in solo play (OfflineMultiplayerPeer) and fans out online.
func _send_event(kind: String, data: Dictionary) -> void:
	_net_event.rpc(kind, data)


@rpc("authority", "call_local", "reliable")
func _net_event(kind: String, data: Dictionary = {}) -> void:
	_last_rpc_kind = kind
	match kind:
		"slam":
			_apply_slam(String(data["door"]))
		"flicker":
			_pending_flicker = data["positions"] as Array
			if data.has("window"):
				flicker_time_s = float(data["window"])
			_call_deferred_apply_flicker()
		"steps":
			_apply_steps(data["pos"], data["dir"])


func _apply_slam(path: NodePath) -> void:
	var d := _resolve_door(path)
	if d != null:
		d.entity_slam()


var _pending_flicker: Array = []


func _resolve_door(path: NodePath) -> InteractableDoor:
	if _house == null:
		return null
	return _house.get_node_or_null(path) as InteractableDoor


func _resolve_light(key: Vector3) -> OmniLight3D:
	if _house == null:
		return null
	# Position-keyed lookup (rebuilt lazily when lights move/restore).
	for node in _house.find_children("*", "OmniLight3D", true, false):
		if _light_key(node as OmniLight3D) == key:
			return node
	return null


func _apply_flicker(keys: Array) -> void:
	# Re-seed per event: same shared seed + same ordered position list makes
	# every peer independently pick the identical brownout victim set.
	if _rng != null:
		_rng.seed = _rng_shared_seed
	for p in keys:
		var light := _resolve_light(p)
		if light == null:
			continue
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
		# 25 % brownout per lamp; shared seed + ordered position list keeps
		# every peer's victim set identical without extra wire payloads.
		if _rng.randf() < 0.25:
			light.light_energy = 0.0
			_killed.append({"light": light, "until": Time.get_ticks_msec() + int(kill_time_s * 1000)})
	last_power = "flicker"


func _apply_steps(pos: Vector3, dir: Vector3) -> void:
	_fake_pos = pos
	_fake_dir = dir
	_fake_remaining = 6
	_fake_timer = 0.0
	last_power = "steps"


func _call_deferred_apply_flicker() -> void:
	# Defer one frame so node paths are valid even if RPC raced the build.
	_apply_flicker(_pending_flicker)
	_pending_flicker = []


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