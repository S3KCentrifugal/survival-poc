class_name MusicComposer
extends RefCounted
## Writes a short piece of music and renders it to samples.
##
## Pure: no nodes, no audio server, no playback. Given a config it produces the
## same bytes every time, which is what lets "does it loop without a click" and
## "does it clip" be assertions rather than something you listen for and then
## argue about.
##
## Three voices, chosen because they cannot clash: a **drone** on the root for
## the whole loop, a **pad** chord that changes once a bar, and a sparse
## **melody**. All of them sit on a minor pentatonic scale, which has no
## semitones in it -- so any two notes sounding together are consonant, and most
## of the ways generated music goes wrong are simply unavailable.

## One note: when it starts, how long it lasts, and how loud.
class Note:
	extends RefCounted

	var start: float
	var duration: float
	var midi: int
	var level: float

	func _init(p_start: float, p_duration: float, p_midi: int, p_level: float) -> void:
		start = p_start
		duration = p_duration
		midi = p_midi
		level = p_level


var _config: MusicConfig
var _rng: RandomNumberGenerator


func _init(config: MusicConfig) -> void:
	_config = config if config != null else MusicConfig.new()
	_rng = RandomNumberGenerator.new()
	_rng.seed = _config.noise_seed


## The melody, as notes. Public so a test can look at what was written rather
## than only at what it sounds like.
func melody() -> Array[Note]:
	var notes: Array[Note] = []
	var beat := _config.beat_seconds()
	# A random walk over scale degrees rather than independent draws: a line
	# that leaps everywhere is a sequence of notes, not a tune.
	var degree := 0

	for index in _config.beat_count():
		if _rng.randf() > _config.note_density:
			continue
		degree = clampi(degree + _rng.randi_range(-2, 2), 0, _config.scale.size() * 2 - 1)
		var octave := degree / _config.scale.size()
		var midi := (
			_config.root_note
			+ 12
			+ _config.scale[degree % _config.scale.size()]
			+ octave * 12
		)
		# Held for a beat and a half, so notes overlap and the line is legato.
		notes.append(Note.new(index * beat, beat * 1.5, midi, _config.melody_level))
	return notes


## The pad, as notes: a chord per bar, each a root/fifth/octave triad.
func pad() -> Array[Note]:
	var notes: Array[Note] = []
	var bar := _config.beat_seconds() * _config.beats_per_bar
	for index in _config.bars:
		# Alternates between the root and the fourth degree. Two chords is
		# enough to feel like it is going somewhere and few enough that it
		# never resolves anywhere surprising.
		var offset: int = 0 if index % 2 == 0 else _config.scale[2]
		var root := _config.root_note + offset
		for interval: int in [0, 7, 12]:
			notes.append(Note.new(index * bar, bar * 1.05, root + interval, _config.pad_level))
	return notes


## Renders the loop as 16-bit mono PCM, ready for an [AudioStreamWAV].
func render() -> PackedByteArray:
	var frames := _config.frame_count()
	var rate := float(_config.sample_rate)
	var samples := PackedFloat32Array()
	samples.resize(frames)

	# The drone runs the whole loop and never stops, so it needs no envelope
	# and cannot click at the loop point.
	var drone_hz := _frequency(_config.root_note - 12)
	for index in frames:
		var t := index / rate
		samples[index] = (
			sin(TAU * drone_hz * t) * 0.6 + sin(TAU * drone_hz * 2.0 * t) * 0.4
		) * _config.drone_level

	for note: Note in pad():
		_mix(samples, note, rate, 0.45, 3.0)
	for note: Note in melody():
		_mix(samples, note, rate, _config.attack_seconds, _config.release_seconds)

	return _to_pcm(samples)


## Adds one enveloped voice into [param samples].
##
## Wraps past the end of the buffer rather than truncating: a note that starts
## in the last bar has to finish at the *beginning*, or the loop clicks every
## time it comes round.
func _mix(
	samples: PackedFloat32Array,
	note: Note,
	rate: float,
	attack: float,
	release: float
) -> void:
	var frames := samples.size()
	var hz := _frequency(note.midi)
	var length := int((note.duration + release) * rate)
	var start := int(note.start * rate)

	for offset in length:
		var t := offset / rate
		var envelope := _envelope(t, note.duration, attack, release)
		if envelope <= 0.0:
			continue
		# Two detuned voices. A single sine is a test tone; a pair a few cents
		# apart beats slowly against itself and sounds like an instrument.
		var value := (
			sin(TAU * hz * t) * 0.55 + sin(TAU * hz * 1.005 * t) * 0.45
		)
		samples[(start + offset) % frames] += value * envelope * note.level


## Attack, sustain, release. Linear, because nobody can hear the difference at
## these speeds and an exponential is one more thing to get wrong.
static func _envelope(t: float, duration: float, attack: float, release: float) -> float:
	if t < 0.0:
		return 0.0
	if t < attack:
		return t / maxf(attack, 0.0001)
	if t < duration:
		return 1.0
	var fading := (t - duration) / maxf(release, 0.0001)
	return maxf(1.0 - fading, 0.0)


static func _frequency(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Floats to 16-bit little-endian PCM, soft-clipped on the way.
##
## tanh rather than a hard clamp: three voices summing past 1.0 is normal and
## a hard clamp turns that into audible distortion, where tanh just leans on it.
static func _to_pcm(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in samples.size():
		var value: float = tanh(samples[index])
		bytes.encode_s16(index * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	return bytes
