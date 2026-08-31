class_name PlayerController
extends CharacterBody3D
## First-person investigator controller (Vision 5.3/5.7 base).
## Everything is code-built: capsule + camera + interaction ray created here.
## Includes accel/decel movement, sprint + stamina, crouch, head bob and
## code-generated footsteps.

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.8
const CROUCH_SPEED := 1.7
const ACCEL := 9.5
const DECEL := 11.5
const GRAVITY := 12.5
const MOUSE_SENS := 0.0022
const EYE_HEIGHT := 1.65
const CROUCH_EYE_HEIGHT := 1.05
const BOB_AMPLITUDE := 0.032
const BOB_FREQUENCY := 8.5
const STAMINA_MAX := 100.0
const STAMINA_DRAIN := 22.0
const STAMINA_REGEN := 16.0
const STAMINA_SPRINT_MIN := 12.0
## Panic interactions (Vision 6): above this fear the E key becomes a
## hold-to-complete bar with shaking breath audio.
const FEAR_HOLD_THRESHOLD := 80.0

var _pitch := 0.0
var _bob_phase := 0.0
var _stamina := STAMINA_MAX
var _crouching := false
var _step_accum := 0.0
var _footsteps: Array[AudioStreamWAV] = []
var _last_look_delta := Vector2.ZERO
## Panic hold tracking (Vision 6): Match flips set_panic(true) when fear
## crosses ~82; the E key then becomes a hold-to-complete interaction with
## shaking-breath audio, released (hysteresis) once fear drops below ~75.
var panic_hold_target_s := 1.1
var _panic_hold := 0.0
var _panicking := false
var _holding_e := false
var _e_was_down := false
var _hold_fired := false
var _panic_shaky: AudioStreamPlayer
var _panic_breath: AudioStreamWAV

var camera: Camera3D
var interact_ray: InteractionRay
var flashlight: Flashlight
var emf: EmfReader
var stamina := STAMINA_MAX


func _ready() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.75
	col.shape = cap
	col.position = Vector3(0, 0.875, 0)
	add_child(col)

	camera = Camera3D.new()
	camera.position = Vector3(0, EYE_HEIGHT, 0)
	camera.fov = 75.0
	camera.near = 0.05
	add_child(camera)
	camera.current = true

	interact_ray = InteractionRay.new()
	interact_ray.position = Vector3.ZERO
	camera.add_child(interact_ray)

	flashlight = Flashlight.new()
	camera.add_child(flashlight)

	# EMF reader rides the camera's left side; hotspots arrive from Match.
	emf = EmfReader.new()
	camera.add_child(emf)

	for v in range(4):
		_footsteps.append(SfxGenerator.footstep(v))

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Fear wiring (Vision 6): Match calls every frame with the current fear.
func set_panic(on: bool) -> void:
	if on == _panicking:
		return
	_panicking = on
	if on:
		_start_shaky_breath()
	else:
		_stop_shaky_breath()


func is_panicking() -> bool:
	return _panicking


## Direct interaction (tests + scripted events bypass the hold gate).
func try_interact() -> void:
	interact_ray.try_interact()


func stamina_ratio() -> float:
	return stamina / STAMINA_MAX


## Fear system (Vision 6): a small camera roll offset, fed by Match each
## frame; peaks ~1.2 deg, no translation so it never nauseates.
func set_fear_sway(offset_rad: float) -> void:
	if camera != null:
		camera.rotation.z = offset_rad


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, deg_to_rad(-85.0), deg_to_rad(85.0))
		camera.rotation.x = _pitch
		notify_look(Vector2(event.relative.x, event.relative.y))

	elif event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_F:
		flashlight.toggle()



func _read_move_input() -> Vector2:
	var right := 0.0
	var forward := 0.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		right += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		right -= 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		forward += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		forward -= 1.0
	# y = forward (+W), so basis * Vector3(x, 0, y) maps into local space.
	return Vector2(right, forward)


func _physics_process(delta: float) -> void:
	var input_vec := _read_move_input()
	var direction := (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y))
	if direction.length_squared() > 1.0:
		direction = direction.normalized()

	# Crouch state (Vision 5.7: camera lowers).
	var want_crouch := Input.is_physical_key_pressed(KEY_CTRL)
	if want_crouch:
		_crouching = true
	elif not _is_ceiling_blocked() and _crouching:
		_crouching = false

	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and input_vec.y > 0.1 \
			and not _crouching and stamina > 0.5
	var target_speed := CROUCH_SPEED if _crouching else (SPRINT_SPEED if sprinting else WALK_SPEED)
	var target := direction * target_speed

	var horiz := Vector2(velocity.x, velocity.z)
	var rate := ACCEL if direction.length_squared() > 0.01 else DECEL
	horiz = horiz.lerp(Vector2(target.x, target.z), clampf(rate * delta, 0.0, 1.0))
	velocity.x = horiz.x
	velocity.z = horiz.y

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	move_and_slide()

	# Stamina: drain while sprinting, regen otherwise.
	if sprinting and Vector2(velocity.x, velocity.z).length() > 0.5:
		stamina = maxf(stamina - STAMINA_DRAIN * delta, 0.0)
	else:
		stamina = minf(stamina + STAMINA_REGEN * delta, STAMINA_MAX)

	# Footsteps: distance-based accumulation.
	var speed2 := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed2 > 0.4:
		_step_accum += speed2 * delta
		var stride := 1.35 if sprinting else (1.1 if not _crouching else 1.6)
		if _step_accum >= stride:
			_step_accum = 0.0
			_play_step()
	else:
		_step_accum = 0.0

	# Head bob toward eye height (crouch lerps smoothly).
	var bob_amount := clampf(speed2 / SPRINT_SPEED, 0.0, 1.0) if not _crouching else 0.35
	var eye := CROUCH_EYE_HEIGHT if _crouching else EYE_HEIGHT
	if is_on_floor():
		_bob_phase += delta * BOB_FREQUENCY * bob_amount
	var offset := sin(_bob_phase) * BOB_AMPLITUDE * bob_amount
	camera.position.y = lerpf(camera.position.y, eye + offset, 10.0 * delta)
	camera.position.x = cos(_bob_phase * 0.5) * BOB_AMPLITUDE * 0.4 * bob_amount

	# Viewmodel sway + light battery tick.
	flashlight.update_viewmodel(_last_look_delta, speed2, delta)
	emf.update_viewmodel(_last_look_delta, speed2, delta)
	emf.sample(global_position + Vector3(0, EYE_HEIGHT, 0), delta)
	_last_look_delta = Vector2.ZERO

	# Panic interactions (Vision 6): above FEAR_HOLD_THRESHOLD fear the E key
	# must be HELD for panic_hold_target_s seconds to finish an interaction;
	# below it, a tap interacts instantly. Shaky breath loops while panicking.
	_poll_panic_interaction(delta)


## Polls the E key each physics tick. Calm: a tap fires on the press edge.
## While panicking, holding E on an interactable charges the hold; a
## completed charge fires the interaction and an early release resets it.
func _poll_panic_interaction(delta: float) -> void:
	var e_down := Input.is_physical_key_pressed(KEY_E)
	var pressed_edge := e_down and not _e_was_down
	var ray := interact_ray as RayCast3D
	var aiming := false
	if ray != null and ray.is_colliding():
		var hit := ray.get_collider()
		aiming = hit != null and (hit.has_method("interact") or hit.has_method("toggle"))
	if _panicking:
		# One shot per key press: a fired hold waits for release before it
		# may charge again (otherwise a held key re-toggles the same door).
		if _hold_fired and e_down:
			_holding_e = false
			_panic_hold = 0.0
			return
		if not e_down:
			_hold_fired = false
		_holding_e = e_down and aiming
		if _holding_e:
			_panic_hold += delta
			if _panic_hold >= panic_hold_target_s:
				_panic_hold = 0.0
				_hold_fired = true
				ray.try_interact()
		else:
			_panic_hold = 0.0
	else:
		if pressed_edge and aiming:
			ray.try_interact()
		_holding_e = false
		_panic_hold = 0.0
	_e_was_down = e_down


## Camera roll add-on while a panic hold is charging (small tremble, caps
## well under the fear sway cap). Match adds this to the fear sway offset.
func panic_shake() -> float:
	if not _panicking or _panic_hold <= 0.0:
		return 0.0
	var t := Time.get_ticks_msec() * 0.001
	var ramp := clampf(_panic_hold / panic_hold_target_s, 0.0, 1.0)
	return sin(t * 26.0) * 0.006 * ramp


## Prompt with hold progress: "Open door — hold E 45%" while charging.
func current_prompt() -> String:
	var base := interact_ray.current_prompt()
	if _panicking and _holding_e and base != "":
		var pct := int(clampf(_panic_hold / panic_hold_target_s, 0.0, 0.99) * 100.0)
		return "%s — hold E %d%%" % [base, pct]
	if _panicking and base != "":
		return "%s — hold E" % base
	return base


func _start_shaky_breath() -> void:
	if _panic_shaky == null:
		_panic_shaky = AudioStreamPlayer.new()
		_panic_shaky.volume_db = -9.0
		_panic_shaky.bus = "Master"
		add_child(_panic_shaky)
	if _panic_breath == null:
		_panic_breath = SfxGenerator.breathing(1.0)
	_panic_shaky.stream = _panic_breath
	if not _panic_shaky.playing:
		_panic_shaky.play()


func _stop_shaky_breath() -> void:
	if _panic_shaky != null and _panic_shaky.playing:
		_panic_shaky.stop()
		_panic_shaky.stream = null


func notify_look(delta_vec: Vector2) -> void:
	_last_look_delta = delta_vec


func _is_ceiling_blocked() -> bool:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.9, 0), global_position + Vector3(0, 1.9, 0))
	return not space.intersect_ray(params).is_empty()


var _step_player: AudioStreamPlayer
var _step_index := 0

func _play_step() -> void:
	if _step_player == null:
		_step_player = AudioStreamPlayer.new()
		_step_player.max_polyphony = 3
		add_child(_step_player)
	_step_player.pitch_scale = randf_range(0.92, 1.08)
	_step_player.stream = _footsteps[_step_index % _footsteps.size()]
	_step_index += 1
	_step_player.volume_db = -8.0 if not _crouching else -16.0
	_step_player.play()