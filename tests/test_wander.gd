extends TestCase
## Deciding where to amble to, and when to stop trying.

const STEP: float = 1.0 / 60.0

var _config: WanderConfig


func before_each() -> void:
	_config = WanderConfig.new()
	_config.pause_min = 1.0
	_config.pause_max = 2.0
	_config.radius = 8.0
	_config.arrival_distance = 0.7
	_config.give_up_seconds = 10.0


func _wander(home: Vector2 = Vector2.ZERO, seed_value: int = 1) -> Wander:
	return Wander.new(_config, home, seed_value)


## Runs a wanderer that actually walks: each tick it moves along whatever
## direction it was given, at [param speed].
func _walk(wanderer: Wander, from: Vector2, seconds: float, speed: float = 1.3) -> Vector2:
	var position := from
	for _frame in int(round(seconds / STEP)):
		position += wanderer.tick(position, STEP) * speed * STEP
	return position


## A world stands still for a moment before anything moves.
func test_it_starts_paused() -> void:
	var wanderer := _wander()
	assert_true(wanderer.is_paused())
	assert_eq(wanderer.tick(Vector2.ZERO, STEP), Vector2.ZERO)


func test_it_sets_off_once_the_pause_is_over() -> void:
	var wanderer := _wander()
	var moved := false
	for _frame in 300:  # five seconds, longer than the longest pause
		if not wanderer.tick(Vector2.ZERO, STEP).is_zero_approx():
			moved = true
			break
	assert_true(moved, "it never set off")


func test_it_walks_toward_its_destination() -> void:
	var wanderer := _wander()
	for _frame in 300:
		var direction := wanderer.tick(Vector2.ZERO, STEP)
		if direction.is_zero_approx():
			continue
		var wanted := (wanderer.destination() - Vector2.ZERO).normalized()
		assert_true(
			direction.distance_to(wanted) < 0.001,
			"walking %v, destination is %v" % [direction, wanderer.destination()]
		)
		return
	fail("it never walked anywhere")


func test_the_direction_is_a_unit_vector() -> void:
	# Movement scales the target speed by this length, so anything else is a
	# wanderer that walks at the wrong pace.
	var wanderer := _wander()
	for _frame in 600:
		var direction := wanderer.tick(Vector2(3.0, 1.0), STEP)
		if not direction.is_zero_approx():
			assert_true(
				is_equal_approx(direction.length(), 1.0), "length %f" % direction.length()
			)
			return
	fail("it never walked anywhere")


func test_it_stops_when_it_arrives() -> void:
	var wanderer := _wander()
	var position := _walk(wanderer, Vector2.ZERO, 30.0)
	assert_true(
		position.distance_to(wanderer.destination()) <= _config.radius,
		"ended %f from its destination" % position.distance_to(wanderer.destination())
	)


func test_it_pauses_again_after_arriving() -> void:
	var wanderer := _wander()
	var position := Vector2.ZERO
	var paused_after_walking := false
	var walked := false
	for _frame in 3000:
		var direction := wanderer.tick(position, STEP)
		if not direction.is_zero_approx():
			walked = true
			position += direction * 1.3 * STEP
		elif walked:
			paused_after_walking = true
			break
	assert_true(paused_after_walking, "it never stopped once it started")


## It should mill about, not emigrate.
func test_it_never_strays_beyond_its_radius() -> void:
	var home := Vector2(20.0, -5.0)
	var wanderer := _wander(home)
	var position := home
	for _frame in 6000:  # 100 seconds
		position += wanderer.tick(position, STEP) * 1.3 * STEP
		assert_true(
			wanderer.destination().distance_to(home) <= _config.radius + 0.001,
			"picked a destination %f from home" % wanderer.destination().distance_to(home)
		)
	assert_true(
		position.distance_to(home) <= _config.radius + 1.0,
		"wandered %f from home" % position.distance_to(home)
	)


## An actor wedged against a wall, or aiming at a spot inside a building, walks
## into it for the rest of the session without this.
func test_it_gives_up_on_somewhere_it_cannot_reach() -> void:
	var wanderer := _wander()
	# Never move: the position argument stays put however hard it walks.
	var first_destination := Vector2.ZERO
	var gave_up := false
	for _frame in 3000:
		var direction := wanderer.tick(Vector2.ZERO, STEP)
		if not direction.is_zero_approx() and first_destination == Vector2.ZERO:
			first_destination = wanderer.destination()
		if first_destination != Vector2.ZERO and wanderer.destination() != first_destination:
			gave_up = true
			break
	assert_true(gave_up, "it kept walking at a wall forever")


func test_giving_up_takes_about_as_long_as_configured() -> void:
	_config.give_up_seconds = 3.0
	var wanderer := _wander()
	# Get it walking first.
	while wanderer.is_paused():
		wanderer.tick(Vector2.ZERO, STEP)

	var ticks := 0
	while not wanderer.is_paused() and ticks < 600:
		wanderer.tick(Vector2.ZERO, STEP)
		ticks += 1
	var seconds := ticks * STEP
	assert_true(
		absf(seconds - 3.0) < 0.2, "gave up after %f seconds, expected about 3" % seconds
	)


## Two wanderers sharing a generator walk in step, which reads as choreography
## rather than life.
func test_different_seeds_wander_differently() -> void:
	var first := _wander(Vector2.ZERO, 1)
	var second := _wander(Vector2.ZERO, 2)
	for _frame in 300:
		first.tick(Vector2.ZERO, STEP)
		second.tick(Vector2.ZERO, STEP)
	assert_ne(first.destination(), second.destination())


func test_the_same_seed_wanders_the_same_way() -> void:
	var first := _wander(Vector2.ZERO, 7)
	var second := _wander(Vector2.ZERO, 7)
	for _frame in 300:
		first.tick(Vector2.ZERO, STEP)
		second.tick(Vector2.ZERO, STEP)
	assert_eq(first.destination(), second.destination())


func test_an_inverted_pause_range_is_straightened_out() -> void:
	_config.pause_min = 5.0
	_config.pause_max = 1.0
	var limits := _config.pause_range()
	assert_true(limits.x <= limits.y)
	# And it still sets off rather than pausing for a negative time.
	var wanderer := _wander()
	var moved := false
	for _frame in 600:
		if not wanderer.tick(Vector2.ZERO, STEP).is_zero_approx():
			moved = true
			break
	assert_true(moved)


## Points picked by a uniform radius bunch toward the middle, and a group of
## wanderers reads as a huddle rather than a scattering.
func test_destinations_are_spread_across_the_circle_not_bunched_in_it() -> void:
	var far := 0
	var total := 0
	for seed_value in 200:
		var wanderer := _wander(Vector2.ZERO, seed_value)
		while wanderer.is_paused():
			wanderer.tick(Vector2.ZERO, STEP)
		total += 1
		# Half the area of a circle lies beyond radius/sqrt(2).
		if wanderer.destination().length() > _config.radius * 0.7071:
			far += 1
	assert_true(
		absf(float(far) / total - 0.5) < 0.12,
		"%d of %d destinations were in the outer half; expected about half" % [far, total]
	)
