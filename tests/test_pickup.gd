extends TestCase
## Picking things up: what is in reach, what F does, and what happens when the
## bag is full.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MUSHROOM_SCENE: String = "res://items/mushroom.tscn"


func _mushroom_at(where: Vector3) -> Node3D:
	var mushroom: Node3D = load(MUSHROOM_SCENE).instantiate()
	mount(mushroom)
	mushroom.global_position = where
	return mushroom


## A body with a bag and the router that owns the key.
##
## There is no collector any more: the item's own [InteractableComponent] is
## what the router finds, and [PickupComponent] listens to it. The bag is found
## as a child of whoever reached, which is why the router's body is the node
## holding it.
func _picker_at(where: Vector3) -> InteractionRouter:
	var body := Node3D.new()
	mount(body)
	body.global_position = where

	var inventory := InventoryComponent.new()
	inventory.name = "Bag"
	body.add_child(inventory)

	var router := InteractionRouter.new()
	router.name = "Router"
	router.body = body
	router.input_source = ScriptedInputSource.new()
	body.add_child(router)
	return router


func _bag_of(router: InteractionRouter) -> InventoryComponent:
	return router.body.get_node("Bag")


func _press_interact(router: InteractionRouter) -> void:
	# A press is a release and a press: the rising edge is what acts.
	var source: ScriptedInputSource = router.input_source
	source.interact(false)
	router.step()
	source.interact(true)
	router.step()


func test_the_mushroom_scene_is_pickable() -> void:
	var mushroom := _mushroom_at(Vector3.ZERO)
	var pickup: PickupComponent = mushroom.get_node_or_null("Pickup")
	assert_not_null(pickup, "the mushroom cannot be picked up")
	assert_not_null(
		mushroom.get_node_or_null("Interactable"), "the mushroom cannot be walked up to"
	)
	assert_not_null(pickup.definition, "it is a pickup for nothing in particular")
	assert_eq(pickup.definition.id, &"mushroom")
	assert_eq(pickup.actor, mushroom, "it would free the wrong node")
	assert_true(
		mushroom.get_node("Interactable").is_in_group(InteractableComponent.GROUP),
		"nothing will ever find it"
	)


func test_the_key_is_bound() -> void:
	assert_true(
		InputMap.has_action(PlayerInputSource.ACTION_INTERACT),
		"the interact action is not in the InputMap, so no key produces one"
	)


func test_it_picks_the_nearest_thing_in_reach() -> void:
	var near := _mushroom_at(Vector3(1.0, 0.0, 0.0)).get_node("Interactable")
	_mushroom_at(Vector3(1.6, 0.0, 0.0))
	assert_eq(_picker_at(Vector3.ZERO).find_target(), near, "it reached past the nearer one")


func test_nothing_out_of_reach_is_offered() -> void:
	_mushroom_at(Vector3(5.0, 0.0, 0.0))
	assert_null(_picker_at(Vector3.ZERO).find_target(), "it reached five metres")


## Reach lives on the thing, not on the reacher -- a merchant is bigger than a
## mushroom and that difference belongs to the merchant.
func test_each_thing_declares_its_own_reach() -> void:
	var mushroom := _mushroom_at(Vector3(3.0, 0.0, 0.0))
	var router := _picker_at(Vector3.ZERO)
	assert_null(router.find_target(), "three metres is not a mushroom's reach")

	(mushroom.get_node("Interactable") as InteractableComponent).reach = 4.0
	assert_not_null(router.find_target(), "widening its reach did not bring it into range")


## Height counts. A mushroom on the roof is not in reach of someone below it.
func test_reach_is_measured_in_three_dimensions() -> void:
	_mushroom_at(Vector3(0.0, 4.0, 0.0))
	assert_null(_picker_at(Vector3.ZERO).find_target())


func test_pressing_the_key_picks_it_up() -> void:
	var mushroom := _mushroom_at(Vector3(1.0, 0.0, 0.0))
	var router := _picker_at(Vector3.ZERO)

	_press_interact(router)
	assert_eq(_bag_of(router).count_of(&"mushroom"), 1, "it did not go in the bag")
	assert_true(mushroom.is_queued_for_deletion(), "the mushroom is still standing there")


func test_walking_past_without_pressing_takes_nothing() -> void:
	_mushroom_at(Vector3(1.0, 0.0, 0.0))
	var router := _picker_at(Vector3.ZERO)

	for _frame in 10:
		router.step()
	assert_eq(_bag_of(router).count_of(&"mushroom"), 0, "it picked itself up")


## Holding F must not clear a whole patch. Same rising edge as jumping.
func test_holding_the_key_picks_up_once() -> void:
	_mushroom_at(Vector3(0.5, 0.0, 0.0))
	_mushroom_at(Vector3(0.7, 0.0, 0.0))
	var router := _picker_at(Vector3.ZERO)

	var source := router
	(router.input_source as ScriptedInputSource).interact(true)
	for _frame in 20:
		router.step()
	assert_eq(_bag_of(router).count_of(&"mushroom"), 1, "a held key emptied the patch")


func test_picking_two_up_stacks_them() -> void:
	_mushroom_at(Vector3(0.5, 0.0, 0.0))
	_mushroom_at(Vector3(0.7, 0.0, 0.0))
	var router := _picker_at(Vector3.ZERO)

	_press_interact(router)
	_press_interact(router)
	assert_eq(_bag_of(router).count_of(&"mushroom"), 2)
	assert_eq(
		_bag_of(router).inventory().filled_slots().size(), 1, "two mushrooms took two slots"
	)


## An item that vanishes because you were full is worse than one you could not
## pick up.
func test_a_full_bag_leaves_it_on_the_ground() -> void:
	var mushroom := _mushroom_at(Vector3(1.0, 0.0, 0.0))
	var router := _picker_at(Vector3.ZERO)
	var pickup: PickupComponent = mushroom.get_node("Pickup")

	# One slot, already full of something else.
	_bag_of(router).capacity = 1
	var other := ItemDefinition.new()
	other.id = &"stone"
	other.max_stack = 1
	_bag_of(router).collect(other, 1)

	var refused: Array[StringName] = []
	_bag_of(router).rejected.connect(
		func(d: ItemDefinition, _n: int) -> void: refused.append(d.id)
	)

	_press_interact(router)
	assert_eq(_bag_of(router).count_of(&"mushroom"), 0)
	assert_false(mushroom.is_queued_for_deletion(), "a full bag deleted the mushroom")
	assert_true(pickup.is_available(), "it is no longer pickable")
	assert_eq(refused, [&"mushroom"] as Array[StringName], "it refused silently")


func test_it_announces_what_is_in_reach() -> void:
	var router := _picker_at(Vector3.ZERO)
	var seen: Array[String] = []
	router.target_changed.connect(
		func(t: InteractableComponent) -> void:
			seen.append("none" if t == null else t.prompt_text())
	)

	router.step()
	assert_eq(router.target(), null, "it found something in an empty world")

	_mushroom_at(Vector3(1.0, 0.0, 0.0))
	router.step()
	assert_not_null(router.target(), "it did not notice the mushroom")
	assert_eq(seen.size(), 1)
	assert_true(seen[0].contains("Mushroom"), "the prompt read '%s'" % seen[0])

	# Steady state: the same target must not be announced every frame.
	router.step()
	router.step()
	assert_eq(seen.size(), 1, "it re-announced an unchanged target %d times" % seen.size())


func test_the_prompt_says_what_it_is() -> void:
	var interactable: InteractableComponent = _mushroom_at(Vector3.ZERO).get_node("Interactable")
	assert_true(
		interactable.prompt_text().contains("Mushroom"), "the prompt does not name the item"
	)


## Assembly: without all of these F does nothing and no test above would notice.
func test_the_player_is_assembled_to_pick_things_up() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)

	var router: InteractionRouter = world.get_node_or_null("Player/Router")
	assert_not_null(router, "nothing owns the interact key")
	assert_eq(router.body, world.get_node("Player"), "reach is measured from the wrong place")
	assert_not_null(
		world.get_node_or_null("Player/Inventory"), "there is nowhere to put what is picked up"
	)
	assert_not_null(
		router.input_source, "nothing gave the router an input source, so F does nothing"
	)
