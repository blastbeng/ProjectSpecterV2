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