class_name FalseSounds
extends Node
## Fear -> gameplay, part 2 (Vision 6): at high fear the house itself lies.
## Whisper bursts and phantom knocks fire BEHIND the player (opposite the
## camera's facing) so turning around finds nothing — pure atmosphere dread.
## Purely local (no networking): hallucinations are per-mind by design.
## All audio is code-generated (SfxGenerator PCM); no external assets.

const MIN_FEAR := 55.0        # engage threshold
const WHISPER_GAP_RANGE := Vector2(9.0, 20.0)   # seconds between whispers
const KNOCK_GAP_RANGE := Vector2(12.0, 26.0)    # seconds between knocks
const WHISPER_CHANCE := 0.85  # per-engage dice: not every spike whispers

var last_sound := ""          # "whisper" | "knock" (test/HUD hook)
var last_sound_pos := Vector3.ZERO
var whisper_count := 0
var knock_count := 0

var _player: Node3D
var _whisper_cooldown := 0.0
var _knock_cooldown := 0.0
var _whisper: AudioStreamPlayer
var _knock: AudioStreamPlayer3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_whisper = AudioStreamPlayer.new()
	_whisper.bus = "Master"
	add_child(_whisper)
	var knock3d := AudioStreamPlayer3D.new()
	knock3d.unit_size = 6.0
	knock3d.bus = "Master"
	_knock = knock3d
	add_child(_knock)
	_whisper_cooldown = _rng.randf_range(WHISPER_GAP_RANGE.x, WHISPER_GAP_RANGE.y)
	_knock_cooldown = _rng.randf_range(KNOCK_GAP_RANGE.x, KNOCK_GAP_RANGE.y)


## Match wires the target player after building the scene.
func setup(player: Node3D) -> void:
	_player = player


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var fm: FearMeter = get_parent() as FearMeter
	if fm == null:
		return
	if fm.fear < MIN_FEAR:
		# Fear below the line: hallucinations fade back out (cooldowns keep
		# running so a fear spike does not instantly fire on re-entry).
		_whisper_cooldown = maxf(_whisper_cooldown - delta * 0.5, 0.5)
		_knock_cooldown = maxf(_knock_cooldown - delta * 0.5, 0.5)
		return
	_whisper_cooldown -= delta
	_knock_cooldown -= delta
	if _whisper_cooldown <= 0.0:
		_whisper_cooldown = _rng.randf_range(WHISPER_GAP_RANGE.x, WHISPER_GAP_RANGE.y)
		if _rng.randf() < WHISPER_CHANCE:
			_cast_whisper()
	if _knock_cooldown <= 0.0:
		_knock_cooldown = _rng.randf_range(KNOCK_GAP_RANGE.x, KNOCK_GAP_RANGE.y)
		_cast_knock()


## Whisper burst: non-directional breathy voices swelling at the player's
## head — something spoke and there is no one there.
func _cast_whisper() -> void:
	_whisper.stream = SfxGenerator.whisper_burst()
	_whisper.volume_db = lerpf(-10.0, -3.0, clampf(_fear_ratio(), 0.0, 1.0))
	_whisper.play()
	whisper_count += 1
	last_sound = "whisper"
	last_sound_pos = _player.global_position


## Phantom knock: 2-4 wood thumps from a point ~2.5 m BEHIND the player,
## opposite the camera facing. 3D positional so panning points over the
## shoulder; walking back finds an empty hall.
func _cast_knock() -> void:
	# Camera basis .z points BACKWARD from the view (forward is -z), so
	# behind the player is +basis.z.
	var cam_basis: Basis = (_player as PlayerController).camera.global_transform.basis
	var behind: Vector3 = _player.global_position + cam_basis.z * 2.5
	behind.y = 1.0
	last_sound_pos = behind
	_knock.stream = SfxGenerator.phantom_knock()
	_knock.volume_db = lerpf(-4.0, 2.0, clampf(_fear_ratio(), 0.0, 1.0))
	_knock.global_position = behind
	_knock.play()
	knock_count += 1
	last_sound = "knock"


func _fear_ratio() -> float:
	var fm: FearMeter = get_parent() as FearMeter
	return fm.fear / FearMeter.MAX_FEAR if fm != null else 0.0