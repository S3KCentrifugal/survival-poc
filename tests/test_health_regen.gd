extends TestCase
## Health coming back on its own.

const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _health(regen: float = 10.0, delay: float = 1.0, maximum: float = 100.0) -> HealthComponent:
	var config := HealthConfig.new()
	config.maximum = maximum
	config.regen_per_second = regen
	config.regen_delay = delay
	var component := HealthComponent.new()
	component.config = config
	_mounted.append(component)
	return component


func _run(component: HealthComponent, seconds: float) -> void:
	for _frame in int(round(seconds / STEP)):
		component.step(STEP)


func test_the_config_carries_a_regen_rate() -> void:
	var config: HealthConfig = load("res://resources/health/player_health.tres")
	assert_true(config.regen_per_second >= 0.0)
	assert_true(config.regen_delay >= 0.0)


func test_a_full_actor_does_not_regenerate_past_full() -> void:
	var health := _health()
	_run(health, 10.0)
	assert_eq(health.current(), health.maximum())


## Without the delay, health ticks back up between blows and a fight has no
## attrition in it.
func test_regeneration_waits_out_the_delay() -> void:
	var health := _health(10.0, 1.0)
	health.take_damage(40.0)

	_run(health, 0.9)
	assert_true(
		is_equal_approx(health.current(), 60.0),
		"regenerated %f during the delay" % (health.current() - 60.0)
	)

	_run(health, 1.0)
	assert_true(health.current() > 60.0, "regeneration never started")


func test_it_regenerates_at_the_configured_rate() -> void:
	var health := _health(10.0, 0.0)
	health.take_damage(50.0)
	_run(health, 2.0)
	assert_true(
		is_equal_approx(health.current(), 70.0), "two seconds gave %f" % (health.current() - 50.0)
	)


func test_regeneration_stops_at_full() -> void:
	var health := _health(50.0, 0.0)
	health.take_damage(10.0)
	_run(health, 30.0)
	assert_eq(health.current(), health.maximum(), "overshot the maximum")


func test_every_hit_restarts_the_delay() -> void:
	var health := _health(10.0, 1.0)
	health.take_damage(30.0)
	for _tap in 3:
		_run(health, 0.9)
		health.take_damage(1.0)
	assert_true(
		health.current() < 70.0, "regeneration ran despite being hit; the delay is not restarting"
	)


func test_regeneration_can_be_switched_off() -> void:
	var health := _health(0.0, 0.0)
	health.take_damage(40.0)
	_run(health, 30.0)
	assert_eq(health.current(), 60.0, "it regenerated with the rate at zero")


## Resurrection is a deliberate act, not a side effect of standing still.
func test_the_dead_do_not_regenerate() -> void:
	var health := _health(50.0, 0.0)
	health.take_damage(health.maximum())
	_run(health, 30.0)
	assert_eq(health.current(), 0.0)
	assert_false(health.is_alive())


func test_regeneration_is_announced_like_any_other_healing() -> void:
	var health := _health(10.0, 0.0)
	health.take_damage(20.0)
	var healed := [0.0]
	health.healed.connect(func(amount: float) -> void: healed[0] += amount)
	_run(health, 1.0)
	assert_true(healed[0] > 0.0, "the bar would never redraw")


func test_it_says_when_regeneration_begins() -> void:
	var health := _health(10.0, 0.5)
	health.take_damage(20.0)
	var starts := [0]
	health.regenerating.connect(func() -> void: starts[0] += 1)
	_run(health, 2.0)
	assert_eq(starts[0], 1, "regenerating fired %d times" % starts[0])


func test_regeneration_is_frame_rate_independent() -> void:
	var coarse := _health(10.0, 0.0)
	coarse.take_damage(50.0)
	coarse.step(1.0)

	var fine := _health(10.0, 0.0)
	fine.take_damage(50.0)
	for _frame in 100:
		fine.step(0.01)

	assert_true(
		is_equal_approx(coarse.current(), fine.current()),
		"one 1s step gave %f, a hundred 0.01s steps gave %f" % [coarse.current(), fine.current()]
	)


## Stamina has had this since feature 6; health now matches it. Both vitals
## should behave the same way about coming back.
func test_stamina_recovers_the_same_way() -> void:
	var config := StaminaConfig.new()
	config.maximum = 100.0
	config.recovery_delay = 1.0
	config.recovery_per_second = 10.0
	var stamina := Stamina.new(config)

	stamina.tick(0.5, true)
	var after_effort := stamina.pool.current
	for _frame in 50:  # 0.83s, inside the delay
		stamina.tick(STEP, false)
	assert_true(is_equal_approx(stamina.pool.current, after_effort), "recovered during the delay")

	for _frame in 120:
		stamina.tick(STEP, false)
	assert_true(stamina.pool.current > after_effort)
