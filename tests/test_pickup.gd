extends TestCase
## Picking things up: what is in reach, what F does, and what happens when the
## bag is full.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MUSHROOM_SCENE: String = "res://items/mushroom.tscn"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_mounted.append(node)
	return node


func _mushroom_at(where: Vector3) -> Node3D:
	var mushroom: Node3D = load(MUSHROOM_SCENE).instantiate()
	_mount(mushroom)
	mushroom.global_position = where
	return mushroom


## A collector with a body, a bag, and the router that owns the key.
##
## The collector stopped reading input when merchants arrived on the same key --
## two components watching F means standing between a mushroom and a merchant
## does both. These tests drive the router, which is what the game does.
func _collector_at(where: Vector3) -> PickupCollector:
	var body := Node3D.new()
	_mount(body)
	body.global_position = where

	var inventory := InventoryComponent.new()
	body.add_child(inventory)

	var collector := PickupCollector.new()
	collector.name = "Collector"
	collector.body = body
	collector.inventory = inventory
	body.add_child(collector)

	var router := InteractionRouter.new()
	router.name = "Router"
	router.body = body
	router.collector = collector
	router.input_source = ScriptedInputSource.new()
	body.add_child(router)
	return collector


func _router_for(collector: PickupCollector) -> InteractionRouter:
	return collector.get_parent().get_node("Router")


func _press_interact(collector: PickupCollector) -> void:
	# A press is a release and a press: the rising edge is what acts.
	var router := _router_for(collector)
	var source: ScriptedInputSource = router.input_source
	source.interact(false)
	router.step()
	source.interact(true)
	router.step()


func test_the_mushroom_scene_is_pickable() -> void:
	var mushroom := _mushroom_at(Vector3.ZERO)
	var pickup: PickupComponent = mushroom.get_node_or_null("Pickup")
	assert_not_null(pickup, "the mushroom cannot be picked up")
	assert_not_null(pickup.definition, "it is a pickup for nothing in particular")
	assert_eq(pickup.definition.id, &"mushroom")
	assert_eq(pickup.actor, mushroom, "it would free the wrong node")
	assert_true(pickup.is_in_group(PickupComponent.GROUP), "nothing will ever find it")


func test_the_key_is_bound() -> void:
	assert_true(
		InputMap.has_action(PlayerInputSource.ACTION_INTERACT),
		"the interact action is not in the InputMap, so no key produces one"
	)


## Choosing is a static function over a list of positions, so it needs no scene,
## no physics and no frame.
func test_it_picks_the_nearest_thing_in_reach() -> void:
	var near := _mushroom_at(Vector3(1.0, 0.0, 0.0)).get_node("Pickup")
	var far := _mushroom_at(Vector3(1.6, 0.0, 0.0)).get_node("Pickup")
	var candidates: Array = [far, near]

	assert_eq(PickupCollector.nearest(Vector3.ZERO, candidates, 2.0), near)
	assert_eq(PickupCollector.nearest(Vector3(3.0, 0.0, 0.0), candidates, 2.0), far)


func test_nothing_out_of_reach_is_offered() -> void:
	var pickup := _mushroom_at(Vector3(5.0, 0.0, 0.0)).get_node("Pickup")
	assert_null(PickupCollector.nearest(Vector3.ZERO, [pickup], 2.2))
	assert_eq(PickupCollector.nearest(Vector3.ZERO, [pickup], 6.0), pickup)


## Height counts. A mushroom on the roof is not in reach of someone below it.
func test_reach_is_measured_in_three_dimensions() -> void:
	var pickup := _mushroom_at(Vector3(0.0, 4.0, 0.0)).get_node("Pickup")
	assert_null(PickupCollector.nearest(Vector3.ZERO, [pickup], 2.2))


func test_pressing_the_key_picks_it_up() -> void:
	var mushroom := _mushroom_at(Vector3(1.0, 0.0, 0.0))
	var collector := _collector_at(Vector3.ZERO)

	_press_interact(collector)
	assert_eq(collector.inventory.count_of(&"mushroom"), 1, "it did not go in the bag")
	assert_true(mushroom.is_queued_for_deletion(), "the mushroom is still standing there")


func test_walking_past_without_pressing_takes_nothing() -> void:
	_mushroom_at(Vector3(1.0, 0.0, 0.0))
	var collector := _collector_at(Vector3.ZERO)

	for _frame in 10:
		_router_for(collector).step()
	assert_eq(collector.inventory.count_of(&"mushroom"), 0, "it picked itself up")


## Holding F must not clear a whole patch. Same rising edge as jumping.
func test_holding_the_key_picks_up_once() -> void:
	_mushroom_at(Vector3(0.5, 0.0, 0.0))
	_mushroom_at(Vector3(0.7, 0.0, 0.0))
	var collector := _collector_at(Vector3.ZERO)

	var router := _router_for(collector)
	(router.input_source as ScriptedInputSource).interact(true)
	for _frame in 20:
		router.step()
	assert_eq(collector.inventory.count_of(&"mushroom"), 1, "a held key emptied the patch")


func test_picking_two_up_stacks_them() -> void:
	_mushroom_at(Vector3(0.5, 0.0, 0.0))
	_mushroom_at(Vector3(0.7, 0.0, 0.0))
	var collector := _collector_at(Vector3.ZERO)

	_press_interact(collector)
	_press_interact(collector)
	assert_eq(collector.inventory.count_of(&"mushroom"), 2)
	assert_eq(
		collector.inventory.inventory().filled_slots().size(), 1, "two mushrooms took two slots"
	)


## An item that vanishes because you were full is worse than one you could not
## pick up.
func test_a_full_bag_leaves_it_on_the_ground() -> void:
	var mushroom := _mushroom_at(Vector3(1.0, 0.0, 0.0))
	var collector := _collector_at(Vector3.ZERO)
	var pickup: PickupComponent = mushroom.get_node("Pickup")

	# One slot, already full of something else.
	collector.inventory.capacity = 1
	var other := ItemDefinition.new()
	other.id = &"stone"
	other.max_stack = 1
	collector.inventory.collect(other, 1)

	var refused: Array[StringName] = []
	collector.bag_full.connect(func(d: ItemDefinition) -> void: refused.append(d.id))

	_press_interact(collector)
	assert_eq(collector.inventory.count_of(&"mushroom"), 0)
	assert_false(mushroom.is_queued_for_deletion(), "a full bag deleted the mushroom")
	assert_true(pickup.is_available(), "it is no longer pickable")
	assert_eq(refused, [&"mushroom"] as Array[StringName], "it refused silently")


func test_it_announces_what_is_in_reach() -> void:
	var collector := _collector_at(Vector3.ZERO)
	var seen: Array[String] = []
	collector.target_changed.connect(
		func(p: PickupComponent) -> void: seen.append("none" if p == null else String(p.definition.id))
	)

	collector.step()
	assert_eq(collector.target(), null, "it found something in an empty world")

	_mushroom_at(Vector3(1.0, 0.0, 0.0))
	collector.step()
	assert_not_null(collector.target(), "it did not notice the mushroom")
	assert_eq(seen, ["mushroom"] as Array[String])

	# Steady state: the same target must not be announced every frame.
	collector.step()
	collector.step()
	assert_eq(seen.size(), 1, "it re-announced an unchanged target %d times" % seen.size())


func test_the_prompt_says_what_it_is() -> void:
	var pickup: PickupComponent = _mushroom_at(Vector3.ZERO).get_node("Pickup")
	assert_true(pickup.prompt_text().contains("Mushroom"), "the prompt does not name the item")


## Assembly: the player must carry all three, or F does nothing and no test
## above would notice.
func test_the_player_is_assembled_to_pick_things_up() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	_mount(world)

	var collector: PickupCollector = world.get_node_or_null("Player/Collector")
	assert_not_null(collector, "the player cannot pick anything up")
	assert_not_null(collector.inventory, "the collector has nowhere to put things")
	assert_eq(collector.body, world.get_node("Player"), "reach is measured from the wrong place")
	var router: InteractionRouter = world.get_node_or_null("Player/Router")
	assert_not_null(router, "nothing owns the interact key")
	assert_eq(router.collector, collector, "the router cannot pick anything up")
	assert_not_null(
		router.input_source, "nothing gave the router an input source, so F does nothing"
	)
