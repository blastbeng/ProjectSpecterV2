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