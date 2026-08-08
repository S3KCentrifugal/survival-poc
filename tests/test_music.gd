extends TestCase
## The generated music: that it is deterministic, that it does not clip, and
## that it loops without a click in the seam.
##
## None of which needs a speaker. [MusicComposer] is a [RefCounted] that turns
## a config into bytes, so "does it click at the loop point" is an assertion
## about two numbers rather than something you listen for at the wrong moment.

const CONFIG_PATH: String = "res://resources/audio/ambient_music.tres"
const MAIN_SCENE: String = "res://scenes/main.tscn"


## A short loop of its own. The real one is thirty seconds and a second to
## render, which is not a thing to do fifteen times in a test suite.
func _config() -> MusicConfig:
	var config := MusicConfig.new()
	config.sample_rate = 8000
	config.bars = 2
	config.tempo_bpm = 120.0
	config.noise_seed = 5
	return config


func _samples(config: MusicConfig) -> PackedFloat32Array:
	var bytes := MusicComposer.new(config).render()
	var samples := PackedFloat32Array()
	samples.resize(bytes.size() / 2)
	for index in samples.size():
		samples[index] = bytes.decode_s16(index * 2) / 32768.0
	return samples


func test_the_config_resource_loads() -> void:
	var config: MusicConfig = load(CONFIG_PATH)
	assert_not_null(config, "%s is missing or malformed" % CONFIG_PATH)
	assert_true(config.loop_seconds() > 4.0, "the loop is %f s long" % config.loop_seconds())
	assert_true(config.frame_count() > 0)


func test_it_renders_the_length_it_says_it_will() -> void:
	var config := _config()
	var bytes := MusicComposer.new(config).render()
	assert_eq(bytes.size(), config.frame_count() * 2, "16-bit mono is two bytes a frame")


## Same seed, same music. Otherwise a bug in it can never be chased.
func test_the_same_seed_renders_the_same_bytes() -> void:
	var config := _config()
	assert_eq(MusicComposer.new(config).render(), MusicComposer.new(config).render())


func test_a_different_seed_renders_different_music() -> void:
	var first := MusicComposer.new(_config()).render()
	var config := _config()
	config.noise_seed += 1
	assert_false(first == MusicComposer.new(config).render(), "the seed changed nothing")


## Silence is the failure mode that looks like success: everything runs, no
## errors, no sound.
func test_it_is_not_silent() -> void:
	var samples := _samples(_config())
	var loudest := 0.0
	for value: float in samples:
		loudest = maxf(loudest, absf(value))
	assert_true(loudest > 0.05, "the loudest sample is %f" % loudest)


## Soft-clipped rather than hard, so three voices summing past 1.0 leans instead
## of distorting -- but it still has to stay inside the range.
func test_nothing_clips() -> void:
	for value: float in _samples(_config()):
		assert_true(absf(value) <= 1.0, "a sample reached %f" % value)


## The seam is where a generated loop gives itself away. Note tails are wrapped
## past the end into the beginning precisely so the last sample and the first
## are neighbours rather than strangers.
func test_the_loop_seam_has_no_step_in_it() -> void:
	var samples := _samples(_config())
	var step := absf(samples[0] - samples[samples.size() - 1])

	# Compared against how far it moves between ordinary neighbouring samples,
	# not against zero: a fixed threshold would be a number with no meaning.
	var largest := 0.0
	for index in range(1, samples.size()):
		largest = maxf(largest, absf(samples[index] - samples[index - 1]))
	assert_true(
		step <= largest,
		"the loop jumps %f at the seam, more than the %f it ever moves in one step"
			% [step, largest]
	)


func test_the_melody_stays_on_the_scale() -> void:
	var config := _config()
	var composer := MusicComposer.new(config)
	for note: MusicComposer.Note in composer.melody():
		var interval := (note.midi - config.root_note) % 12
		assert_true(
			config.scale.has(interval),
			"a note landed %d semitones off the root, which is not in the scale" % interval
		)


func test_the_melody_is_sparse_rather_than_a_note_a_beat() -> void:
	var config := _config()
	config.bars = 8
	var notes := MusicComposer.new(config).melody().size()
	assert_true(notes > 0, "there is no melody at all")
	assert_true(
		notes < config.beat_count(),
		"%d notes over %d beats is a note on every beat" % [notes, config.beat_count()]
	)


## Rendering thirty seconds takes about a second, which is fine once and not
## fine on every scene mount.
func test_the_render_is_cached() -> void:
	var config: MusicConfig = load(CONFIG_PATH)
	MusicPlayer.build_stream(config)

	var start := Time.get_ticks_msec()
	for _repeat in 5:
		MusicPlayer.build_stream(config)
	var elapsed := Time.get_ticks_msec() - start
	assert_true(elapsed < 100, "five cached builds took %d ms, so they were not cached" % elapsed)


## Cached on the values, not the resource: a config edited at runtime has to
## produce different music, or the cache is a bug.
func test_changing_the_config_changes_the_signature() -> void:
	var config := _config()
	var before := MusicPlayer.signature(config)
	config.tempo_bpm += 1.0
	assert_false(before == MusicPlayer.signature(config), "a tempo change went unnoticed")


func test_the_stream_loops_over_the_whole_buffer() -> void:
	var config := _config()
	var stream := MusicPlayer.build_stream(config)
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "the music would play once and stop")
	assert_eq(stream.loop_begin, 0)
	assert_eq(stream.loop_end, config.frame_count())
	assert_eq(stream.mix_rate, config.sample_rate)


func test_the_world_carries_a_music_player() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(world)

	var music: MusicPlayer = world.get_node_or_null("Music")
	assert_not_null(music, "the world is silent")
	assert_not_null(music.config, "the music player has no config")
	assert_true(music.autoplay, "the music would never start")

	world.free()


## Not a test convenience: a headless run has no speakers, and Godot's headless
## audio server never releases the playback it was handed.
func test_it_does_not_play_with_no_display() -> void:
	var music := MusicPlayer.new()
	music.config = _config()
	(Engine.get_main_loop() as SceneTree).root.add_child(music)
	music.play()

	assert_false(music.is_playing(), "it started playing into a headless server")
	assert_true(music.stream() == null, "it built a stream with nowhere to play it")
	music.free()


## Music is silent until somebody asks for it.
##
## A game that starts playing at you unasked is a game muted at the operating
## system, after which nothing else it does with sound can reach you either.
func test_music_is_off_by_default() -> void:
	assert_eq(GameSettings.new().music_volume, 0.0, "the game starts playing music at you")


func test_the_rest_of_the_game_is_not_muted_with_it() -> void:
	assert_eq(GameSettings.new().master_volume, 1.0)


## On its own bus, so the slider turns the music down rather than the game.
func test_there_is_a_music_bus_to_turn_down() -> void:
	assert_true(
		AudioServer.get_bus_index(MusicPlayer.BUS) > 0,
		"there is no %s bus, so the music slider would do nothing" % MusicPlayer.BUS
	)


func test_the_music_bus_feeds_the_master_one() -> void:
	# Or the master slider would stop controlling the music, and "mute
	# everything" would leave the music playing.
	var bus := AudioServer.get_bus_index(MusicPlayer.BUS)
	assert_eq(AudioServer.get_bus_send(bus), &"Master")


func test_turning_the_slider_up_unmutes_the_bus() -> void:
	var bus := AudioServer.get_bus_index(MusicPlayer.BUS)
	var settings := GameSettings.new()

	SettingsApplier.apply_audio(settings)
	assert_true(AudioServer.is_bus_mute(bus), "silent settings left the bus playing")

	settings.music_volume = 0.6
	SettingsApplier.apply_audio(settings)
	assert_false(AudioServer.is_bus_mute(bus), "the slider did not reach the bus")
	assert_true(AudioServer.get_bus_volume_db(bus) < 0.0)

	# Left as the defaults found it, or every later suite runs with the music on.
	SettingsApplier.apply_audio(GameSettings.new())


func test_the_choice_survives_being_saved_and_read_back() -> void:
	var settings := GameSettings.new()
	settings.music_volume = 0.35
	assert_eq(settings.duplicate_settings().music_volume, 0.35)


## A settings file written before this existed must not start playing music at
## somebody who never asked for it.
func test_a_settings_file_from_before_this_existed_stays_silent() -> void:
	var old := GameSettings.new().to_dictionary()
	old.erase("music_volume")
	assert_eq(GameSettings.from_dictionary(old).music_volume, 0.0)


func test_a_volume_outside_the_slider_is_brought_back() -> void:
	var settings := GameSettings.new()
	settings.music_volume = 4.0
	settings.sanitise()
	assert_eq(settings.music_volume, 1.0)


## The menu has to actually offer it, or "off by default" is just "off".
func test_the_settings_menu_offers_a_music_slider() -> void:
	var menu: SettingsMenu = mount(load("res://ui/settings_menu.tscn").instantiate())
	var slider := menu.control(&"music_volume")
	assert_not_null(slider, "there is no music slider in the settings menu")

	var settings := GameSettings.new()
	settings.music_volume = 0.5
	menu.show_settings(settings)
	assert_eq(menu.collect().music_volume, 0.5, "the slider does not round-trip")
