extends TestCase
## The value structure: which brightness band a surface belongs to, and whether
## the bands are far enough apart to make a silhouette.


func test_the_bands_climb_from_the_ground_to_the_actors() -> void:
	assert_true(
		SurfacePalette.value_of(SurfacePalette.Band.GROUND)
			< SurfacePalette.value_of(SurfacePalette.Band.STRUCTURE),
		"the ground is not the floor of the value structure"
	)
	assert_true(
		SurfacePalette.value_of(SurfacePalette.Band.STRUCTURE)
			< SurfacePalette.value_of(SurfacePalette.Band.CHARACTER)
	)


## `ART.md` rule 3, asserted against the tokens themselves rather than against a
## rendered frame. A palette change that quietly closes the gap fails here, in
## the headless suite, rather than in a screenshot somebody happens to look at.
func test_a_character_is_at_least_three_to_one_against_the_ground() -> void:
	var ratio := SurfacePalette.contrast_between(
		SurfacePalette.Band.CHARACTER, SurfacePalette.Band.GROUND
	)
	assert_true(ratio >= 3.0, "the value structure only separates %.1f:1" % ratio)


## Aimed well past 3:1 on purpose. Tonemapping compresses a contrast on its way
## to the screen, so a structure built to exactly the minimum arrives under it --
## which is what the rendered figure being 2.5:1 against a 6.8:1 palette shows.
func test_the_structure_aims_past_the_target_because_the_screen_takes_a_cut() -> void:
	assert_true(
		SurfacePalette.contrast_between(
			SurfacePalette.Band.CHARACTER, SurfacePalette.Band.GROUND
		) >= 5.0
	)


func test_nothing_is_pulled_all_the_way_into_its_band() -> void:
	# At full strength every surface in a band renders at one brightness, which
	# flattens a character into a paper cut-out and throws away the shading that
	# says what shape it is.
	for band: int in [
		SurfacePalette.Band.GROUND,
		SurfacePalette.Band.STRUCTURE,
		SurfacePalette.Band.PROP,
		SurfacePalette.Band.CHARACTER,
	]:
		var strength := SurfacePalette.strength_of(band as SurfacePalette.Band)
		assert_true(strength > 0.0 and strength < 1.0, "band %d pulls at %f" % [band, strength])


func test_pulling_a_colour_into_a_band_lands_on_the_band() -> void:
	var moved := SurfacePalette.to_band(Color(0.2, 0.5, 0.3), 0.25, 1.0)
	assert_true(
		absf(UiTokens.luminance(moved) - 0.25) < 0.01,
		"asked for 0.25, got %f" % UiTokens.luminance(moved)
	)


## Scaled rather than mixed toward a grey of that brightness. Mixing would
## desaturate as it moved, so a green field pulled down would come out sludge
## rather than dark green -- fixing rule 3 by breaking rule 1.
func test_pulling_a_colour_into_a_band_keeps_its_hue() -> void:
	var vivid := Color(0.15, 0.55, 0.2)
	var moved := SurfacePalette.to_band(vivid, 0.04, 1.0)
	assert_true(absf(moved.h - vivid.h) < 0.02, "the hue moved from %f to %f" % [vivid.h, moved.h])
	assert_true(moved.s > vivid.s * 0.8, "it desaturated from %f to %f" % [vivid.s, moved.s])


func test_a_strength_of_zero_leaves_a_colour_alone() -> void:
	var original := Color(0.3, 0.4, 0.5)
	assert_eq(SurfacePalette.to_band(original, 0.9, 0.0), original)


func test_it_cannot_produce_a_colour_outside_the_range() -> void:
	var blown := SurfacePalette.to_band(Color(0.9, 0.9, 0.9), 1.0, 1.0)
	for channel: float in [blown.r, blown.g, blown.b]:
		assert_true(channel <= 1.0 and channel >= 0.0, "channel came out at %f" % channel)


func test_black_does_not_divide_by_zero() -> void:
	var moved := SurfacePalette.to_band(Color.BLACK, 0.5, 1.0)
	assert_true(is_finite(moved.r) and is_finite(moved.g) and is_finite(moved.b))


func test_alpha_survives() -> void:
	assert_eq(SurfacePalette.to_band(Color(0.5, 0.5, 0.5, 0.25), 0.1, 1.0).a, 0.25)
