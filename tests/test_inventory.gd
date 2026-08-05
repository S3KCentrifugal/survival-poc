extends TestCase
## Stacking, overflow, and taking things back out.
##
## All of it without a node: [Inventory] is a [RefCounted], which is what lets
## "a pickup that only half fits" be a number rather than something you find out
## by filling a bag in the running game.

const MUSHROOM_PATH: String = "res://resources/items/mushroom.tres"


## A definition of our own, so a test cannot change the real mushroom for
## everything else. The shared-resource trap has caught this project four times.
func _item(id: StringName, max_stack: int = 20) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = id
	definition.display_name = String(id)
	definition.max_stack = max_stack
	return definition


func test_the_mushroom_definition_is_usable() -> void:
	var mushroom: ItemDefinition = load(MUSHROOM_PATH)
	assert_not_null(mushroom, "%s is missing or malformed" % MUSHROOM_PATH)
	assert_true(mushroom.is_valid(), "the mushroom cannot be saved or networked")
	assert_eq(mushroom.id, &"mushroom")
	assert_true(mushroom.max_stack > 1, "mushrooms would not stack")


## An id is what a save file remembers, so an item without one is not an item.
func test_an_item_with_no_id_is_not_valid() -> void:
	var nameless := ItemDefinition.new()
	assert_false(nameless.is_valid())
	assert_eq(Inventory.new(4).add(nameless, 3), 3, "a nameless item went into a bag")


func test_a_new_bag_is_empty_and_the_right_size() -> void:
	var bag := Inventory.new(8)
	assert_eq(bag.size(), 8)
	assert_true(bag.is_empty())
	assert_eq(bag.filled_slots().size(), 0)


func test_one_item_goes_in() -> void:
	var bag := Inventory.new(4)
	assert_eq(bag.add(_item(&"mushroom"), 1), 0, "it did not fit in an empty bag")
	assert_eq(bag.count_of(&"mushroom"), 1)
	assert_false(bag.is_empty())


## The whole point of stacking: twelve mushrooms are one slot, not twelve.
func test_the_same_item_stacks_into_one_slot() -> void:
	var bag := Inventory.new(10)
	var mushroom := _item(&"mushroom", 20)
	for _picked in 12:
		bag.add(mushroom, 1)

	assert_eq(bag.count_of(&"mushroom"), 12)
	assert_eq(bag.filled_slots().size(), 1, "twelve mushrooms took more than one slot")


## Partial stacks are topped up before a fresh slot is opened. Without this,
## picking things up one at a time fills the bag with air.
func test_a_partial_stack_is_topped_up_first() -> void:
	var bag := Inventory.new(6)
	var mushroom := _item(&"mushroom", 5)
	bag.add(mushroom, 5)
	bag.add(mushroom, 2)
	bag.add(mushroom, 1)

	assert_eq(bag.filled_slots().size(), 2, "it opened a slot with room still going spare")
	assert_eq(bag.slot(0).count, 5)
	assert_eq(bag.slot(1).count, 3)


func test_a_full_stack_overflows_into_the_next_slot() -> void:
	var bag := Inventory.new(4)
	assert_eq(bag.add(_item(&"mushroom", 5), 12), 0, "twelve did not fit in four slots of five")
	assert_eq(bag.count_of(&"mushroom"), 12)
	assert_eq(bag.slot(0).count, 5)
	assert_eq(bag.slot(1).count, 5)
	assert_eq(bag.slot(2).count, 2)


## Different items never share a slot, however much room is left.
func test_different_items_do_not_stack_together() -> void:
	var bag := Inventory.new(4)
	bag.add(_item(&"mushroom", 20), 1)
	bag.add(_item(&"berry", 20), 1)
	assert_eq(bag.filled_slots().size(), 2, "two kinds of thing shared one slot")


## The number that matters: a pickup that only half fits must leave the rest
## behind rather than deleting it.
func test_what_does_not_fit_comes_back() -> void:
	var bag := Inventory.new(2)
	var mushroom := _item(&"mushroom", 5)
	assert_eq(bag.add(mushroom, 14), 4, "a bag holding ten swallowed fourteen")
	assert_eq(bag.count_of(&"mushroom"), 10)

	assert_eq(bag.add(mushroom, 3), 3, "a full bag took more")
	assert_eq(bag.count_of(&"mushroom"), 10, "a full bag grew")


func test_it_knows_whether_something_will_fit() -> void:
	var bag := Inventory.new(2)
	var mushroom := _item(&"mushroom", 5)
	assert_true(bag.has_room_for(mushroom, 10))
	assert_false(bag.has_room_for(mushroom, 11))

	bag.add(mushroom, 8)
	assert_true(bag.has_room_for(mushroom, 2))
	assert_false(bag.has_room_for(mushroom, 3))


func test_taking_things_out() -> void:
	var bag := Inventory.new(4)
	bag.add(_item(&"mushroom", 5), 8)

	assert_eq(bag.remove(&"mushroom", 3), 3)
	assert_eq(bag.count_of(&"mushroom"), 5)
	assert_eq(bag.remove(&"mushroom", 99), 5, "it should hand back only what it had")
	assert_true(bag.is_empty())
	assert_eq(bag.remove(&"mushroom", 1), 0, "an empty bag produced an item")


## Smallest stacks first, so using things closes half-empty slots rather than
## multiplying them.
func test_removing_drains_the_smallest_stack_first() -> void:
	var bag := Inventory.new(4)
	var mushroom := _item(&"mushroom", 5)
	bag.add(mushroom, 7)
	assert_eq(bag.slot(1).count, 2)

	bag.remove(&"mushroom", 2)
	assert_eq(bag.filled_slots().size(), 1, "it left two partial stacks behind")
	assert_eq(bag.slot(0).count, 5)


## An emptied slot stays where it was. Items sliding around the grid whenever
## you use one is infuriating in a way that is hard to argue with afterwards.
func test_an_emptied_slot_does_not_close_up() -> void:
	var bag := Inventory.new(4)
	bag.add(_item(&"mushroom", 5), 1)
	bag.add(_item(&"berry", 5), 1)
	bag.remove(&"mushroom", 1)

	assert_true(bag.slot(0).is_empty(), "the second item slid into the first slot")
	assert_eq(bag.slot(1).definition.id, &"berry")


func test_asking_for_a_slot_that_is_not_there() -> void:
	var bag := Inventory.new(2)
	assert_null(bag.slot(-1))
	assert_null(bag.slot(9))


func test_the_component_reports_what_it_took() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var component := InventoryComponent.new()
	component.capacity = 1
	tree.root.add_child(component)

	var taken: Array[int] = []
	var refused: Array[int] = []
	component.collected.connect(func(_d: ItemDefinition, n: int) -> void: taken.append(n))
	component.rejected.connect(func(_d: ItemDefinition, n: int) -> void: refused.append(n))

	var mushroom := _item(&"mushroom", 5)
	assert_eq(component.collect(mushroom, 3), 0)
	assert_eq(taken, [3] as Array[int])
	assert_eq(refused.size(), 0)

	assert_eq(component.collect(mushroom, 4), 2, "a one-slot bag of five took nine")
	assert_eq(taken, [3, 2] as Array[int])
	assert_eq(refused, [2] as Array[int], "it did not say what it turned away")

	component.free()


## A bag that changes without saying so is a UI that shows yesterday's items.
func test_the_component_announces_changes() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var component := InventoryComponent.new()
	tree.root.add_child(component)

	var changes := [0]
	component.changed.connect(func() -> void: changes[0] += 1)

	component.collect(_item(&"mushroom"), 1)
	assert_eq(changes[0], 1)
	component.drop(&"mushroom", 1)
	assert_eq(changes[0], 2)
	component.drop(&"mushroom", 1)
	assert_eq(changes[0], 2, "removing nothing counted as a change")

	component.free()
