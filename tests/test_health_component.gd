extends TestCase
## The health component and its wiring into the player scene.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const CONFIG_RESOURCE: String = "res://resources/health/player_health.tres"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


## A component detached from any actor, with a config of a known size.
func _health(maximum: float = 100.0) -> HealthComponent:
	var config := HealthConfig.new()
	config.maximum = maximum
	var component := HealthComponent.new()
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
	var config: HealthConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not a HealthConfig" % CONFIG_RESOURCE)
	assert_true(config.maximum > 0.0)


func test_the_player_carries_health_wired_to_a_config() -> void:
	var player := _mount_player()
	var health: HealthComponent = player.get_node_or_null("Health")
	assert_not_null(health, "the player scene has no health component")
	assert_not_null(health.config, "config is not wired in the scene")
	assert_true(health.is_alive())
	assert_eq(health.current(), health.maximum(), "should spawn at full health")


## Usable without a scene tree: logic first, presentation second.
func test_it_works_before_it_is_ever_added_to_a_tree() -> void:
	var health := _health(50.0)
	assert_eq(health.current(), 50.0)
	assert_true(health.is_alive())


func test_damage_reduces_health() -> void:
	var health := _health()
	assert_eq(health.take_damage(30.0), 30.0)
	assert_eq(health.current(), 70.0)
	assert_true(is_equal_approx(health.fraction(), 0.7))


func test_damage_reports_what_was_actually_taken() -> void:
	var health := _health()
	health.take_damage(90.0)
	assert_eq(health.take_damage(40.0), 10.0, "a killing blow overreported its damage")
	assert_eq(health.current(), 0.0)


func test_healing_is_capped_at_the_maximum() -> void:
	var health := _health()
	health.take_damage(20.0)
	assert_eq(health.heal(100.0), 20.0)
	assert_eq(health.current(), health.maximum())


func test_running_out_of_health_kills() -> void:
	var health := _health()
	health.take_damage(100.0)
	assert_false(health.is_alive())
	assert_eq(health.current(), 0.0)


## Every listener -- ragdoll, loot drop, respawn timer -- would fire twice if a
## corpse could die again.
func test_death_is_announced_exactly_once() -> void:
	var health := _health()
	var deaths := [0]
	health.died.connect(func() -> void: deaths[0] += 1)

	health.take_damage(100.0)
	health.take_damage(100.0)
	health.take_damage(100.0)
	assert_eq(deaths[0], 1, "died fired %d times" % deaths[0])


func test_the_dead_take_no_further_damage() -> void:
	var health := _health()
	health.take_damage(150.0)

	var damage_events := [0]
	health.damaged.connect(func(_amount: float) -> void: damage_events[0] += 1)
	assert_eq(health.take_damage(10.0), 0.0)
	assert_eq(damage_events[0], 0, "a corpse reported being damaged")


## Resurrection should be a deliberate act, not a side effect of a bandage
## landing a frame too late.
func test_healing_does_not_raise_the_dead() -> void:
	var health := _health()
	health.take_damage(100.0)
	assert_eq(health.heal(50.0), 0.0)
	assert_false(health.is_alive())
	assert_eq(health.current(), 0.0)


func test_it_announces_damage_and_healing() -> void:
	var health := _health()
	var damaged := [0.0]
	var healed := [0.0]
	health.damaged.connect(func(amount: float) -> void: damaged[0] = amount)
	health.healed.connect(func(amount: float) -> void: healed[0] = amount)

	health.take_damage(25.0)
	assert_eq(damaged[0], 25.0)
	health.heal(10.0)
	assert_eq(healed[0], 10.0)


func test_changed_carries_the_new_value_for_a_bar_to_draw() -> void:
	var health := _health()
	var seen := [0.0, 0.0]
	health.changed.connect(
		func(current: float, maximum: float) -> void:
			seen[0] = current
			seen[1] = maximum
	)

	health.take_damage(40.0)
	assert_eq(seen[0], 60.0)
	assert_eq(seen[1], 100.0)


## Zero-sized events are noise: a bar has nothing to redraw and a hit reaction
## would play for a blow that landed on nothing.
func test_a_no_op_change_is_not_announced() -> void:
	var health := _health()
	var events := [0]
	health.changed.connect(func(_current: float, _maximum: float) -> void: events[0] += 1)

	health.take_damage(0.0)
	health.heal(50.0)  # already full
	assert_eq(events[0], 0, "announced %d changes that did not happen" % events[0])
