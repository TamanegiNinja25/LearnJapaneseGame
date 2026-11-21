## Builds the game's sound effects and background loop as WAV files (original, synthesised here,
## so no third-party audio licence applies).
##
##   godot --headless --path game --script ../tools/make_sounds.gd
##
## Plucked notes use the Karplus-Strong string model (a koto-like timbre); the scale is the
## Japanese yo pentatonic on D (D E G A B). Outputs go to game/assets/audio/.
extends SceneTree

const RATE := 22050
const OUT := "res://assets/audio/"
## Yo scale degrees as semitones above D4 (293.66 Hz), two octaves.
const YO := [0, 2, 5, 7, 9, 12, 14, 17, 19, 21, 24]
const D4 := 293.66

var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_rng.seed = 2026  # same files every run
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save("correct", _mix([_pluck(_hz(7), 0.5, 0.9), _delay(_pluck(_hz(12), 0.6, 0.9), 0.09)]))
	_save("wrong", _mix([_tone(220.0, 0.16, 0.5), _delay(_tone(185.0, 0.22, 0.5), 0.12)]))
	_save("stroke", _pluck(_hz(19), 0.18, 0.55))
	_save("complete", _mix([_pluck(_hz(0), 0.9, 0.8), _delay(_pluck(_hz(5), 0.8, 0.8), 0.1),
		_delay(_pluck(_hz(9), 0.8, 0.8), 0.2), _delay(_pluck(_hz(14), 1.0, 0.85), 0.3)]))
	_save("levelup", _mix([_pluck(_hz(7), 0.7, 0.8), _delay(_pluck(_hz(12), 0.7, 0.8), 0.08),
		_delay(_pluck(_hz(17), 0.7, 0.8), 0.16), _delay(_pluck(_hz(24), 1.1, 0.9), 0.24)]))
	_save("music_loop", _music())
	quit()


func _hz(degree_semitones: int) -> float:
	return D4 * pow(2.0, degree_semitones / 12.0)


## Karplus-Strong pluck: a noise burst in a delay line, averaged each pass (string damping).
func _pluck(freq: float, seconds: float, gain: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var period := maxi(2, int(RATE / freq))
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = _rng.randf_range(-1.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(n)
	var idx := 0
	for i in n:
		var cur := line[idx]
		var nxt := line[(idx + 1) % period]
		line[idx] = 0.996 * 0.5 * (cur + nxt)
		out[i] = cur * gain * (1.0 - float(i) / n) # gentle overall fade
		idx = (idx + 1) % period
	return out


## A soft sine "boop" with a quick attack and decay (used for the gentle wrong-answer cue).
func _tone(freq: float, seconds: float, gain: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.01) * exp(-t * 9.0)
		out[i] = sin(TAU * freq * t) * env * gain
	return out


func _delay(sound: PackedFloat32Array, seconds: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE))
	out.append_array(sound)
	return out


func _mix(parts: Array) -> PackedFloat32Array:
	var n := 0
	for p: PackedFloat32Array in parts:
		n = maxi(n, p.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for p: PackedFloat32Array in parts:
		for i in p.size():
			out[i] += p[i]
	return out


## 16 s loop at 90 bpm: a slow pentatonic melody over a low drone, quiet enough to study with.
func _music() -> PackedFloat32Array:
	var beat := 60.0 / 90.0
	var bars := 6
	var total := int(beat * 4 * bars * RATE)
	var out := PackedFloat32Array()
	out.resize(total)
	# Drone: D2 and A2, slowly breathing.
	for i in total:
		var t := float(i) / RATE
		var breathe := 0.5 + 0.5 * sin(TAU * t / (beat * 8))
		out[i] = (sin(TAU * 73.42 * t) * 0.05 + sin(TAU * 110.0 * t) * 0.035) * (0.6 + 0.4 * breathe)
	var melody := [7, 9, 12, 9, 7, 5, 2, 5, 7, 12, 14, 12, 9, 7, 5, 0, 2, 5, 7, 9, 7, 5, 2, 0]
	for k in melody.size():
		var start := int(k * beat * RATE)
		var note := _pluck(_hz(melody[k]), beat * 2.2, 0.32 if k % 4 == 0 else 0.24)
		for i in note.size():
			out[(start + i) % total] += note[i]  # wrap so the tail rings into the loop start
	return out


func _save(name: String, samples: PackedFloat32Array) -> void:
	var peak := 0.0
	for v in samples:
		peak = maxf(peak, absf(v))
	var scale := 0.85 / peak if peak > 0.85 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * scale, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	var path := ProjectSettings.globalize_path(OUT + name + ".wav")
	var err := wav.save_to_wav(path)
	print("%s.wav %.2f s -> %s" % [name, samples.size() / float(RATE), error_string(err)])
