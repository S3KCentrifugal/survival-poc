extends TestCase
## The bag on screen: the key, what the cells say, and what it must not do.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const SCREEN_SCENE: String = "res://ui/inventory_screen.tscn"


func after_each() -> void:
	# A suite that leaves the tree paused takes every later one with it.
	(Engine.get_main_loop() as SceneTree).paused = false


func _screen() -> InventoryScreen:
	var screen: InventoryScreen = load(SCREEN_SCENE).instantiate()
	var inventory := InventoryComponent.new()
	inventory.capacity = 6
	screen.add_child(inventory)
	screen.inventory = inventory
	mount(screen)
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
	mount(world)

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
	mount(world)

	var player: Node3D = world.get_node("Player")
	var collector: PickupCollector = world.get_node("Player/Collector")
	var patch: MushroomPatch = world.get_node("Mushrooms")
	var screen: InventoryScreen = world.get_node("InventoryScreen")

	# Stand one right next to the player rather than walking there.
	var mushroom := patch.mushrooms()[0]
	mushroom.global_position = player.global_position + Vector3(0.6, 0.0, 0.0)

	assert_eq(collector.collect(), 1, "F picked up nothing")
	assert_eq(screen.cell_text(0), "1", "the bag on screen says '%s'" % screen.cell_text(0))


func _mushroom() -> ItemDefinition:
	return load("res://resources/items/mushroom.tres")


## The two settings that make an icon of any size look right in a cell of any
## size. Without KEEP_ASPECT_CENTERED a tall icon is squashed into the square;
## without IGNORE_SIZE a 512-pixel icon makes the cell 512 pixels wide and the
## grid runs off the screen.
func test_icons_scale_to_the_cell_and_keep_their_shape() -> void:
	var screen := _screen()
	screen.inventory.collect(_mushroom(), 1)
	var icon: TextureRect = screen.cell(0).get_node("Stack/Frame/Icon")

	assert_eq(icon.expand_mode, TextureRect.EXPAND_IGNORE_SIZE, "the icon sizes the cell")
	assert_eq(
		icon.stretch_mode,
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"the icon is stretched out of shape"
	)


func test_a_cell_shows_the_item_icon() -> void:
	var screen := _screen()
	screen.inventory.collect(_mushroom(), 1)
	assert_not_null(screen.cell(0).icon(), "the cell drew no icon")
	assert_eq(screen.cell(0).icon(), _mushroom().icon)


## An 84-pixel cell must not be forced wider by the art inside it.
func test_a_cell_stays_the_size_it_asked_for() -> void:
	var screen := _screen()
	screen.inventory.collect(_mushroom(), 1)
	assert_eq(screen.cell(0).custom_minimum_size, Vector2(84, 84))


func test_emptying_a_cell_clears_its_icon() -> void:
	var screen := _screen()
	screen.inventory.collect(_mushroom(), 1)
	screen.inventory.drop(&"mushroom", 1)
	assert_null(screen.cell(0).icon(), "the icon outlived the item")
	assert_true(screen.cell(0).is_empty())


## Counts are for things that stack. A "1" under an item you can only hold one
## of is a number that never changes.
func test_stackable_items_show_their_count() -> void:
	var screen := _screen()
	screen.inventory.collect(_item(&"mushroom", 20), 1)
	assert_eq(screen.cell_text(0), "1", "a stackable item hid its count")

	screen.inventory.collect(_item(&"mushroom", 20), 6)
	assert_eq(screen.cell_text(0), "7")


func test_an_item_that_does_not_stack_shows_no_count() -> void:
	var screen := _screen()
	screen.inventory.collect(_item(&"sword", 1), 1)
	assert_eq(screen.cell_text(0), "", "a one-of-a-kind item was labelled '1'")


## An empty cell must not offer a drag, or you can pick up nothing and drop it
## somewhere.
func test_an_empty_cell_cannot_be_dragged() -> void:
	var screen := _screen()
	assert_null(screen.cell(0).drag_payload())


func test_a_filled_cell_hands_over_its_index() -> void:
	var screen := _screen()
	screen.inventory.collect(_mushroom(), 2)
	var payload: Dictionary = screen.cell(0).drag_payload()
	assert_eq(payload.get("index"), 0)
	assert_true(InventoryCell.is_inventory_drag(payload))


## A file dragged in from the desktop is not a mushroom.
func test_a_foreign_payload_is_refused() -> void:
	var screen := _screen()
	assert_false(InventoryCell.is_inventory_drag({"files": ["/tmp/thing.png"]}))
	assert_false(screen.cell(0)._can_drop_data(Vector2.ZERO, "some string"))


func test_dragging_one_cell_onto_another_moves_the_stack() -> void:
	var screen := _screen()
	screen.inventory.collect(_mushroom(), 3)

	screen.cell(2)._drop_data(Vector2.ZERO, {"source": &"inventory", "index": 0})
	assert_eq(screen.cell_text(0), "", "it left a copy in the old slot")
	assert_eq(screen.cell_text(2), "3", "the stack did not arrive")


## Dropping outside the panel is what puts a stack on the ground, so the zone
## has to accept the drag rather than ignore the mouse.
func test_the_area_outside_the_panel_takes_a_drop() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var screen: InventoryScreen = world.get_node("InventoryScreen")
	var inventory: InventoryComponent = world.get_node("Player/Inventory")
	inventory.collect(_mushroom(), 2)

	assert_not_null(screen.drop_zone, "there is nowhere to drag a stack out to")
	assert_eq(
		screen.drop_zone.mouse_filter,
		Control.MOUSE_FILTER_STOP,
		"the drop zone ignores the mouse, so a drag out of the panel goes nowhere"
	)
	assert_true(screen._can_drop_outside(Vector2.ZERO, {"source": &"inventory", "index": 0}))

	screen._dropped_outside(Vector2.ZERO, {"source": &"inventory", "index": 0})
	assert_eq(inventory.count_of(&"mushroom"), 0, "the stack is still in the bag")


## The cursor should say no rather than swallowing something that cannot be put
## down.
func test_dragging_out_an_item_with_no_world_form_is_refused() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var screen: InventoryScreen = world.get_node("InventoryScreen")
	var idea := _item(&"idea")
	(world.get_node("Player/Inventory") as InventoryComponent).collect(idea, 1)

	assert_false(screen._can_drop_outside(Vector2.ZERO, {"source": &"inventory", "index": 0}))


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


## Same fault as the shop and the bench: escape reaches the pause menu first,
## because `_unhandled_input` runs in reverse tree order and the menu is later
## in the scene. An open panel must win its own close key.
func test_escape_closes_the_bag_without_opening_the_pause_menu() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var screen: InventoryScreen = world.get_node("InventoryScreen")
	var pause: PauseMenu = world.get_node("PauseMenu")
	screen.set_open(true)

	world.get_tree().root.push_input(_key_event(KEY_ESCAPE))

	assert_false(screen.is_open(), "escape did not close the bag")
	assert_false(pause.visible, "escape opened the pause menu over the bag")
	assert_false((Engine.get_main_loop() as SceneTree).paused)


## And the pause menu still works when nothing else is open, which is the thing
## a fix like this is most likely to break.
func test_escape_still_opens_the_pause_menu_with_no_panel_open() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var pause: PauseMenu = world.get_node("PauseMenu")

	world.get_tree().root.push_input(_key_event(KEY_ESCAPE))
	assert_true(pause.visible, "escape no longer opens the pause menu")
	pause.set_open(false)
