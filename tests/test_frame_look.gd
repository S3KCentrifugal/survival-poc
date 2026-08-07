extends TestCase
## The measurable half of `ART.md`: the four ways a frame can be objectively
## wrong, as opposed to merely not to taste.


func _filled(width: int, height: int, colour: Color) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	image.fill(colour)
	return image


## A subject of [param subject_height] pixels drawn on a background, centred.
func _subject_on(background: Color, subject: Color, subject_height: int) -> Image:
	var image := _filled(200, 200, background)
	var half := subject_height / 2
	for y in range(100 - half, 100 + half):
		# A quarter as wide as it is tall, which is roughly a person.
		for x in range(100 - half / 4, 100 + half / 4):
			image.set_pixel(x, y, subject)
	return image


func test_nothing_at_all_measures_to_nothing() -> void:
	var look := FrameLook.measure(null)
	assert_eq(look.pixels, 0)
	assert_eq(look.mean_luminance, 0.0)
	assert_false(look.subject_measured)


func test_black_and_white_sit_at_the_ends_of_the_range() -> void:
	assert_eq(FrameLook.measure(_filled(16, 16, Color.BLACK)).mean_luminance, 0.0)
	assert_eq(FrameLook.measure(_filled(16, 16, Color.WHITE)).mean_luminance, 1.0)


## The night-readability measurement, which exists because `world-night`
## measured 100% dark and a mean luminance of 0.002 -- a frame nobody can play
## in, that no golden could ever have complained about.
func test_a_frame_of_night_reports_itself_as_unreadable() -> void:
	var look := FrameLook.measure(_filled(64, 64, Color(0.03, 0.03, 0.05)))
	assert_eq(look.dark_fraction, 1.0)
	assert_false(look.is_readable(0.5), "a frame that is entirely below the floor passed")


func test_a_daylit_frame_is_readable() -> void:
	var look := FrameLook.measure(_filled(64, 64, Color(0.4, 0.5, 0.3)))
	assert_eq(look.dark_fraction, 0.0)
	assert_true(look.is_readable(0.12))


func test_no_darkness_target_is_always_met() -> void:
	# Because two shots deliberately carry none: a ceiling set at what is
	# currently wrong is a ceiling that ratifies it.
	assert_true(FrameLook.measure(_filled(8, 8, Color.BLACK)).is_readable(0.0))


func test_a_blown_out_frame_says_so() -> void:
	assert_eq(FrameLook.measure(_filled(32, 32, Color.WHITE)).bright_fraction, 1.0)
	assert_eq(FrameLook.measure(_filled(32, 32, Color(0.5, 0.5, 0.5))).bright_fraction, 0.0)


## Greys have no hue worth counting, or every frame with a road in it reports a
## colour it is not using.
func test_a_grey_frame_is_built_from_no_hues_at_all() -> void:
	assert_eq(FrameLook.measure(_filled(32, 32, Color(0.5, 0.5, 0.5))).hue_count, 0)


func test_a_frame_of_one_colour_is_built_from_one_hue() -> void:
	var look := FrameLook.measure(_filled(32, 32, Color(0.2, 0.6, 0.25)))
	assert_eq(look.hue_count, 1)
	assert_eq(look.dominant_hue_share, 1.0)


## Cohesion is most of what the art direction asks for, and this is the
## countable part: a frame drawing on four hues reads as designed, one drawing
## on eleven reads as assembled from whatever was to hand.
func test_a_frame_scattered_across_the_wheel_is_incoherent() -> void:
	var image := Image.create_empty(120, 10, false, Image.FORMAT_RGB8)
	for x in 120:
		image.set_pixel(x, 0, Color.from_hsv(x / 120.0, 0.9, 0.9))
	for y in range(1, 10):
		for x in 120:
			image.set_pixel(x, y, image.get_pixel(x, 0))

	var look := FrameLook.measure(image)
	assert_true(look.hue_count >= 10, "a full colour wheel counted as %d hues" % look.hue_count)
	assert_false(look.is_coherent(6))


func test_a_deliberately_narrow_palette_is_coherent() -> void:
	var image := _filled(60, 20, Color(0.25, 0.55, 0.25))
	for y in 20:
		for x in range(30, 60):
			image.set_pixel(x, y, Color(0.35, 0.6, 0.22))  # A neighbouring green.
	assert_true(FrameLook.measure(image).is_coherent(3))


## A pixel too dark for its hue to be visible must not be counted as a hue, or a
## night frame reports a rich palette nobody can see.
func test_hues_nobody_can_see_are_not_counted() -> void:
	assert_eq(FrameLook.measure(_filled(32, 32, Color(0.0, 0.04, 0.0))).hue_count, 0)


func test_a_pale_subject_on_a_dark_background_stands_out() -> void:
	var look := FrameLook.measure(
		_subject_on(Color(0.1, 0.1, 0.1), Color(0.9, 0.9, 0.9), 80), Vector2i(100, 100), 80
	)
	assert_true(look.subject_measured)
	assert_true(look.subject_contrast > 8.0, "measured only %.1f:1" % look.subject_contrast)
	assert_true(look.subject_stands_out(3.0))


## The finding this measurement was built to make sayable: every shot in the
## project reports 1.0-1.3:1, because the blue character sits at almost exactly
## the luminance of the grass and the walls behind it. Colour alone does not
## build a silhouette.
func test_a_subject_matching_its_background_in_luminance_does_not() -> void:
	# Different hues, near-identical relative luminance.
	var look := FrameLook.measure(
		_subject_on(Color(0.42, 0.42, 0.42), Color(0.10, 0.52, 0.30), 80), Vector2i(100, 100), 80
	)
	assert_true(look.subject_contrast < 1.5, "measured %.1f:1" % look.subject_contrast)
	assert_false(look.subject_stands_out(3.0), "a character invisible in the grass passed")


## The first version used a fixed disc and measured mostly background for any
## character more than a few metres away -- reporting 1.0:1 for a player who is
## plainly visible in the frame.
func test_a_small_distant_subject_is_still_measured_on_the_subject() -> void:
	var look := FrameLook.measure(
		_subject_on(Color(0.05, 0.05, 0.05), Color.WHITE, 16), Vector2i(100, 100), 16
	)
	assert_true(
		look.subject_contrast > 8.0,
		"a small bright subject on black measured %.1f:1, so the disc sampled the background"
			% look.subject_contrast
	)


## The second version sized the disc correctly but put the background ring at
## three times its radius, which for a close-up is still inside the silhouette
## -- so it compared the character against itself and reported 1.0:1.
func test_a_subject_filling_the_frame_is_still_compared_against_the_background() -> void:
	var look := FrameLook.measure(
		_subject_on(Color(0.05, 0.05, 0.05), Color.WHITE, 160), Vector2i(100, 100), 160
	)
	assert_true(
		look.subject_contrast > 8.0,
		"a close-up measured %.1f:1, so the ring was still on the character"
			% look.subject_contrast
	)


func test_a_frame_with_no_subject_reports_none_rather_than_a_number() -> void:
	var look := FrameLook.measure(_filled(64, 64, Color(0.4, 0.4, 0.4)))
	assert_false(look.subject_measured)
	assert_eq(look.subject_contrast, 0.0)


## A landscape has nothing to separate from anything, so it must not fail a
## target it was never asked to meet.
func test_no_subject_target_is_always_met() -> void:
	assert_true(FrameLook.measure(_filled(8, 8, Color.RED)).subject_stands_out(0.0))


## But a shot that *asks* for the player and cannot find them has failed, rather
## than quietly passing for want of a measurement.
func test_a_missing_subject_fails_a_target_that_asked_for_one() -> void:
	assert_false(FrameLook.measure(_filled(8, 8, Color.RED)).subject_stands_out(3.0))


func test_a_subject_off_the_edge_of_the_frame_is_not_measured() -> void:
	var look := FrameLook.measure(_filled(64, 64, Color.RED), Vector2i(400, 400), 20)
	assert_false(look.subject_measured)


func test_the_range_a_frame_uses_is_reported() -> void:
	var image := _filled(100, 100, Color.BLACK)
	for y in range(50, 100):
		for x in 100:
			image.set_pixel(x, y, Color.WHITE)
	var look := FrameLook.measure(image)
	assert_true(look.low_luminance < 0.05, "p05 was %f" % look.low_luminance)
	assert_true(look.high_luminance > 0.9, "p95 was %f" % look.high_luminance)


func test_a_flat_frame_uses_none_of_the_range() -> void:
	var look := FrameLook.measure(_filled(64, 64, Color(0.5, 0.5, 0.5)))
	assert_true(absf(look.high_luminance - look.low_luminance) < 0.02)


func test_measuring_does_not_modify_the_frame() -> void:
	var frame := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	frame.fill(Color.RED)
	FrameLook.measure(frame)
	assert_eq(frame.get_format(), Image.FORMAT_RGBA8, "the measurement converted its input")


func test_it_reports_itself_in_words() -> void:
	var text := FrameLook.measure(_filled(32, 32, Color(0.2, 0.6, 0.25))).summary()
	assert_true(text.contains("dark"), text)
	assert_true(text.contains("hues"), text)
	assert_true(text.contains("no subject"), text)
