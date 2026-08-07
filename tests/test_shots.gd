extends TestCase
## The named shots, and the part of taking one that does not need a renderer.
##
## Nothing here captures a frame -- `--headless` has no rendering device, so the
## suite cannot and this is not a gap that can be closed. What it can do is
## assert that every committed shot is a sane thing to ask for, and that the
## world is properly frozen before one is taken. Both are where a screenshot
## harness actually goes wrong: a shot with a bad camera does not error, it
## writes a black PNG, which is then blessed as a golden and asserted against
## forever.


func _shot() -> ShotConfig:
	var shot := ShotConfig.new()
	shot.shot_name = &"probe"
	shot.camera_position = Vector3(5.0, 5.0, 5.0)
	shot.camera_target = Vector3.ZERO
	return shot


func test_there_are_shots_at_all() -> void:
	# A directory that quietly emptied would otherwise make every check below
	# pass by having nothing to check.
	assert_true(ShotConfig.all().size() >= 5, "only %d shots are defined" % ShotConfig.all().size())


func test_every_committed_shot_is_a_sane_thing_to_ask_for() -> void:
	for shot: ShotConfig in ShotConfig.all():
		var problems := shot.problems()
		assert_true(problems.is_empty(), "%s: %s" % [shot.shot_name, ", ".join(problems)])


func test_no_two_shots_share_a_name() -> void:
	# They would share a golden, so one would overwrite the other's and the pair
	# would fail alternately forever.
	var seen: Array[StringName] = []
	for shot: ShotConfig in ShotConfig.all():
		assert_false(seen.has(shot.shot_name), "%s is defined twice" % shot.shot_name)
		seen.append(shot.shot_name)


## Sorted through [String] rather than by [StringName], because comparing
## StringNames sorts by interned pointer -- allocation order, which changes the
## moment an unrelated file interns a new name. A tool whose output order moves
## between runs makes every diff of its output unreadable.
func test_the_order_is_alphabetical_and_not_allocation_order() -> void:
	var names: Array[String] = []
	for shot: ShotConfig in ShotConfig.all():
		names.append(String(shot.shot_name))
	var sorted := names.duplicate()
	sorted.sort()
	assert_eq(names, sorted, "the shots came back in %s" % str(names))


func test_a_shot_can_be_found_by_name() -> void:
	assert_not_null(ShotConfig.named(&"world-noon"), "world-noon is missing")
	assert_null(ShotConfig.named(&"no-such-shot"))


func test_goldens_live_with_the_tests_because_they_are_expected_values() -> void:
	var shot := _shot()
	assert_eq(shot.golden_path(), "res://tests/golden/probe.png")


func test_a_shot_with_no_name_has_nowhere_to_put_its_golden() -> void:
	var shot := _shot()
	shot.shot_name = &"  "
	assert_false(shot.problems().is_empty())


## Produces a black frame rather than an error, which is exactly the failure
## this validation exists to catch.
func test_a_camera_standing_on_its_own_target_is_refused() -> void:
	var shot := _shot()
	shot.camera_target = shot.camera_position
	assert_false(shot.problems().is_empty(), "look_at had no direction and nothing objected")


func test_a_shot_that_captures_before_the_world_is_built_is_refused() -> void:
	var shot := _shot()
	shot.settle_frames = 0
	assert_false(shot.problems().is_empty())


func test_a_golden_larger_than_the_frame_it_reduces_is_refused() -> void:
	var shot := _shot()
	shot.golden_height = shot.resolution.y * 2
	assert_false(shot.problems().is_empty())


## No renderer gives pixel-exact equality twice, so a zero tolerance is a test
## that fails on the first driver update and gets deleted.
func test_a_zero_tolerance_is_refused() -> void:
	var shot := _shot()
	shot.mean_tolerance = 0.0
	assert_false(shot.problems().is_empty())


func test_a_shot_defaults_to_a_frozen_clock_rather_than_the_current_time() -> void:
	# Not "whenever". A shot taken at an arbitrary time of day is lit a
	# different colour every run and can never be compared with itself.
	assert_true(_shot().time_of_day >= 0.0 and _shot().time_of_day <= 1.0)
	assert_true(_shot().rng_seed != 0, "an unseeded shot scatters its mushrooms afresh")


## Physics frames, never idle frames. Headless and unfocused runs produce idle
## frames at whatever rate they like while physics stays at 60 Hz, so a settle
## counted in `_process` calls times nothing at all.
func test_settling_is_counted_in_something_that_is_actually_a_clock() -> void:
	assert_true(_shot().settle_frames >= 1)
	for shot: ShotConfig in ShotConfig.all():
		assert_true(shot.settle_frames >= 10, "%s barely settles" % shot.shot_name)


func test_freezing_a_world_stops_its_clock_at_the_shot_time() -> void:
	var shot := _shot()
	shot.time_of_day = 0.8
	var world: Node = mount(load(ShotRunner.WORLD_SCENE).instantiate())

	ShotRunner.freeze(world, shot)

	var clock: DayNightComponent = world.get_node("DayNight")
	assert_eq(clock.time_of_day(), 0.8, "the shot's time of day did not take")
	assert_false(clock.is_processing(), "the sun is still moving during the shot")


## Setting the clock is not enough: the sun has to be pointed at the new time as
## well. A freeze that moved the number and left the light where it was would
## produce a shot whose sky and whose shadows disagree -- and it would look like
## a lighting bug rather than a harness one.
func test_freezing_relights_the_world_rather_than_only_moving_the_number() -> void:
	var world: Node = mount(load(ShotRunner.WORLD_SCENE).instantiate())
	var sun: DirectionalLight3D = world.get_node("Sun")

	var noon := _shot()
	noon.time_of_day = 0.5
	ShotRunner.freeze(world, noon)
	var at_noon := sun.global_transform.basis.z

	var dusk := _shot()
	dusk.time_of_day = 0.78
	ShotRunner.freeze(world, dusk)

	assert_true(
		sun.global_transform.basis.z.distance_to(at_noon) > 0.2,
		"the sun did not move between midday and sunset"
	)


func test_freezing_gives_the_cursor_back_and_stops_reading_the_keyboard() -> void:
	# A tool that steals the mouse and then exits leaves the desktop without
	# one, and a stray keypress during a capture opened the pause menu over two
	# screenshots before this existed.
	var world: WorldRoot = mount(load(ShotRunner.WORLD_SCENE).instantiate())
	ShotRunner.freeze(world, _shot())
	assert_true(world.is_input_suspended(), "the shot is still listening for gameplay input")


func test_a_world_shot_hides_the_interface() -> void:
	var shot := _shot()
	shot.show_interface = false
	var world: Node = mount(load(ShotRunner.WORLD_SCENE).instantiate())

	ShotRunner.freeze(world, shot)

	var hud: CanvasLayer = world.get_node("PlayerHud")
	assert_false(hud.visible, "the HUD is in a shot about the world")


func test_an_interface_shot_keeps_it() -> void:
	var shot := _shot()
	shot.show_interface = true
	var world: Node = mount(load(ShotRunner.WORLD_SCENE).instantiate())

	ShotRunner.freeze(world, shot)

	assert_true((world.get_node("PlayerHud") as CanvasLayer).visible)


## At least one shot has to carry the interface, or a UI change is invisible to
## every golden and the regression net has a hole exactly where UI.md's rules
## are.
func test_something_is_watching_the_interface() -> void:
	var found := false
	for shot: ShotConfig in ShotConfig.all():
		found = found or shot.show_interface
	assert_true(found, "every shot hides the interface, so no golden can catch a UI change")


## And most of them must not, or every lighting comparison also contains a
## health bar's worth of pixels that change for unrelated reasons.
func test_most_shots_are_about_the_world_rather_than_the_interface() -> void:
	var world_shots := 0
	for shot: ShotConfig in ShotConfig.all():
		world_shots += 0 if shot.show_interface else 1
	assert_true(world_shots * 2 > ShotConfig.all().size(), "most shots have the HUD in them")


func _result(shot: ShotConfig, draws: float, prims: float, shadow_draws: float,
		shadow_prims: float) -> ShotResult:
	var result := ShotResult.new()
	result.shot = shot
	for _index in 3:
		result.draw_calls.add(draws)
		result.primitives.add(prims)
		result.shadow_draw_calls.add(shadow_draws)
		result.shadow_primitives.add(shadow_prims)
	return result


## A shot with no budget is a shot that can never fail for getting heavier, and
## the golden will not catch geometry that changes the picture only slightly.
func test_every_committed_shot_carries_a_budget() -> void:
	for shot: ShotConfig in ShotConfig.all():
		assert_true(shot.draw_call_budget > 0, "%s has no draw call budget" % shot.shot_name)
		assert_true(shot.primitive_budget > 0, "%s has no primitive budget" % shot.shot_name)
		assert_true(
			shot.shadow_draw_call_budget > 0, "%s does not budget the sun" % shot.shot_name
		)
		assert_true(shot.shadow_primitive_budget > 0, "%s does not budget the sun" % shot.shot_name)


## The measurement that made the shadow budget non-optional: `terrain-detail`
## draws 6 things and the sun draws 91 of them. A shot whose shadow budget was
## a rounding of its visible one would be off by a factor of fifteen.
func test_the_shadow_budget_is_not_a_copy_of_the_visible_one() -> void:
	for shot: ShotConfig in ShotConfig.all():
		assert_true(
			shot.shadow_draw_call_budget > shot.draw_call_budget,
			"%s budgets the sun at or below the camera, which no shot measured" % shot.shot_name
		)


func test_a_frame_inside_its_budget_passes() -> void:
	var result := _result(ShotConfig.named(&"world-noon"), 88, 207_000, 155, 665_000)
	assert_true(result.within_budget(), result.over_budget_reason())
	assert_eq(result.over_budget_reason(), "")


func test_too_many_draw_calls_is_caught() -> void:
	var result := _result(ShotConfig.named(&"world-noon"), 900, 207_000, 155, 665_000)
	assert_false(result.within_budget())
	assert_true(result.over_budget_reason().contains("draw calls"), result.over_budget_reason())


## The half a visible-only budget would have missed entirely.
func test_a_shadow_pass_that_quadruples_is_caught() -> void:
	var result := _result(ShotConfig.named(&"world-noon"), 88, 207_000, 155, 4_000_000)
	assert_false(result.within_budget(), "the sun's work quadrupled and nothing objected")
	assert_true(
		result.over_budget_reason().contains("shadow primitives"), result.over_budget_reason()
	)


## One change often pushes several counts over at once, and reporting only the
## first turns one investigation into three.
func test_every_breach_is_listed_rather_than_the_first() -> void:
	var result := _result(ShotConfig.named(&"world-noon"), 900, 9_000_000, 900, 9_000_000)
	var reason := result.over_budget_reason()
	for expected: String in ["draw calls", "primitives", "shadow draw calls", "shadow primitives"]:
		assert_true(reason.contains(expected), "%s is missing from '%s'" % [expected, reason])


func test_an_unbudgeted_shot_passes_whatever_it_costs() -> void:
	var result := _result(_shot(), 9_000, 9_000_000, 9_000, 9_000_000)
	assert_true(result.within_budget(), "a shot with no budget failed one")


func test_a_result_with_no_shot_at_all_does_not_crash_looking_for_a_budget() -> void:
	assert_true(ShotResult.new().within_budget())
	assert_eq(ShotResult.new().over_budget_reason(), "")


## The debug overlay draws a live frame counter. A shot containing it has a
## number in the corner that differs on every run, so the golden fails for a
## reason that has nothing to do with the picture -- and the fix is not a looser
## tolerance, it is not photographing the developer tools.
func test_developer_tools_are_hidden_even_in_an_interface_shot() -> void:
	var shot := _shot()
	shot.show_interface = true
	var world: Node = mount(load(ShotRunner.WORLD_SCENE).instantiate())

	ShotRunner.freeze(world, shot)

	for name: StringName in ShotRunner.DEVELOPER_LAYERS:
		var layer := world.get_node_or_null(NodePath(name)) as CanvasLayer
		assert_not_null(layer, "%s is not in the world any more" % name)
		assert_false(layer.visible, "%s is in the shot" % name)


## Absolute camera coordinates cannot frame something the terrain places. Three
## shots written that way put the camera underground, looking up through
## back-faced terrain at the sky, and were blessed as goldens -- a picture of the
## sky is not black, so nothing in problems() could tell.
func test_an_anchored_shot_is_placed_relative_to_where_the_player_ended_up() -> void:
	var shot := _shot()
	shot.anchor_to_player = true
	shot.camera_position = Vector3(2.0, 1.5, 2.0)
	shot.camera_target = Vector3(0.0, 1.0, 0.0)

	var stood := Vector3(-3.0, 41.7, 0.0)  # On a heightfield, not on the ground plane.
	assert_eq(shot.camera_at(stood), Vector3(-1.0, 43.2, 2.0))
	assert_eq(shot.target_at(stood), Vector3(-3.0, 42.7, 0.0))


func test_an_unanchored_shot_means_exactly_what_it_says() -> void:
	var shot := _shot()
	shot.camera_position = Vector3(26.0, 14.0, 26.0)
	shot.camera_target = Vector3(0.0, 2.0, 0.0)
	assert_eq(shot.camera_at(Vector3(-3.0, 41.7, 0.0)), Vector3(26.0, 14.0, 26.0))
	assert_eq(shot.target_at(Vector3(-3.0, 41.7, 0.0)), Vector3(0.0, 2.0, 0.0))


## Every shot that is about the player has to be anchored, or it is one terrain
## change away from photographing the sky again.
func test_every_shot_that_must_show_the_player_is_anchored_to_them() -> void:
	for shot: ShotConfig in ShotConfig.all():
		if shot.must_show_player:
			assert_true(
				shot.anchor_to_player,
				"%s demands the player in frame from a fixed world position" % shot.shot_name
			)


func test_something_is_watching_the_character() -> void:
	var found := false
	for shot: ShotConfig in ShotConfig.all():
		found = found or shot.must_show_player
	assert_true(found, "no shot asserts the player is even in it")


func _looked(shot: ShotConfig, dark: float, hues: int, contrast: float) -> ShotResult:
	var result := ShotResult.new()
	result.shot = shot
	result.look.dark_fraction = dark
	result.look.hue_count = hues
	result.look.subject_contrast = contrast
	result.look.subject_measured = contrast > 0.0
	return result


## Every shot reports the art-direction figures; only some enforce them, and the
## ones that do have to be shots the current build already satisfies -- a target
## set at what is currently wrong is a target that ratifies it.
func test_every_shot_bounds_how_many_hues_it_may_be_built_from() -> void:
	for shot: ShotConfig in ShotConfig.all():
		assert_true(shot.max_hue_count > 0, "%s does not bound its palette" % shot.shot_name)


## The two exceptions, named rather than left to be noticed: they are 71% and
## 100% below the readable floor today, which is the gap ART.md exists to state.
func test_the_shots_that_do_not_bound_darkness_are_the_night_ones() -> void:
	var unbounded: Array[String] = []
	for shot: ShotConfig in ShotConfig.all():
		if shot.max_dark_fraction <= 0.0:
			unbounded.append(String(shot.shot_name))
	unbounded.sort()
	assert_eq(unbounded, ["world-dusk", "world-night"] as Array[String],
		"a daylit shot stopped bounding how dark it may get: %s" % str(unbounded))


func test_a_frame_within_every_target_passes() -> void:
	assert_eq(_looked(ShotConfig.named(&"world-noon"), 0.01, 5, 0.0).look_problems(), "")


func test_a_frame_crushed_to_black_is_caught() -> void:
	var reason := _looked(ShotConfig.named(&"world-noon"), 0.6, 5, 0.0).look_problems()
	assert_true(reason.contains("too dark"), reason)


func test_a_frame_scattered_across_the_colour_wheel_is_caught() -> void:
	var reason := _looked(ShotConfig.named(&"world-noon"), 0.01, 11, 0.0).look_problems()
	assert_true(reason.contains("hues"), reason)


## No shot sets this target yet -- every one of them measures 1.0-1.3:1 today,
## and ART.md records 3:1 as what Phase 1 has to reach. The check has to work
## before then, or it lands untested on the day it matters.
func test_a_character_nobody_can_pick_out_of_the_grass_is_caught() -> void:
	var shot := _shot()
	shot.must_show_player = true
	shot.min_subject_contrast = 3.0
	var reason := _looked(shot, 0.0, 2, 1.2).look_problems()
	assert_true(reason.contains("stands out"), reason)
	assert_eq(_looked(shot, 0.0, 2, 4.5).look_problems(), "")


## Asking how far the player stands out without asking for them to be in frame
## is a target that can only ever pass by accident.
func test_a_subject_target_without_a_subject_is_refused() -> void:
	var shot := _shot()
	shot.min_subject_contrast = 3.0
	shot.must_show_player = false
	assert_false(shot.problems().is_empty())
