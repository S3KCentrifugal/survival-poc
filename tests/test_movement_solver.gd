extends TestCase
## Walking maths: velocity, gravity and turning.

const SPEED: float = 4.5
const ACCEL: float = 30.0
const DECEL: float = 45.0
const STEP: float = 1.0 / 60.0


func _walk(current: Vector2, desired: Vector2, delta: float = STEP) -> Vector2:
	return MovementSolver.horizontal_velocity(current, desired, SPEED, ACCEL, DECEL, delta)


func test_a_standing_actor_starts_moving() -> void:
	var velocity := _walk(Vector2.ZERO, Vector2.RIGHT)
	assert_true(velocity.x > 0.0)
	assert_true(velocity.x < SPEED, "should accelerate, not teleport to full speed")


func test_it_accelerates_up_to_walk_speed_and_stops_there() -> void:
	var velocity := Vector2.ZERO
	for _frame in 300:
		velocity = _walk(velocity, Vector2.RIGHT)
	assert_true(
		is_equal_approx(velocity.length(), SPEED),
		"settled at %f instead of %f" % [velocity.length(), SPEED]
	)


func test_releasing_the_keys_brings_it_to_a_halt() -> void:
	var velocity := Vector2(SPEED, 0.0)
	for _frame in 300:
		velocity = _walk(velocity, Vector2.ZERO)
	assert_true(velocity.is_zero_approx(), "still drifting at %v" % velocity)


func test_stopping_is_quicker_than_starting() -> void:
	# Deceleration is higher than acceleration, which is most of what makes
	# movement feel deliberate rather than slippery.
	var starting := _walk(Vector2.ZERO, Vector2.RIGHT).length()
	var stopping := SPEED - _walk(Vector2(SPEED, 0.0), Vector2.ZERO).length()
	assert_true(stopping > starting, "start %f, stop %f" % [starting, stopping])


func test_a_partial_direction_walks_slower() -> void:
	# A half-pressed stick should stroll, not sprint.
	var velocity := Vector2.ZERO
	for _frame in 300:
		velocity = _walk(velocity, Vector2.RIGHT * 0.5)
	assert_true(is_equal_approx(velocity.length(), SPEED * 0.5))


func test_acceleration_is_frame_rate_independent() -> void:
	# The same real time must produce the same speed, however it is sliced.
	var coarse := _walk(Vector2.ZERO, Vector2.RIGHT, 0.1)

	var fine := Vector2.ZERO
	for _frame in 10:
		fine = _walk(fine, Vector2.RIGHT, 0.01)

	assert_true(
		is_equal_approx(coarse.x, fine.x),
		"one 0.1s step gave %f, ten 0.01s steps gave %f" % [coarse.x, fine.x]
	)


func test_reversing_does_not_overshoot() -> void:
	var velocity := Vector2(SPEED, 0.0)
	for _frame in 600:
		velocity = _walk(velocity, Vector2.LEFT)
	assert_true(is_equal_approx(velocity.x, -SPEED))


func test_gravity_pulls_a_falling_actor_down() -> void:
	var vertical := MovementSolver.apply_gravity(0.0, 20.0, STEP, false)
	assert_true(vertical < 0.0)


func test_gravity_accumulates_over_a_fall() -> void:
	var vertical := 0.0
	for _frame in 60:
		vertical = MovementSolver.apply_gravity(vertical, 20.0, STEP, false)
	assert_true(is_equal_approx(vertical, -20.0), "a second of fall should reach -20 m/s")


## An unbounded downward velocity while grounded makes an actor punch through
## thin geometry the instant it steps off an edge.
func test_standing_on_the_ground_clears_downward_velocity() -> void:
	assert_eq(MovementSolver.apply_gravity(-500.0, 20.0, STEP, true), 0.0)


func test_yaw_zero_faces_negative_z() -> void:
	# Godot's convention: a node faces its local -Z.
	assert_true(is_zero_approx(MovementSolver.yaw_towards(Vector2(0.0, -1.0))))


func test_facing_matches_the_requested_direction() -> void:
	for direction: Vector2 in [
		Vector2(0.0, -1.0), Vector2(1.0, 0.0), Vector2(0.0, 1.0), Vector2(-1.0, 0.0)
	]:
		var yaw := MovementSolver.yaw_towards(direction)
		# Rebuild the forward vector from the yaw and compare.
		var forward := Vector2(-sin(yaw), -cos(yaw))
		assert_true(
			forward.distance_to(direction) < 0.0001,
			"facing %v produced forward %v" % [direction, forward]
		)


func test_turning_stops_once_it_arrives() -> void:
	var yaw := MovementSolver.turn_towards(0.0, 1.0, 10.0)
	assert_true(is_equal_approx(yaw, 1.0), "overshot to %f" % yaw)


func test_turning_is_limited_by_the_step() -> void:
	var yaw := MovementSolver.turn_towards(0.0, 3.0, 0.1)
	assert_true(is_equal_approx(yaw, 0.1))


## Naive subtraction sends an actor the long way round whenever the angles
## straddle +/-pi, which looks like a spin-out.
func test_turning_takes_the_short_way_across_the_wrap() -> void:
	var yaw := MovementSolver.turn_towards(3.0, -3.0, 0.1)
	assert_true(yaw > 3.0, "should have kept turning positive, went to %f" % yaw)

	var other := MovementSolver.turn_towards(-3.0, 3.0, 0.1)
	assert_true(other < -3.0, "should have kept turning negative, went to %f" % other)


func test_turning_converges_from_any_angle() -> void:
	for start: float in [-3.1, -1.0, 0.0, 2.2, 3.1]:
		var yaw := start
		for _frame in 200:
			yaw = MovementSolver.turn_towards(yaw, 1.5, 0.1)
		assert_true(
			is_zero_approx(angle_difference(yaw, 1.5)),
			"from %f settled at %f" % [start, yaw]
		)


func test_ground_direction_ignores_height() -> void:
	var direction := MovementSolver.ground_direction(
		Vector3(0.0, 100.0, 0.0), Vector3(10.0, -50.0, 0.0)
	)
	assert_true(is_equal_approx(direction.x, 1.0))
	assert_true(is_zero_approx(direction.y))


func test_ground_direction_of_a_stacked_pair_is_zero() -> void:
	var direction := MovementSolver.ground_direction(
		Vector3(5.0, 0.0, 5.0), Vector3(5.0, 9.0, 5.0)
	)
	assert_eq(direction, Vector2.ZERO)
	assert_false(is_nan(direction.x), "normalising a zero vector must not produce NaN")
