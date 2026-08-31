class_name FearMeter
extends Node
## Fear system (Vision 6): a 0-100 scalar fed by darkness, isolation and
## entity activity. Drives heartbeat/breathing audio pacing (SfxGenerator
## heartbeat PCM), a HUD meter (MatchHUD.set_fear), camera sway at high fear
## (applied by PlayerController reading the value) and slows interaction at
## the very top of the scale. Never nauseating: sway caps at ~1.2 degrees.

signal fear_changed(value01: float)

## Contribution weights per second while the condition holds (tuned so a
## lone player in the dark spikes to ~70 within ~25 s).
const DARK_RATE := 1.9        # brightness < 0.18 at the player
const ISOLATION_RATE := 1.1   # no teammate avatar within 8 m
const ENTITY_BASE_RATE := 2.4 # entity recently cast a power nearby
const RELIEF_RATE := 6.0      # decay in lit + company safety
const MAX_FEAR := 100.0

## Darkness probe: sampled at the player's eye position each 0.25 s.
var fear := 0.0
var _probe_timer := 0.0
var _dark := false
var _isolated := false
var _entity_activity_left := 0.0
## Camera sway phase; PlayerController reads sway_offset() each frame.
var _sway_t := 0.0
var _heart: AudioStreamPlayer
var _heart_cooldown := 0.0


func _ready() -> void:
	_heart = AudioStreamPlayer.new()
	_heart.bus = "Master"
	add_child(_heart)


## Per-frame update: Match calls every frame with its scene references.
func sample(delta: float, player: Node3D, avatars: Array, entity_powers: Node) -> void:
	_probe_timer -= delta
	if _probe_timer <= 0.0:
		_probe_timer = 0.25
		_probe_darkness(player)
		_probe_isolation(player, avatars)
	var rate := 0.0
	if _dark:
		rate += DARK_RATE
	if _isolated:
		rate += ISOLATION_RATE
	rate += _entity_activity_left * ENTITY_BASE_RATE
	if _entity_activity_left > 0.0:
		_entity_activity_left = maxf(_entity_activity_left - delta, 0.0)
	if rate <= 0.0:
		rate = -RELIEF_RATE
	fear = clampf(fear + rate * delta, 0.0, MAX_FEAR)

	# Heartbeat pacing: interval shrinks (60 -> 150 bpm) as fear rises.
	if fear > 18.0:
		_heart_cooldown -= delta
		if _heart_cooldown <= 0.0:
			_heart_cooldown = lerpf(1.0, 0.4, fear / MAX_FEAR)
			_play_heartbeat(fear / MAX_FEAR)
	# Sway phase advances faster with fear; amplitude lives in sway_offset().
	_sway_t += delta * (0.6 + 1.6 * (fear / MAX_FEAR))
	fear_changed.emit(fear / MAX_FEAR)


func _probe_darkness(player: Node3D) -> void:
	# Cheap darkness: distance to the nearest lit lamp + flashlight state.
	# (Sampling the actual light grid per frame is too dear on mobile.)
	var lit := false
	for light in player.get_tree().get_nodes_in_group("fear_lights"):
		var l := light as OmniLight3D
		if l == null or not is_instance_valid(l):
			continue
		if l.light_energy > 0.4 and l.global_position.distance_to(player.global_position) < l.omni_range * 0.8:
			lit = true
			break
	var flash: Flashlight = player.get("flashlight") if player != null else null
	if flash != null and flash.is_on():
		lit = true
	_dark = not lit


func _probe_isolation(player: Node3D, avatars: Array) -> void:
	_isolated = true
	for av in avatars:
		if is_instance_valid(av) and av.global_position.distance_to(player.global_position) < 8.0:
			_isolated = false
			break


func on_entity_power_near(at: Vector3, player: Node3D) -> void:
	if at.distance_to(player.global_position) < 12.0:
		_entity_activity_left = minf(_entity_activity_left + 1.6, 3.0)


func ratio() -> float:
	return fear / MAX_FEAR


## Camera roll/offset hint (radians); capped low to stay comfortable.
func sway_offset() -> float:
	if fear < 45.0:
		return 0.0
	var amp := 0.021 * ((fear - 45.0) / 55.0)  # ~1.2 deg max
	return sin(_sway_t * TAU) * amp


func _play_heartbeat(strength01: float) -> void:
	_heart.stream = SfxGenerator.heartbeat(strength01)
	_heart.volume_db = lerpf(-16.0, -6.0, strength01)
	_heart.play()