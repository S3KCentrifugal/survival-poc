extends TestCase
## The settings model: what is valid, and what a bad value becomes.


func test_defaults_are_usable() -> void:
	var settings := GameSettings.new()
	settings.sanitise(1)
	assert_true(settings.resolution.x >= GameSettings.MIN_RESOLUTION.x)
	assert_eq(settings.monitor, 0)
	assert_true(settings.render_scale > 0.0)


## A file written on a two-monitor desk and opened on a laptop would otherwise
## put the window on a screen that is not there, which looks exactly like the
## game failing to start.
func test_a_monitor_that_is_no_longer_there_falls_back_to_the_first() -> void:
	var settings := GameSettings.new()
	settings.monitor = 3
	settings.sanitise(1)
	assert_eq(settings.monitor, 0)


func test_a_monitor_that_exists_is_kept() -> void:
	var settings := GameSettings.new()
	settings.monitor = 2
	settings.sanitise(3)
	assert_eq(settings.monitor, 2)


func test_a_negative_monitor_is_refused() -> void:
	var settings := GameSettings.new()
	settings.monitor = -4
	settings.sanitise(2)
	assert_eq(settings.monitor, 0)


func test_a_tiny_resolution_is_raised_to_something_usable() -> void:
	var settings := GameSettings.new()
	settings.resolution = Vector2i(16, 9)
	settings.sanitise()
	assert_eq(settings.resolution, GameSettings.MIN_RESOLUTION)


## Someone will edit the file and ask for 4000 FPS. They should get the highest
## cap we offer, not the number they typed.
func test_an_unsupported_frame_cap_rounds_down_to_one_we_offer() -> void:
	var settings := GameSettings.new()
	settings.max_fps = 4000
	settings.sanitise()
	assert_eq(settings.max_fps, 240)

	settings.max_fps = 100
	settings.sanitise()
	assert_eq(settings.max_fps, 60, "should round down, not up")


func test_a_negative_frame_cap_becomes_unlimited() -> void:
	var settings := GameSettings.new()
	settings.max_fps = -30
	settings.sanitise()
	assert_eq(settings.max_fps, 0)


func test_an_unsupported_msaa_level_rounds_down() -> void:
	var settings := GameSettings.new()
	settings.msaa = 16
	settings.sanitise()
	assert_eq(settings.msaa, 8)

	settings.msaa = 3
	settings.sanitise()
	assert_eq(settings.msaa, 2)


func test_render_scale_and_volume_are_clamped() -> void:
	var settings := GameSettings.new()
	settings.render_scale = 9.0
	settings.master_volume = 5.0
	settings.look_sensitivity = -1.0
	settings.sanitise()
	assert_true(settings.render_scale <= 2.0)
	assert_true(settings.master_volume <= 1.0)
	assert_true(settings.look_sensitivity > 0.0)


func test_an_unknown_display_mode_falls_back() -> void:
	var settings := GameSettings.new()
	settings.display_mode = 99 as GameSettings.DisplayMode
	settings.sanitise()
	assert_true(settings.display_mode < GameSettings.DisplayMode.size())


func test_it_survives_a_round_trip_through_plain_values() -> void:
	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.BORDERLESS
	settings.resolution = Vector2i(2560, 1440)
	settings.monitor = 1
	settings.vsync = false
	settings.max_fps = 144
	settings.msaa = 4
	settings.render_scale = 0.75
	settings.master_volume = 0.4
	settings.look_sensitivity = 0.5
	settings.invert_pitch = true

	var restored := GameSettings.from_dictionary(settings.to_dictionary())
	assert_true(restored.matches(settings), "%s came back as %s" % [
		settings.to_dictionary(), restored.to_dictionary()
	])


## A truncated or hand-edited file should lose one setting, not all of them.
func test_missing_values_fall_back_one_at_a_time() -> void:
	var restored := GameSettings.from_dictionary({"max_fps": 120})
	assert_eq(restored.max_fps, 120)
	assert_eq(restored.resolution, GameSettings.new().resolution)
	assert_eq(restored.vsync, GameSettings.new().vsync)


func test_values_of_the_wrong_type_are_ignored() -> void:
	var restored := GameSettings.from_dictionary({
		"max_fps": "lots", "vsync": "yes please", "resolution_x": [1, 2]
	})
	assert_eq(restored.max_fps, GameSettings.new().max_fps)
	assert_eq(restored.vsync, GameSettings.new().vsync)
	assert_eq(restored.resolution.x, GameSettings.new().resolution.x)


func test_an_empty_dictionary_gives_defaults() -> void:
	assert_true(GameSettings.from_dictionary({}).matches(GameSettings.new()))


func test_copies_are_independent() -> void:
	var settings := GameSettings.new()
	var copy := settings.duplicate_settings()
	copy.max_fps = 144
	assert_ne(settings.max_fps, copy.max_fps, "editing a copy changed the original")


## Both fullscreen modes take the monitor's size, which is what greys the
## resolution picker out.
func test_only_windowed_uses_the_chosen_resolution() -> void:
	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.WINDOWED
	assert_false(settings.uses_monitor_size())
	settings.display_mode = GameSettings.DisplayMode.FULLSCREEN
	assert_true(settings.uses_monitor_size())
	settings.display_mode = GameSettings.DisplayMode.BORDERLESS
	assert_true(settings.uses_monitor_size())


func test_every_mode_has_a_name() -> void:
	for mode: int in range(GameSettings.DisplayMode.size()):
		var name := GameSettings.display_mode_name(mode as GameSettings.DisplayMode)
		assert_false(name.is_empty(), "mode %d has no name" % mode)


func test_the_offered_resolutions_are_sane() -> void:
	for size: Vector2i in GameSettings.resolutions():
		assert_true(size.x >= GameSettings.MIN_RESOLUTION.x, "%v is too small" % size)
		assert_true(size.y >= GameSettings.MIN_RESOLUTION.y, "%v is too small" % size)
