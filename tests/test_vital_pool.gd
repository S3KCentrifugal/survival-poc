extends TestCase
## The bounded quantity shared by health, stamina and anything else with a bar.


func test_a_new_pool_starts_full() -> void:
	var pool := VitalPool.new(100.0)
	assert_eq(pool.current, 100.0)
	assert_true(pool.is_full())
	assert_false(pool.is_empty())


func test_a_pool_can_start_empty() -> void:
	var pool := VitalPool.new(100.0, false)
	assert_eq(pool.current, 0.0)
	assert_true(pool.is_empty())


func test_draining_removes_what_was_asked_for() -> void:
	var pool := VitalPool.new(100.0)
	assert_eq(pool.drain(30.0), 30.0)
	assert_eq(pool.current, 70.0)


## The return value is how a caller tells a partial spend from a full one.
func test_draining_more_than_is_left_takes_only_what_is_there() -> void:
	var pool := VitalPool.new(100.0)
	pool.drain(90.0)
	assert_eq(pool.drain(50.0), 10.0, "reported taking more than the pool held")
	assert_eq(pool.current, 0.0, "went negative")


func test_restoring_more_than_the_ceiling_adds_only_the_shortfall() -> void:
	var pool := VitalPool.new(100.0)
	pool.drain(10.0)
	assert_eq(pool.restore(50.0), 10.0)
	assert_eq(pool.current, 100.0, "overshot the maximum")


## A negative amount must not become the opposite operation by accident -- a
## damage number that goes negative should heal nobody.
func test_negative_amounts_do_nothing() -> void:
	var pool := VitalPool.new(100.0)
	pool.drain(50.0)
	assert_eq(pool.drain(-25.0), 0.0)
	assert_eq(pool.restore(-25.0), 0.0)
	assert_eq(pool.current, 50.0)


func test_fill_and_empty() -> void:
	var pool := VitalPool.new(80.0)
	pool.empty()
	assert_true(pool.is_empty())
	pool.fill()
	assert_eq(pool.current, 80.0)


func test_fraction_tracks_the_current_value() -> void:
	var pool := VitalPool.new(200.0)
	assert_eq(pool.fraction(), 1.0)
	pool.drain(150.0)
	assert_true(is_equal_approx(pool.fraction(), 0.25))


## UI asks for the fraction every frame and must never be handed a NaN.
func test_a_zero_maximum_reads_as_empty_rather_than_dividing_by_zero() -> void:
	var pool := VitalPool.new(0.0)
	assert_eq(pool.fraction(), 0.0)
	assert_false(is_nan(pool.fraction()))


func test_a_negative_maximum_is_clamped_away() -> void:
	var pool := VitalPool.new(-50.0)
	assert_eq(pool.maximum, 0.0)
	assert_eq(pool.current, 0.0)


func test_lowering_the_maximum_spills_the_excess() -> void:
	var pool := VitalPool.new(100.0)
	pool.set_maximum(40.0)
	assert_eq(pool.current, 40.0, "current was left above the new ceiling")


## Granting extra capacity should not also be a free heal.
func test_raising_the_maximum_does_not_heal() -> void:
	var pool := VitalPool.new(100.0)
	pool.drain(60.0)
	pool.set_maximum(200.0)
	assert_eq(pool.current, 40.0)
	assert_false(pool.is_full())


func test_setting_the_current_value_is_clamped_at_both_ends() -> void:
	var pool := VitalPool.new(100.0)
	pool.set_current(500.0)
	assert_eq(pool.current, 100.0)
	pool.set_current(-500.0)
	assert_eq(pool.current, 0.0)
