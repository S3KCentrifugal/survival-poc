extends TestCase
## The stamina component and its wiring into the player scene.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const CONFIG_RESOURCE: String = "res://resources/stamina/player_stamina.tres"
const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


## A component detached from any actor, tuned to drain fast enough that a test
## does not have to simulate a minute of game time.
func _stamina() -> StaminaComponent:
	var config := StaminaConfig.new()
	config.maximum = 10.0
	config.drain_per_second = 20.0
	config.recovery_per_second = 5.0
	config.recovery_delay = 0.5
	config.exhausted_recovery_fraction = 0.5

	var component := StaminaComponent.new()
	component.config = config
	_mounted.append(component)
	return component


func _mount_player() -> CharacterBody3D:
	var tree := Engine.get_main_loop() as SceneTree
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	tree.root.add_child(player)
	_mounted.append(player)
	return player


func test_the_config_resource_loads() -> void:
	var config: StaminaConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not a StaminaConfig" % CONFIG_RESOURCE)
	assert_true(config.maximum > 0.0)
	assert_true(config.drain_per_second > 0.0)
	assert_true(config.recovery_per_second > 0.0)


func test_the_player_carries_stamina_wired_to_a_config() -> void:
	var player := _mount_player()
	var stamina: StaminaComponent = player.get_node_or_null("Stamina")
	assert_not_null(stamina, "the player scene has no stamina component")
	assert_not_null(stamina.config, "config is not wired in the scene")
	assert_true(stamina.can_spend())
	assert_eq(stamina.current(), stamina.maximum(), "should spawn rested")


## Usable without a scene tree: logic first, presentation second.
func test_it_works_before_it_is_ever_added_to_a_tree() -> void:
	var stamina := _stamina()
	assert_eq(stamina.current(), 10.0)
	assert_false(stamina.step(STEP), "spent without being asked")


func test_a_request_is_granted_and_costs_stamina() -> void:
	var stamina := _stamina()
	stamina.request_drain()
	assert_true(stamina.step(STEP), "the request was refused")
	assert_true(stamina.current() < 10.0)


## The latch is what lets a consumer forget to say stop. Letting go of the key
## is simply the absence of a request, so a stale one must never survive a tick.
func test_a_request_lasts_exactly_one_tick() -> void:
	var stamina := _stamina()
	stamina.request_drain()
	stamina.step(STEP)
	var after_one := stamina.current()

	assert_false(stamina.step(STEP), "the request outlived its tick")
	assert_true(stamina.current() <= after_one, "kept draining after the request")


func test_it_announces_changes_for_a_bar_to_draw() -> void:
	var stamina := _stamina()
	var seen := [0.0, 0.0]
	stamina.changed.connect(
		func(current: float, maximum: float) -> void:
			seen[0] = current
			seen[1] = maximum
	)

	stamina.request_drain()
	stamina.step(STEP)
	assert_true(seen[0] > 0.0 and seen[0] < 10.0, "changed reported %f" % seen[0])
	assert_eq(seen[1], 10.0)


## A rested actor standing still changes nothing, and a bar has no reason to
## redraw sixty times a second.
func test_an_idle_full_actor_announces_nothing() -> void:
	var stamina := _stamina()
	var events := [0]
	stamina.changed.connect(func(_current: float, _maximum: float) -> void: events[0] += 1)

	for _tick in 60:
		stamina.step(STEP)
	assert_eq(events[0], 0, "announced %d changes while nothing happened" % events[0])


func test_it_announces_exhaustion_and_recovery_once_each() -> void:
	var stamina := _stamina()
	var exhausted := [0]
	var recovered := [0]
	stamina.exhausted.connect(func() -> void: exhausted[0] += 1)
	stamina.recovered.connect(func() -> void: recovered[0] += 1)

	# 10 stamina at 20/s empties in half a second.
	for _tick in 60:
		stamina.request_drain()
		stamina.step(STEP)
	assert_eq(exhausted[0], 1, "exhausted fired %d times" % exhausted[0])
	assert_eq(recovered[0], 0)
	assert_false(stamina.can_spend())

	# 0.5s of delay, then 5 of 10 back at 5/s.
	for _tick in 120:
		stamina.step(STEP)
	assert_eq(recovered[0], 1, "recovered fired %d times" % recovered[0])
	assert_true(stamina.can_spend())
	assert_eq(exhausted[0], 1, "exhaustion was announced again on the way back")


func test_fraction_tracks_the_bar() -> void:
	var stamina := _stamina()
	assert_eq(stamina.fraction(), 1.0)
	for _tick in 15:
		stamina.request_drain()
		stamina.step(STEP)
	assert_true(
		is_equal_approx(stamina.fraction(), 0.5),
		"a quarter second of effort left %f" % stamina.fraction()
	)
