extends TestCase
## The 3D render resolution cap: what it leaves alone, and what it rescues.

const FOUR_K: Vector2i = Vector2i(3840, 2160)

## The display this project was profiled on, and the reason [RenderBudget]
## exists. Kept as a named constant so the test says what it is testing.
const SIX_K: Vector2i = Vector2i(6144, 3456)


func test_a_1080p_display_is_left_completely_alone() -> void:
	assert_eq(RenderBudget.scale_for(Vector2i(1920, 1080)), 1.0)


func test_1440p_is_still_native() -> void:
	# The budget is 1440p, so the display it is set from must not be scaled --
	# a cap that catches the resolution it was derived from is off by one rung.
	assert_eq(RenderBudget.scale_for(Vector2i(2560, 1440)), 1.0)


func test_the_steam_deck_is_never_touched() -> void:
	assert_eq(RenderBudget.scale_for(Vector2i(1280, 800)), 1.0)


func test_4k_comes_down() -> void:
	var scale := RenderBudget.scale_for(FOUR_K)
	assert_true(scale < 1.0, "4K rendered at full resolution")
	assert_true(
		RenderBudget.rendered_pixels(FOUR_K, scale) <= RenderBudget.DEFAULT_PIXELS,
		"4K at %f still costs %d pixels" % [scale, RenderBudget.rendered_pixels(FOUR_K, scale)]
	)


## The finding this whole thing came from: fullscreen on this desk asked the
## renderer for 21 megapixels, ten times 1080p, and nothing anywhere objected.
func test_the_6k_display_that_started_this_is_brought_under_control() -> void:
	var scale := RenderBudget.scale_for(SIX_K)
	var before := SIX_K.x * SIX_K.y
	var after := RenderBudget.rendered_pixels(SIX_K, scale)
	assert_true(after * 3 < before, "6K went from %d to %d pixels, which is not a rescue" % [
		before, after
	])


## Deliberate, not an oversight. Below half, bilinear upscaling is visibly soft,
## and a display that still costs too much at 0.5 needs FSR rather than a
## smaller number.
func test_it_refuses_to_go_below_half_however_large_the_display() -> void:
	assert_eq(RenderBudget.scale_for(Vector2i(15360, 8640)), RenderBudget.MIN_SCALE)


func test_every_scale_it_returns_is_a_rung_on_the_ladder() -> void:
	# A continuous scale means a resize changes the number every frame and no two
	# machines ever report the same one, so no performance figure can be
	# compared with another.
	for height in range(400, 4400, 137):
		var scale := RenderBudget.scale_for(Vector2i(height * 16 / 9, height))
		assert_true(
			RenderBudget.LADDER.has(scale), "%dp produced %f, which is not a rung" % [height, scale]
		)


## Rounding to nearest would let a display sit above the budget, which is the
## one thing a budget must not allow.
func test_it_never_lands_above_the_budget() -> void:
	for height in range(1000, 4400, 89):
		var size := Vector2i(height * 16 / 9, height)
		var scale := RenderBudget.scale_for(size)
		if scale == RenderBudget.MIN_SCALE:
			continue  # The floor is allowed to exceed it; that is what a floor is.
		assert_true(
			RenderBudget.rendered_pixels(size, scale) <= RenderBudget.DEFAULT_PIXELS,
			"%s at %f exceeds the budget" % [size, scale]
		)


## The scale applies to both axes, so 0.5 is a quarter of the pixels and not
## half. Getting this wrong gives a plausible-looking number that misses the
## budget by two.
func test_the_scale_is_squared_not_halved() -> void:
	assert_eq(RenderBudget.rendered_pixels(Vector2i(1000, 1000), 0.5), 250_000)


func test_a_degenerate_size_does_not_divide_by_zero() -> void:
	assert_eq(RenderBudget.scale_for(Vector2i.ZERO), 1.0)
	assert_eq(RenderBudget.scale_for(Vector2i(-100, 200)), 1.0)


func test_a_zero_budget_is_treated_as_no_budget() -> void:
	assert_eq(RenderBudget.scale_for(FOUR_K, 0), 1.0)


func test_it_says_whether_a_display_is_capped_at_all() -> void:
	# For the settings tooltip, which should not imply it is protecting a 1080p
	# player from something.
	assert_false(RenderBudget.is_capped(Vector2i(1920, 1080)))
	assert_true(RenderBudget.is_capped(SIX_K))


func test_it_describes_itself_in_terms_a_person_can_check() -> void:
	var text := RenderBudget.describe(FOUR_K)
	assert_true(text.contains("3840x2160"), "the description hides the display: %s" % text)
	assert_true(text.contains("MP"), "the description hides the cost: %s" % text)


## The setting is the policy's off switch, and it is what a player who wants to
## supersample reaches for.
func test_turning_auto_off_hands_the_number_back_to_the_player() -> void:
	var settings := GameSettings.new()
	settings.render_scale_auto = false
	settings.render_scale = 2.0
	assert_eq(SettingsApplier.render_scale_for(settings, SIX_K), 2.0)


func test_auto_is_on_by_default_because_it_is_fixing_a_bug() -> void:
	assert_true(GameSettings.new().render_scale_auto)
	assert_eq(SettingsApplier.render_scale_for(GameSettings.new(), SIX_K), RenderBudget.MIN_SCALE)


func test_the_choice_survives_being_saved_and_read_back() -> void:
	var settings := GameSettings.new()
	settings.render_scale_auto = false
	var restored := settings.duplicate_settings()
	assert_false(restored.render_scale_auto, "the setting did not survive a round trip")
	assert_true(settings.matches(restored))


## A settings file written before this setting existed must not silently turn
## the cap off for everybody who already had one.
func test_a_settings_file_from_before_this_existed_still_gets_the_cap() -> void:
	var old := GameSettings.new().to_dictionary()
	old.erase("render_scale_auto")
	assert_true(GameSettings.from_dictionary(old).render_scale_auto)


## Which surface the cap is computed against. Found by checking rather than by
## reasoning: setting the window to a fullscreen mode does not update its size in
## the same frame, so applying borderless fullscreen on the 6144x3456 display and
## immediately reading the window reported the old 3840x2160 -- and the cap was
## then computed for a resolution the game was no longer at.
func test_a_fullscreen_mode_is_measured_against_the_monitor_not_the_stale_window() -> void:
	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.BORDERLESS
	settings.resolution = Vector2i(1600, 900)
	assert_eq(
		SettingsApplier.output_size_for(settings, Vector2i(1600, 900), SIX_K),
		SIX_K,
		"the cap was computed against the window the game had just left"
	)


func test_exclusive_fullscreen_is_measured_the_same_way() -> void:
	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.FULLSCREEN
	assert_eq(SettingsApplier.output_size_for(settings, Vector2i(800, 600), FOUR_K), FOUR_K)


func test_windowed_is_measured_against_the_window_it_asked_for() -> void:
	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.WINDOWED
	settings.resolution = Vector2i(1280, 720)
	assert_eq(
		SettingsApplier.output_size_for(settings, Vector2i(1600, 900), SIX_K), Vector2i(1280, 720)
	)


## A monitor that reports nothing -- which happens on a headless run and on at
## least one Wayland compositor -- must not collapse the budget to zero and cap
## everything at half.
func test_a_screen_that_reports_nothing_falls_back_rather_than_capping_everything() -> void:
	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.FULLSCREEN
	assert_eq(
		SettingsApplier.output_size_for(settings, Vector2i(1920, 1080), Vector2i.ZERO),
		Vector2i(1920, 1080)
	)


func test_with_no_settings_at_all_it_believes_the_window() -> void:
	assert_eq(SettingsApplier.output_size_for(null, Vector2i(1920, 1080), SIX_K), Vector2i(1920, 1080))
	assert_eq(SettingsApplier.output_size_for(null, Vector2i.ZERO, SIX_K), SIX_K)
