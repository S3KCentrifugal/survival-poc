extends TestCase
## Cutting openings out of walls.
##
## A doorway is a subtraction, and subtraction is where the off-by-one lives. A
## gap half a metre out is a door you cannot walk through or a wall with
## daylight under it, and neither is visible from thirty metres up.

const HEIGHT: float = 3.0
const THICKNESS: float = 0.3
const DOOR_HEIGHT: float = 2.2


func _wall(
	from: Vector2, to: Vector2, openings: Array[WallOpening] = [], base_y: float = 0.0
) -> Array[WallSegment]:
	return WallBuilder.segments(from, to, openings, HEIGHT, THICKNESS, base_y)


func _door(offset: float, width: float = 1.6) -> WallOpening:
	return WallOpening.new(offset, width, DOOR_HEIGHT)


## Total length of every full-height piece, which is the wall minus its holes.
func _solid_length(segments: Array[WallSegment]) -> float:
	var total := 0.0
	for segment: WallSegment in segments:
		if is_equal_approx(segment.size.y, HEIGHT):
			total += segment.size.x
	return total


func test_a_plain_wall_is_one_box() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0))
	assert_eq(segments.size(), 1)
	assert_true(is_equal_approx(segments[0].size.x, 10.0), "spans %f" % segments[0].size.x)
	assert_true(is_equal_approx(segments[0].size.y, HEIGHT))
	assert_true(is_equal_approx(segments[0].size.z, THICKNESS))


func test_a_wall_stands_on_the_floor_rather_than_in_it() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [], 4.0)
	assert_true(is_equal_approx(segments[0].bottom(), 4.0), "sits at %f" % segments[0].bottom())
	assert_true(is_equal_approx(segments[0].top(), 7.0))


func test_a_wall_runs_between_the_points_it_was_given() -> void:
	var segments := _wall(Vector2(2.0, 5.0), Vector2(12.0, 5.0))
	assert_true(is_equal_approx(segments[0].center.x, 7.0))
	assert_true(is_equal_approx(segments[0].center.z, 5.0))


## A wall along z is the same wall turned, not a different case.
func test_a_wall_along_z_is_turned_to_match() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(0.0, 10.0))
	assert_eq(segments.size(), 1)
	var along := segments[0].transform().basis.x
	assert_true(
		along.normalized().is_equal_approx(Vector3(0.0, 0.0, 1.0)),
		"the box runs along %v instead of +z" % along.normalized()
	)


func test_a_wall_along_x_is_not_turned() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0))
	var along := segments[0].transform().basis.x
	assert_true(
		along.normalized().is_equal_approx(Vector3(1.0, 0.0, 0.0)),
		"the box runs along %v instead of +x" % along.normalized()
	)


func test_a_doorway_splits_the_wall_and_leaves_a_lintel() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(4.2)])
	assert_eq(segments.size(), 3, "expected two piers and a lintel, got %d" % segments.size())
	assert_true(
		is_equal_approx(_solid_length(segments), 8.4),
		"solid wall totals %f, should be 10 minus the 1.6 door" % _solid_length(segments)
	)


func test_the_lintel_sits_above_the_opening() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(4.2)])
	for segment: WallSegment in segments:
		if is_equal_approx(segment.size.y, HEIGHT):
			continue
		assert_true(is_equal_approx(segment.bottom(), DOOR_HEIGHT), "lintel starts at %f" % segment.bottom())
		assert_true(is_equal_approx(segment.top(), HEIGHT))
		assert_true(is_equal_approx(segment.size.x, 1.6))
		return
	fail("no lintel was built")


## The point of the whole exercise: the doorway has to be empty at head height.
func test_nothing_solid_stands_in_the_doorway() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(4.2)])
	for segment: WallSegment in segments:
		# The lintel is allowed up there. Its underside lands on 2.1999999
		# rather than 2.2, so this cannot be an exact comparison.
		if segment.bottom() >= DOOR_HEIGHT - 0.001:
			continue
		var near := segment.center.x - segment.size.x * 0.5
		var far := segment.center.x + segment.size.x * 0.5
		assert_true(
			far <= 4.2001 or near >= 5.7999,
			"a box below head height spans %f..%f, inside the 4.2..5.8 doorway" % [near, far]
		)


func test_a_walkable_doorway_is_left_clear_to_the_floor() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(4.2)])
	var midpoint := 5.0
	for segment: WallSegment in segments:
		var near := segment.center.x - segment.size.x * 0.5
		var far := segment.center.x + segment.size.x * 0.5
		if midpoint <= near or midpoint >= far:
			continue
		assert_true(
			segment.bottom() >= DOOR_HEIGHT - 0.001,
			"something solid blocks the doorway from %f up" % segment.bottom()
		)


func test_two_doorways_leave_three_piers() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(20.0, 0.0), [_door(4.0), _door(12.0)])
	var piers := 0
	for segment: WallSegment in segments:
		if is_equal_approx(segment.size.y, HEIGHT):
			piers += 1
	assert_eq(piers, 3, "got %d piers" % piers)
	assert_true(is_equal_approx(_solid_length(segments), 16.8))


## Openings given out of order must not produce overlapping or negative spans.
func test_doorways_are_ordered_before_they_are_cut() -> void:
	var jumbled := _wall(Vector2.ZERO, Vector2(20.0, 0.0), [_door(12.0), _door(4.0)])
	var ordered := _wall(Vector2.ZERO, Vector2(20.0, 0.0), [_door(4.0), _door(12.0)])
	assert_eq(jumbled.size(), ordered.size())
	assert_true(is_equal_approx(_solid_length(jumbled), _solid_length(ordered)))


## A doorway flush with the end would otherwise produce a box of no width:
## invisible, collides with nothing, and counted forever after.
func test_a_doorway_at_the_end_leaves_no_sliver() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(8.4)])
	for segment: WallSegment in segments:
		assert_true(segment.size.x > 0.001, "built a zero-width box: %s" % segment)


func test_a_doorway_running_off_the_end_is_clipped() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(9.0, 4.0)])
	assert_true(
		is_equal_approx(_solid_length(segments), 9.0),
		"solid wall totals %f, should be the 9 m before the opening" % _solid_length(segments)
	)


func test_an_opening_wider_than_the_wall_leaves_nothing_standing() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(4.0, 0.0), [_door(-1.0, 10.0)])
	assert_true(is_zero_approx(_solid_length(segments)), "something survived a total demolition")


func test_an_opening_past_the_end_does_not_cut_the_wall() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(20.0)])
	assert_eq(segments.size(), 1)
	assert_true(is_equal_approx(_solid_length(segments), 10.0))


func test_a_full_height_opening_has_no_lintel() -> void:
	var gap := WallOpening.new(4.0, 2.0, HEIGHT)
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [gap])
	assert_eq(segments.size(), 2, "a gap to the roof should leave only the two piers")


func test_a_zero_width_opening_is_ignored() -> void:
	var segments := _wall(Vector2.ZERO, Vector2(10.0, 0.0), [_door(4.0, 0.0)])
	assert_eq(segments.size(), 1)


func test_a_wall_of_no_length_builds_nothing() -> void:
	assert_true(_wall(Vector2(3.0, 3.0), Vector2(3.0, 3.0)).is_empty())
