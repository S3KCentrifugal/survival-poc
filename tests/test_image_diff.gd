extends TestCase
## Comparing two frames: what counts as the same picture, and what does not.
##
## The measurement under golden-image regression. It runs headless because
## [Image] is CPU-side -- nothing here needs a renderer, which is the whole
## reason the comparison was worth separating from the tool that captures.


func _filled(width: int, height: int, colour: Color) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	image.fill(colour)
	return image


## A frame with structure in it, so a test is not just comparing flat colours --
## a downscale or a resize bug is invisible on a solid fill.
func _striped(width: int, height: int) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	for y in height:
		for x in width:
			image.set_pixel(x, y, Color.WHITE if (x + y) % 2 == 0 else Color.BLACK)
	return image


func test_a_frame_is_identical_to_itself() -> void:
	var frame := _striped(32, 32)
	var diff := ImageDiff.compare(frame, frame)
	assert_true(diff.comparable)
	assert_eq(diff.mean_difference, 0.0)
	assert_eq(diff.changed_fraction, 0.0)
	assert_true(diff.within())


func test_black_against_white_is_the_largest_difference_there_is() -> void:
	var diff := ImageDiff.compare(_filled(8, 8, Color.BLACK), _filled(8, 8, Color.WHITE))
	assert_eq(diff.mean_difference, 1.0)
	assert_eq(diff.changed_fraction, 1.0)
	assert_false(diff.within())


## Two runs of the same scene differ slightly, and a driver update moves every
## pixel a little. A test that fails on that gets disabled within a week, which
## is worse than no test.
func test_renderer_noise_is_not_a_regression() -> void:
	var before := _filled(16, 16, Color(0.5, 0.5, 0.5))
	var after := _filled(16, 16, Color(0.504, 0.5, 0.496))
	assert_true(ImageDiff.compare(before, after).within(), "a one-step wobble failed the check")


## The case the mean cannot see: a new object in one corner moves very few
## pixels, by a lot.
func test_a_small_violent_change_is_caught_even_though_the_mean_is_tiny() -> void:
	var before := _filled(100, 100, Color.BLACK)
	var after := _filled(100, 100, Color.BLACK)
	for y in 20:
		for x in 20:
			after.set_pixel(x, y, Color.WHITE)

	var diff := ImageDiff.compare(before, after)
	assert_true(diff.mean_difference < 0.05, "the mean was %f, so it was not subtle" % diff.mean_difference)
	assert_eq(diff.changed_fraction, 0.04)
	assert_false(diff.within(), "a fifth of the frame turned white and it passed")


## And the opposite case, which the changed fraction cannot see: a colour grade
## moves every pixel a little and nothing by much.
func test_a_large_subtle_change_is_caught_even_though_no_pixel_moved_far() -> void:
	var before := _filled(64, 64, Color(0.4, 0.4, 0.4))
	var after := _filled(64, 64, Color(0.44, 0.44, 0.44))
	var diff := ImageDiff.compare(before, after)
	assert_true(diff.max_difference < 0.05, "one pixel moved a long way after all")
	assert_false(diff.within(), "a whole-frame grade passed as unchanged")


func test_a_frame_of_the_wrong_size_is_a_failure_rather_than_a_difference() -> void:
	# A golden is stored at a fixed size, so a capture at another one means the
	# harness changed rather than the picture.
	var diff := ImageDiff.compare(_filled(8, 8, Color.RED), _filled(16, 16, Color.RED))
	assert_false(diff.size_matches)
	assert_false(diff.within())


func test_nothing_at_all_is_not_quietly_a_match() -> void:
	assert_false(ImageDiff.compare(null, _filled(4, 4, Color.RED)).within())
	assert_false(ImageDiff.compare(_filled(4, 4, Color.RED), null).within())


## A golden saved as PNG and a capture taken with an alpha channel must be
## compared on equal terms, not differ everywhere in a channel neither uses.
func test_the_alpha_channel_is_not_a_difference() -> void:
	var opaque := _filled(8, 8, Color(0.3, 0.6, 0.9))
	var with_alpha := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	with_alpha.fill(Color(0.3, 0.6, 0.9, 1.0))
	assert_true(ImageDiff.compare(opaque, with_alpha).within(), "the formats compared as different")


## The comparison must not edit what it is given: a golden very often comes
## straight out of the resource cache, and converting it in place converts
## everybody's copy.
func test_comparing_does_not_modify_either_image() -> void:
	var frame := Image.create_empty(4, 4, false, Image.FORMAT_RGBA8)
	frame.fill(Color.RED)
	ImageDiff.compare(frame, frame)
	assert_eq(frame.get_format(), Image.FORMAT_RGBA8, "the comparison converted its input")


func test_goldens_are_stored_smaller_than_the_frame_they_came_from() -> void:
	var golden := ImageDiff.to_golden(_striped(1280, 720), 270)
	assert_eq(golden.get_height(), 270)
	assert_eq(golden.get_width(), 480, "the aspect ratio was not preserved")


## Bilinear downscaling throws away most of the pixels it is handed, so two
## frames differing in fine detail can resize to the same image and pass a test
## they should fail. This asserts the reduction still carries a difference.
func test_a_difference_survives_being_reduced_to_golden_size() -> void:
	var before := _striped(640, 360)
	var after := _striped(640, 360)
	for y in 360:
		for x in 320:
			after.set_pixel(x, y, Color(0.2, 0.7, 0.3))

	var diff := ImageDiff.compare(
		ImageDiff.to_golden(before, 90), ImageDiff.to_golden(after, 90)
	)
	assert_false(diff.within(), "half the frame changed and the reduction hid it")


func test_a_difference_image_is_written_where_the_frames_differ() -> void:
	var before := _filled(8, 8, Color.BLACK)
	var after := _filled(8, 8, Color.BLACK)
	after.set_pixel(3, 3, Color.WHITE)

	var picture := ImageDiff.difference_image(before, after)
	assert_not_null(picture)
	assert_true(picture.get_pixel(3, 3).r > 0.9, "the changed pixel is not lit up")
	assert_eq(picture.get_pixel(0, 0).r, 0.0, "an unchanged pixel is lit up")


func test_a_difference_image_of_mismatched_frames_is_nothing_rather_than_a_crash() -> void:
	assert_null(ImageDiff.difference_image(_filled(4, 4, Color.RED), _filled(8, 8, Color.RED)))


func test_it_reports_itself_in_words() -> void:
	var diff := ImageDiff.compare(_filled(4, 4, Color.BLACK), _filled(4, 4, Color.WHITE))
	assert_true(diff.summary().contains("mean"), diff.summary())
	assert_eq(ImageDiff.compare(_filled(4, 4, Color.RED), _filled(8, 8, Color.RED)).summary(),
		"different sizes")
