class_name SfxGenerator
extends RefCounted
## Code-generated sound effects (Vision 4: AudioStreamWAV from PCM bytes).
## No imported audio anywhere.

const RATE := 22050


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## Tiny mechanical click for flashlight toggle.
static func click() -> AudioStreamWAV:
	var n := int(0.03 * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * 1900.0 / RATE
		var square := 1.0 if sin(phase) > 0.0 else -1.0
		var env := 1.0 - t / 0.03
		samples[i] = clampf(square * env * 0.5, -1.0, 1.0)
	return _to_wav(samples)


## Short footstep: filtered noise burst + low body thump.
static func footstep(variant := 0) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + absi(variant)
	var duration := 0.16
	var n := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var thump_f := rng.randf_range(70.0, 95.0)
	for i in n:
		var t := float(i) / RATE
		var body := 1.0 - minf(t / 0.09, 1.0)
		body *= body
		phase += TAU * thump_f / RATE
		var thump := sin(phase) * body * 0.55
		# heel scrape noise, decaying quickly
		var noise := rng.randf_range(-1.0, 1.0) * (1.0 - t / duration) * 0.35
		noise *= 0.5 + 0.5 * sin(t * 210.0)
		samples[i] = clampf(thump + noise, -1.0, 1.0)
	return _to_wav(samples)


## Shaky breathing loop for panic (Vision 6): in/out swells of filtered
## noise with a tremor, ~3.2 s round trip so it can loop seamlessly. When
## strong01 approaches 1 the breath gets rougher (added jitter).
static func breathing(strong01 := 0.8) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700
	var duration := 3.2
	var n := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var jitter_phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		# Two breath swells per loop (in at 0.2s, out at 1.8s).
		var swell := maxf(sin(t * TAU / duration * 2.0 - TAU * 0.25), 0.0)
		swell *= swell
		var raw := rng.randf_range(-1.0, 1.0)
		lp = lerpf(lp, raw, 0.12)  # soften toward breathy hiss
		jitter_phase += TAU * 13.0 / RATE
		var tremor := 1.0 + 0.35 * strong01 * sin(jitter_phase)
		var body := 0.18 + 0.2 * strong01
		samples[i] = clampf(lp * swell * tremor * body * 1.9, -1.0, 1.0)
	return _to_wav(samples)


## Heartbeat: lub-dub pair of low thumps (Vision 6 fear audio).
## strength01 shapes tempo-irrelevant character: deeper + harder at high fear.
static func heartbeat(strength01 := 0.5) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + int(strength01 * 20.0)
	var duration := 0.42
	var n := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var beats := [0.0, 0.22]           # lub (strong), dub (softer)
	var gains := [1.0, 0.62]
	var f0 := lerpf(52.0, 42.0, strength01)  # deeper when scared
	for i in n:
		var t := float(i) / RATE
		var s := 0.0
		for k in 2:
			var dt: float = t - beats[k]
			if dt > 0.0 and dt < 0.16:
				var env: float = exp(-dt * 26.0)
				var phase: float = TAU * f0 * dt
				var thump: float = sin(phase) * env * gains[k]
				# body knock: a little 2nd harmonic
				thump += sin(phase * 2.0) * env * gains[k] * 0.3
				s += thump * 0.72
		# faint breathy noise floor at high fear.
		s += rng.randf_range(-1.0, 1.0) * 0.02 * strength01
		samples[i] = clampf(s, -1.0, 1.0)
	return _to_wav(samples)


## Objective "power restored": rising two-tone hum + relay thunk (Vision 6).
static func power_up(seed_value := 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + absi(seed_value)
	var duration := 1.1
	var n := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var phase2 := 0.0
	for i in n:
		var t := float(i) / RATE
		# Rising hum: 55 -> 110 Hz with a fifth layered in halfway.
		var f := 55.0 + 55.0 * minf(t / duration, 1.0)
		phase += TAU * f / RATE
		phase2 += TAU * f * 1.5 / RATE
		var hum := sin(phase) * 0.4
		var fifth := sin(phase2) * 0.22 * (0.0 if t < 0.45 else minf((t - 0.45) / 0.2, 1.0))
		# Envelope: ramp up, hold, decay at the tail.
		var env := minf(t / 0.15, 1.0)
		if t > duration - 0.25:
			env *= (duration - t) / 0.25
		# Relay thunk at t = 0.62 s.
		var thunk := 0.0
		if t > 0.6 and t < 0.66:
			thunk = sin(TAU * 90.0 * (t - 0.6)) * (0.66 - t) * 6.0
		# Faint machine fizz.
		var fizz := rng.randf_range(-1.0, 1.0) * 0.03 * env
		samples[i] = clampf((hum + fifth + thunk) * env + fizz, -1.0, 1.0)
	return _to_wav(samples)


## Locked-door rattle: short metal knob jangles against the latch plate.
static func rattle(seed_value := 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var duration := 0.35
	var n := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	# Three knob strikes; each strike is a bright metallic burst with fast decay.
	for s in range(3):
		var strike_t := float(s) * 0.11 + rng.randf_range(-0.01, 0.01)
		var f0 := rng.randf_range(2100.0, 2900.0)
		for i in int(0.06 * RATE):
			var t := float(i) / RATE
			var idx := int((strike_t + t) * RATE)
			if idx >= n:
				break
			var phase := TAU * f0 * t
			var body := sin(phase) + 0.6 * sin(2.7 * phase) + 0.3 * sin(5.3 * phase)
			# Hard attack, exponential ring.
			var env := exp(-t * 55.0) * minf(t / 0.004, 1.0)
			samples[idx] += body * env * 0.22
	return _to_wav(samples)


## Brass key turn: two low clicks plus a smooth mid-freq scrape sweep.
static func unlock(seed_value := 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var duration := 0.5
	var n := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		# Continuous key-in-cylinder rasp: rising frequency sweep with tremble.
		var f := 340.0 + 520.0 * t + 90.0 * sin(t * 61.0)
		phase += TAU * f / RATE
		var rasp := sin(phase) * 0.35 * (0.5 + 0.5 * sin(t * 95.0 + 3.0))
		var amp := minf(t / 0.03, 1.0) * minf((duration - t) / 0.18, 1.0)
		samples[i] += rasp * amp
	# Two detent clicks (key passes tumblers).
	for ct in [0.09, 0.31]:
		for i in int(0.02 * RATE):
			var t := float(i) / RATE
			var idx := int(ct * RATE) + i
			if idx >= n:
				break
			var c := rng.randf_range(-1.0, 1.0) * exp(-t * 260.0) * 0.5
			samples[idx] += c
	return _to_wav(samples)


## EMF reader beep: two-tone "dut-doo" chirp; pitch_scale raises per level.
static func emf_beep() -> AudioStreamWAV:
	var n := int(0.11 * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var phase2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1180.0 if t < 0.05 else 1560.0
		phase += TAU * f / RATE
		phase2 += TAU * (f * 2.01) / RATE
		var env := minf(t / 0.005, 1.0) * exp(-t * 26.0)
		var body := sin(phase) * 0.7 + sin(phase2) * 0.25
		samples[i] = clampf(body * env * 0.4, -1.0, 1.0)
	return _to_wav(samples)


## Heavy door slam (entity power): low body thump + latch clack burst.
static func slam(seed_value := 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 700 + absi(seed_value)
	var samples := PackedFloat32Array()
	# Low body: 300 ms decaying sine sweep 120 -> 55 Hz.
	var body_n := int(0.30 * RATE)
	samples.resize(body_n)
	var phase := 0.0
	for i in body_n:
		var t := float(i) / RATE
		var f := lerpf(120.0, 55.0, t / 0.30)
		phase += TAU * f / RATE
		var env := (1.0 - t / 0.30)
		env *= env
		samples[i] = sin(phase) * env * 0.85
	# Latch burst on top: two bright metallic clacks at 0.26 s and 0.29 s.
	var tail_n := int(0.10 * RATE)
	var latch_f := 0
	for i in tail_n:
		var t := float(i) / RATE
		var idx := body_n + i
		samples.resize(idx + 1)
		var amp := 0.0
		if t < 0.015:
			amp = (1.0 - t / 0.015) * 0.7
		elif t >= 0.03 and t < 0.042:
			amp = (1.0 - (t - 0.03) / 0.012) * 0.5
		latch_f += 1
		var ring := sin(TAU * (2600.0 + 900.0 * sin(t * 310.0)) * t) * amp
		samples[idx] = clampf(samples[idx] + ring, -1.0, 1.0)
	return _to_wav(samples)


## Stick-slip door creak: dragging saw partial with wobble + tremble envelope.
static func creak(seed_value := 1) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var duration := 0.9
	var n := int(duration * RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	var phase2 := 0.0
	var drift := rng.randf_range(-8.0, 8.0)
	for i in n:
		var t := float(i) / RATE
		# stick-slip pitch wobble + slow upward drag
		var wobble := sin(t * 9.0 + rng.randf() * 0.2) * 55.0
		var f := 165.0 + wobble + t * (55.0 + drift)
		phase += TAU * f / RATE
		phase2 += TAU * f * 2.63 / RATE
		var saw := 2.0 * fmod(phase / TAU, 1.0) - 1.0
		var partial := 0.35 * sin(phase2)
		# envelope: fast attack, slow release, stick-slip tremble
		var amp := minf(t / 0.07, 1.0) * minf((duration - t) / 0.35, 1.0)
		amp *= 0.72 + 0.28 * sin(t * 27.0 + 1.7)
		# faint friction noise
		var noise := rng.randf_range(-1.0, 1.0) * 0.05 * amp
		samples[i] = clampf((saw * 0.5 + partial + noise) * amp * 0.9, -1.0, 1.0)
	return _to_wav(samples)