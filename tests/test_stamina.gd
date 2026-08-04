extends TestCase
## Spending, the recovery delay, and the exhaustion lockout.

const STEP: float = 1.0 / 60.0

var _config: StaminaConfig


func before_each() -> void:
	_config = StaminaConfig.new()
	_config.maximum = 100.0
	_config.drain_per_second = 20.0
	_config.recovery_per_second = 15.0
	_config.recovery_delay = 1.0
	_config.exhausted_recovery_fraction = 0.25


func _run(stamina: Stamina, seconds: float, wants: bool, step: float = STEP) -> void:
	for _tick in int(round(seconds / step)):
		stamina.tick(step, wants)


## Empties the bar and lets the recovery delay expire, so a test can start from
## the exhausted state without depending on where the delay happens to be.
##
## Deliberately overshoots the five seconds the maths says it takes: draining in
## sixtieths accumulates float error, and stopping on the exact boundary would
## leave a pool holding 1e-14 rather than nothing.
func _exhaust(stamina: Stamina) -> void:
	_run(stamina, 6.0, true)


func test_a_fresh_actor_starts_full_and_able() -> void:
	var stamina := Stamina.new(_config)
	assert_eq(stamina.pool.current, 100.0)
	assert_true(stamina.can_spend())
	assert_false(stamina.is_exhausted())


func test_spending_drains_at_the_configured_rate() -> void:
	var stamina := Stamina.new(_config)
	_run(stamina, 1.0, true)
	assert_true(
		is_equal_approx(stamina.pool.current, 80.0),
		"a second of effort left %f" % stamina.pool.current
	)


func test_a_granted_request_reports_true() -> void:
	var stamina := Stamina.new(_config)
	assert_true(stamina.tick(STEP, true))


func test_an_idle_tick_spends_nothing() -> void:
	var stamina := Stamina.new(_config)
	assert_false(stamina.tick(STEP, false))
	assert_eq(stamina.pool.current, 100.0)


func test_running_the_bar_dry_exhausts() -> void:
	var stamina := Stamina.new(_config)
	_run(stamina, 5.5, true)
	assert_true(stamina.pool.is_empty(), "sustained effort should have emptied it")
	assert_true(stamina.is_exhausted())
	assert_false(stamina.can_spend())


## Lifting the lock the moment a single point returns would let an exhausted
## actor sprint one frame in every two, which reads as a bug rather than as
## exhaustion.
func test_exhaustion_holds_until_the_threshold_is_back() -> void:
	var stamina := Stamina.new(_config)
	_exhaust(stamina)

	# 15 back of the 25 required.
	_run(stamina, 1.0, false)
	assert_true(stamina.pool.current > 0.0, "recovery never started")
	assert_true(stamina.pool.fraction() < _config.exhausted_recovery_fraction)
	assert_true(stamina.is_exhausted(), "the lockout lifted too early")
	assert_false(stamina.tick(STEP, true), "spent while locked out")

	# Comfortably past the threshold.
	_run(stamina, 1.5, false)
	assert_false(stamina.is_exhausted(), "the lockout never lifted")
	assert_true(stamina.can_spend())


## Holding the key with an empty bar must not stall the refill, or the actor
## never gets going again.
func test_it_recovers_even_while_effort_is_still_demanded() -> void:
	var stamina := Stamina.new(_config)
	_run(stamina, 5.5, true)
	assert_true(stamina.pool.is_empty())

	_run(stamina, 2.0, true)
	assert_true(stamina.pool.current > 0.0, "holding the key blocked its own recovery")


## Without the delay, tapping the key is free: the bar refills in the gaps
## between taps and the actor sprints indefinitely at a stutter.
func test_recovery_waits_out_the_delay() -> void:
	var stamina := Stamina.new(_config)
	_run(stamina, 2.0, true)
	var after_effort := stamina.pool.current

	_run(stamina, 0.9, false)
	assert_true(
		is_equal_approx(stamina.pool.current, after_effort),
		"recovered %f during the delay" % (stamina.pool.current - after_effort)
	)

	_run(stamina, 1.0, false)
	assert_true(stamina.pool.current > after_effort, "recovery never started")


func test_every_spend_restarts_the_delay() -> void:
	var stamina := Stamina.new(_config)
	_run(stamina, 1.0, true)
	var after_effort := stamina.pool.current

	# Tapping: not quite a full delay of quiet, then one more spend.
	for _tap in 3:
		_run(stamina, 0.9, false)
		stamina.tick(STEP, true)

	assert_true(
		stamina.pool.current < after_effort,
		"tapping refilled the bar; the delay is not being restarted"
	)


func test_recovery_is_capped_at_the_maximum() -> void:
	var stamina := Stamina.new(_config)
	_run(stamina, 1.0, true)
	_run(stamina, 60.0, false)
	assert_eq(stamina.pool.current, 100.0, "recovered past full")


## The delay and the refill share a tick, so a coarse frame must not swallow the
## leftover time -- the same real time has to give the same stamina back.
func test_recovery_is_frame_rate_independent() -> void:
	var coarse := Stamina.new(_config)
	_run(coarse, 2.0, true)
	coarse.tick(2.0, false)

	var fine := Stamina.new(_config)
	_run(fine, 2.0, true)
	_run(fine, 2.0, false, 0.1)

	assert_true(
		is_equal_approx(coarse.pool.current, fine.pool.current),
		"one 2s tick gave %f, twenty 0.1s ticks gave %f" % [coarse.pool.current, fine.pool.current]
	)


func test_spending_is_frame_rate_independent() -> void:
	var coarse := Stamina.new(_config)
	coarse.tick(1.0, true)

	var fine := Stamina.new(_config)
	_run(fine, 1.0, true, 0.05)

	assert_true(is_equal_approx(coarse.pool.current, fine.pool.current))
