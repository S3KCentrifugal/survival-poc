class_name MusicPlayer
extends Node
## Plays the generated background music, on a loop, forever.
##
## Thin: [MusicComposer] writes the samples, this wraps them in a stream and
## starts it. Routed through the Master bus so the existing volume setting
## already controls it -- music with no way to turn it down is worse than no
## music.

signal started

@export var config: MusicConfig

## Off by default in code and on in the scene. A test that mounts the world a
## hundred times should not synthesise a minute of audio a hundred times, and
## the ones that care turn it on themselves.
@export var autoplay: bool = true

## Extra trim in decibels, for balancing against effects later.
@export_range(-40.0, 6.0, 0.5) var volume_db: float = -6.0

## Whether to play with no window open.
##
## Off, and it is not a test hack. A headless run has no speakers, so
## synthesising thirty seconds of audio and holding a megabyte of samples buys
## exactly nothing -- and Godot's headless audio server never mixes, so it never
## releases the playback either, which is reported as a leak on the way out.
## Exported rather than hard-coded because a headless *client* is a thing that
## could exist, and it should be able to say so.
@export var play_without_display: bool = false

var _player: AudioStreamPlayer


func _ready() -> void:
	if autoplay:
		play()


## Builds the loop and starts it. Idempotent -- calling twice does not stack a
## second copy over the first, and silent when there is nothing to play into.
func play() -> void:
	if _player != null:
		return
	if not play_without_display and DisplayServer.get_name() == "headless":
		return
	if config == null:
		push_warning("MusicPlayer has no config; falling back to defaults")
		config = MusicConfig.new()

	_player = AudioStreamPlayer.new()
	_player.stream = build_stream(config)
	_player.volume_db = volume_db
	_player.bus = &"Master"
	# Music is not part of the simulation. It should keep going while the pause
	# menu is open, which is exactly when silence is most noticeable.
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.play()
	started.emit()


## Stopped on the way out, and the stream let go with it.
##
## Freeing an AudioStreamPlayer that is still playing leaves the audio server
## holding an AudioStreamPlaybackWAV, which holds the stream, which is two
## objects the engine counts on exit and reports as a leak. Nothing audibly
## wrong; it just makes an otherwise clean run look dirty, and a warning nobody
## can explain is a warning everybody learns to ignore.
func _exit_tree() -> void:
	if _player == null:
		return
	_player.stop()
	_player.stream = null
	# Freed here rather than left to the tree. The audio server releases a
	# playback when its player goes away, and waiting for that to happen during
	# teardown means it does not.
	_player.get_parent().remove_child(_player)
	_player.free()
	_player = null


func stop() -> void:
	if _player != null:
		_player.stop()


func is_playing() -> bool:
	return _player != null and _player.playing


## The stream being played, for a test to inspect.
func stream() -> AudioStream:
	return null if _player == null else _player.stream


## Rendered sample data, by config signature.
##
## Synthesising thirty seconds of audio in GDScript takes about a second, which
## is fine once and not fine on every scene load -- the test suite mounts the
## world dozens of times. The render is a pure function of the config, so the
## answer can be kept: same numbers, same bytes, no reason to do it twice.
##
## Holds the **bytes**, not the stream. A static variable holding a Resource is
## still holding it when the engine counts objects on the way out, and gets
## reported as a leak on an otherwise clean run. A PackedByteArray is not an
## object, so there is nothing to count.
##
## Keyed by the values rather than by the resource, so editing a config at
## runtime regenerates instead of quietly playing the old music.
static var _rendered: Dictionary[String, PackedByteArray] = {}


## Renders [param config] into a looping 16-bit mono stream, or returns the one
## already rendered for these numbers.
##
## Static so it can be built and measured without a scene tree.
static func build_stream(config: MusicConfig) -> AudioStreamWAV:
	var key := signature(config)
	if not _rendered.has(key):
		_rendered[key] = MusicComposer.new(config).render()

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = config.sample_rate
	stream.stereo = false
	stream.data = _rendered[key]
	# The whole buffer, forward, forever. The composer wraps note tails past the
	# end into the beginning so the seam has no click in it.
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = config.frame_count()
	return stream


## Every value that changes the output, as a string. Anything not in here is a
## config change the cache will not notice.
static func signature(config: MusicConfig) -> String:
	return "|".join([
		str(config.sample_rate), str(config.bars), str(config.beats_per_bar),
		str(config.tempo_bpm), str(config.root_note), str(config.scale),
		str(config.note_density), str(config.drone_level), str(config.pad_level),
		str(config.melody_level), str(config.gain), str(config.attack_seconds),
		str(config.release_seconds), str(config.noise_seed),
	])


## Renders the samples, cache or no cache.
static func render_samples(config: MusicConfig) -> PackedByteArray:
	return MusicComposer.new(config).render()
