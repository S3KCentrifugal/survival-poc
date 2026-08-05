extends TestCase
## The bag on screen: the key, what the cells say, and what it must not do.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const SCREEN_SCENE: String = "res://ui/inventory_screen.tscn"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()
	# A suite that leaves the tree paused takes every later one with it.
	(Engine.get_main_loop() as SceneTree).paused = false


func _mount(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_mounted.append(node)
	return node


func _screen() -> InventoryScreen:
	var screen: InventoryScreen = load(SCREEN_SCENE).instantiate()
	var inventory := InventoryComponent.new()
	inventory.capacity = 6
	screen.add_child(inventory)
	screen.inventory = inventory
	_mount(screen)
	return screen


func _item(id: StringName, max_stack: int = 20) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.id = id
	definition.display_name = String(id).capitalize()
	definition.max_stack = max_stack
	return definition


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_it_starts_closed() -> void:
	assert_false(_screen().visible, "the bag was open before anyone asked")


func test_i_opens_and_closes_it() -> void:
	var screen := _screen()
	screen._unhandled_input(_key(KEY_I))
	assert_true(screen.is_open(), "I did not open the bag")
	screen._unhandled_input(_key(KEY_I))
	assert_false(screen.is_open(), "I did not close the bag")


func test_another_key_does_nothing() -> void:
	var screen := _screen()
	screen._unhandled_input(_key(KEY_K))
	assert_false(screen.is_open())


## The pause menu pauses because it is a menu about the game. This is a screen
## about your character, and in multiplayer a bag that stops the world cannot
## exist.
func test_opening_the_bag_does_not_pause_the_game() -> void:
	var screen := _screen()
	screen.set_open(true)
	assert_false((Engine.get_main_loop() as SceneTree).paused, "the bag paused the world")


func test_it_keeps_running_while_paused() -> void:
	# Otherwise something else pausing while the bag is open makes it
	# uncloseable.
	assert_eq(_screen().process_mode, Node.PROCESS_MODE_ALWAYS)


func test_there_is_a_cell_for_every_slot() -> void:
	var screen := _screen()
	assert_eq(screen.cell_count(), 6, "the grid does not match the bag")


func test_an_empty_bag_says_so() -> void:
	var screen := _screen()
	assert_true(screen.empty_label.visible, "an empty bag showed no hint")
	assert_eq(screen.cell_text(0), "", "an empty cell showed a number")


func test_a_stack_shows_its_count() -> void:
	var screen := _screen()
	screen.inventory.collect(_item(&"mushroom"), 7)

	assert_eq(screen.cell_text(0), "7", "the cell reads '%s'" % screen.cell_text(0))
	assert_false(screen.empty_label.visible, "it still says the bag is empty")


## Redrawn on the signal, not on open. A bag that only updates when you look at
## it is a bag showing yesterday's items.
func test_picking_something_up_redraws_it_while_it_is_open() -> void:
	var screen := _screen()
	screen.set_open(true)
	screen.inventory.collect(_item(&"mushroom"), 2)
	assert_eq(screen.cell_text(0), "2")

	screen.inventory.collect(_item(&"mushroom"), 3)
	assert_eq(screen.cell_text(0), "5", "the open bag did not follow the pickup")


func test_emptying_a_slot_clears_its_cell() -> void:
	var screen := _screen()
	screen.inventory.collect(_item(&"mushroom"), 2)
	screen.inventory.drop(&"mushroom", 2)
	assert_eq(screen.cell_text(0), "", "the cell still shows what was taken out")


func test_the_world_carries_one_wired_to_the_player() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	_mount(world)

	var screen: InventoryScreen = world.get_node_or_null("InventoryScreen")
	assert_not_null(screen, "there is no inventory screen in the world")
	assert_eq(
		screen.inventory,
		world.get_node("Player/Inventory"),
		"the screen is not showing the player's bag"
	)
	assert_eq(screen.world_root, world, "it cannot give the cursor back")


## The whole loop, in the assembled world: walk up, press F, and see it.
func test_a_picked_mushroom_shows_up_in_the_screen() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	_mount(world)

	var player: Node3D = world.get_node("Player")
	var collector: PickupCollector = world.get_node("Player/Collector")
	var patch: MushroomPatch = world.get_node("Mushrooms")
	var screen: InventoryScreen = world.get_node("InventoryScreen")

	# Stand one right next to the player rather than walking there.
	var mushroom := patch.mushrooms()[0]
	mushroom.global_position = player.global_position + Vector3(0.6, 0.0, 0.0)

	assert_eq(collector.collect(), 1, "F picked up nothing")
	assert_eq(screen.cell_text(0), "1", "the bag on screen says '%s'" % screen.cell_text(0))
