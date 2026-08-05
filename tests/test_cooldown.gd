extends TestCase
## The reusable "you cannot do that again yet".

const STEP: float = 1.0 / 60.0


func test_a_fresh_cooldown_is_ready() -> void:
	assert_true(Cooldown.new(1.0).is_ready())


func test_using_it_starts_the_wait() -> void:
	var cooldown := Cooldown.new(1.0)
	assert_true(cooldown.use())
	assert_false(cooldown.is_ready())


func test_using_it_again_too_soon_is_refused() -> void:
	var cooldown := Cooldown.new(1.0)
	cooldown.use()
	assert_false(cooldown.use(), "it allowed a second use inside the wait")


func test_it_becomes_ready_again() -> void:
	var cooldown := Cooldown.new(0.5)
	cooldown.use()
	for _frame in 60:
		cooldown.advance(STEP)
	assert_true(cooldown.is_ready())
	assert_true(cooldown.use())


func test_it_is_not_ready_a_moment_early() -> void:
	var cooldown := Cooldown.new(0.5)
	cooldown.use()
	for _frame in 29:  # 0.483s
		cooldown.advance(STEP)
	assert_false(cooldown.is_ready(), "became ready before the wait was over")


## The same real time must leave the same wait, however it is sliced.
func test_counting_down_is_frame_rate_independent() -> void:
	var coarse := Cooldown.new(1.0)
	coarse.use()
	coarse.advance(0.5)

	var fine := Cooldown.new(1.0)
	fine.use()
	for _frame in 50:
		fine.advance(0.01)

	assert_true(
		is_equal_approx(coarse.remaining, fine.remaining),
		"one 0.5s step left %f, fifty 0.01s steps left %f" % [coarse.remaining, fine.remaining]
	)


## A long frame -- a stall, a loading hitch -- must not leave a negative wait
## that then counts back up to ready.
func test_a_huge_step_does_not_overshoot_into_negative() -> void:
	var cooldown := Cooldown.new(0.5)
	cooldown.use()
	cooldown.advance(30.0)
	assert_eq(cooldown.remaining, 0.0)
	assert_true(cooldown.is_ready())


func test_a_cooldown_of_zero_is_always_ready() -> void:
	var cooldown := Cooldown.new(0.0)
	assert_true(cooldown.use())
	assert_true(cooldown.use(), "a zero cooldown should never refuse")
	assert_eq(cooldown.fraction(), 0.0, "and must not divide by its own zero")


func test_a_negative_duration_is_treated_as_none() -> void:
	var cooldown := Cooldown.new(-5.0)
	assert_true(cooldown.use())
	assert_true(cooldown.is_ready())


func test_fraction_runs_from_one_down_to_zero() -> void:
	var cooldown := Cooldown.new(1.0)
	cooldown.use()
	assert_true(is_equal_approx(cooldown.fraction(), 1.0))
	cooldown.advance(0.5)
	assert_true(is_equal_approx(cooldown.fraction(), 0.5))
	cooldown.advance(0.5)
	assert_true(is_zero_approx(cooldown.fraction()))


func test_advancing_a_ready_cooldown_does_nothing() -> void:
	var cooldown := Cooldown.new(1.0)
	cooldown.advance(10.0)
	assert_eq(cooldown.remaining, 0.0)


func test_clearing_makes_it_usable_immediately() -> void:
	var cooldown := Cooldown.new(5.0)
	cooldown.use()
	cooldown.clear()
	assert_true(cooldown.is_ready())
	assert_true(cooldown.use())
