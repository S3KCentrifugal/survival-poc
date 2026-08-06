extends TestCase
## Putting things back on the ground: where they land, what happens to the bag,
## and that a dropped stack can be picked up again.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MUSHROOM_PATH: String = "res://resources/items/mushroom.tres"


## A body facing -Z with a dropper on it and nothing else around.
func _dropper_at(where: Vector3) -> ItemDropper:
	var container := Node3D.new()
	mount(container)
	var body := Node3D.new()
	container.add_child(body)
	body.global_position = where

	var dropper := ItemDropper.new()
	dropper.body = body
	dropper.container = container
	body.add_child(dropper)
	return dropper


func test_it_lands_in_front_of_you_and_within_reach() -> void:
	var dropper := _dropper_at(Vector3.ZERO)
	var where := dropper.landing_point()

	assert_true(where.z < 0.0, "it landed behind or beside the player, at %v" % where)
	assert_true(
		where.distance_to(Vector3.ZERO) <= 2.2,
		"it landed %f m away, outside a collector's reach" % where.length()
	)


## An item you drop and cannot pick back up is a hole in the floor.
func test_a_dropped_stack_is_immediately_pickable_again() -> void:
	var dropper := _dropper_at(Vector3.ZERO)
	var item := dropper.drop(load(MUSHROOM_PATH), 6)
	assert_not_null(item, "nothing landed")

	var body := Node3D.new()
	mount(body)
	var router := InteractionRouter.new()
	router.body = body
	body.add_child(router)

	var found := router.find_target()
	assert_not_null(found, "the dropped stack is out of reach")
	var pickup: PickupComponent = found.get_parent().get_node("Pickup")
	assert_eq(pickup.amount, 6, "it landed as %d rather than the six dropped" % pickup.amount)


## Twenty mushrooms dropped as twenty nodes is a pile you press F at twenty
## times.
func test_a_whole_stack_lands_as_one_pickup() -> void:
	var dropper := _dropper_at(Vector3.ZERO)
	var item := dropper.drop(load(MUSHROOM_PATH), 12)
	var pickup: PickupComponent = item.get_node("Pickup")

	assert_eq(pickup.amount, 12)
	var interactable: InteractableComponent = item.get_node("Interactable")
	assert_true(
		interactable.prompt_text().contains("12"), "the prompt hides how many there are"
	)


## Something you put down is already there. Watching it sprout would read as
## having planted it.
func test_a_dropped_mushroom_does_not_sprout() -> void:
	var dropper := _dropper_at(Vector3.ZERO)
	var item := dropper.drop(load(MUSHROOM_PATH), 1)
	assert_eq((item as MushroomGrowth).maturity(), 1.0, "the dropped mushroom was a seedling")


## Parented to the world, never the actor: an item parented to a character
## follows them around, which is not what putting something down means.
func test_it_is_not_parented_to_the_person_dropping_it() -> void:
	var dropper := _dropper_at(Vector3.ZERO)
	var item := dropper.drop(load(MUSHROOM_PATH), 1)
	assert_false(dropper.body.is_ancestor_of(item), "the dropped item is carried")


func test_an_item_with_no_world_form_does_not_drop() -> void:
	var dropper := _dropper_at(Vector3.ZERO)
	var idea := ItemDefinition.new()
	idea.id = &"idea"
	assert_null(dropper.drop(idea, 1), "an item with no scene produced one")
	assert_null(dropper.drop(load(MUSHROOM_PATH), 0), "dropping zero produced something")


func test_it_lands_on_the_ground_rather_than_at_sea_level() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var dropper: ItemDropper = world.get_node("Player/Dropper")
	var terrain: Terrain = world.get_node("Terrain")
	assert_eq(dropper.terrain, terrain, "the world did not give the dropper its terrain")

	var item := dropper.drop(load(MUSHROOM_PATH), 1)
	var ground := terrain.height_at_world(item.global_position)
	assert_true(
		absf(item.global_position.y - ground) < 0.1,
		"it landed %f m off the ground" % (item.global_position.y - ground)
	)


## The whole round trip, in the assembled world.
func test_dropping_from_the_screen_empties_the_slot_and_fills_the_world() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var screen: InventoryScreen = world.get_node("InventoryScreen")
	var inventory: InventoryComponent = world.get_node("Player/Inventory")
	inventory.collect(load(MUSHROOM_PATH), 4)

	assert_eq(screen.drop_to_world(0), 4, "nothing was dropped")
	assert_eq(inventory.count_of(&"mushroom"), 0, "the bag kept a copy")
	assert_eq(screen.cell_text(0), "", "the cell still shows the dropped stack")


## Nothing leaves the bag until it is standing in the world. A stack removed
## first and then failed to spawn is a stack that exists nowhere.
func test_a_failed_drop_keeps_the_items() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var screen: InventoryScreen = world.get_node("InventoryScreen")
	var inventory: InventoryComponent = world.get_node("Player/Inventory")

	var idea := ItemDefinition.new()
	idea.id = &"idea"
	idea.max_stack = 5
	inventory.collect(idea, 3)

	assert_eq(screen.drop_to_world(0), 0, "an item with no world form was dropped")
	assert_eq(inventory.count_of(&"idea"), 3, "the bag lost items that never landed")


func test_dropping_an_empty_slot_does_nothing() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	assert_eq((world.get_node("InventoryScreen") as InventoryScreen).drop_to_world(3), 0)


func test_the_player_is_assembled_to_drop_things() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var dropper: ItemDropper = world.get_node_or_null("Player/Dropper")
	assert_not_null(dropper, "the player cannot put anything down")
	assert_eq(dropper.body, world.get_node("Player"))
	assert_not_null(dropper.container, "dropped items would have nowhere to go")
	assert_eq(
		(world.get_node("InventoryScreen") as InventoryScreen).dropper,
		dropper,
		"the screen cannot drop anything"
	)
