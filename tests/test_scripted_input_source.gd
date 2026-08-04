extends TestCase
## The source enemies and tests drive directly.

var source: ScriptedInputSource


func before_each() -> void:
	source = ScriptedInputSource.new()


func test_it_starts_neutral() -> void:
	var state := source.poll()
	assert_false(state.is_moving())
	assert_false(state.sprint)
	assert_false(state.has_aim)


func test_it_is_an_input_source() -> void:
	# Movement will accept the base type, so this has to substitute for it.
	assert_true(source is InputSource)


func test_directions_are_normalised() -> void:
	source.move_towards_direction(Vector2(3.0, 4.0))
	assert_true(is_equal_approx(source.poll().move.length(), 1.0))


func test_a_zero_direction_stays_still() -> void:
	# Normalising a zero vector is undefined; it must not produce NaN.
	source.move_towards_direction(Vector2.ZERO)
	var move := source.poll().move
	assert_eq(move, Vector2.ZERO)
	assert_false(is_nan(move.x))
	assert_false(is_nan(move.y))


func test_moving_between_two_points_heads_the_right_way() -> void:
	source.move_between(Vector3(10.0, 0.0, 10.0), Vector3(20.0, 5.0, 10.0))
	var move := source.poll().move
	assert_true(is_equal_approx(move.x, 1.0), "should walk toward +x")
	assert_true(is_zero_approx(move.y), "height difference must not steer it")


func test_stop_clears_movement_but_not_aim() -> void:
	source.move_towards_direction(Vector2.RIGHT)
	source.aim_at(Vector3(4.0, 0.0, 4.0))
	source.stop()

	var state := source.poll()
	assert_false(state.is_moving())
	assert_true(state.has_aim, "stopping is not the same as looking away")


func test_aim_can_be_set_and_cleared() -> void:
	source.aim_at(Vector3(1.0, 0.0, 2.0))
	assert_true(source.poll().has_aim)
	assert_eq(source.poll().aim_point, Vector3(1.0, 0.0, 2.0))

	source.clear_aim()
	assert_false(source.poll().has_aim)


func test_sprint_toggles() -> void:
	source.sprint(true)
	assert_true(source.poll().sprint)
	source.sprint(false)
	assert_false(source.poll().sprint)
