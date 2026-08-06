extends TestCase
## Walking up to the bench and using it: reach, the key, and the panel.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MUSHROOM_PATH: String = "res://resources/items/mushroom.tres"


func after_each() -> void:
	(Engine.get_main_loop() as SceneTree).paused = false


func _bench_at(where: Vector3) -> WorkbenchComponent:
	var scene: Node3D = load("res://world/workbench.tscn").instantiate()
	mount(scene)
	scene.global_position = where
	return scene.get_node("Bench")


func _interactor_at(where: Vector3) -> Interactor:
	var body := Node3D.new()
	mount(body)
	body.global_position = where

	var interactor := Interactor.new()
	interactor.body = body
	interactor.input_source = ScriptedInputSource.new()
	body.add_child(interactor)
	return interactor


func _press_use(interactor: Interactor) -> void:
	var source: ScriptedInputSource = interactor.input_source
	source.use(false)
	interactor.step()
	source.use(true)
	interactor.step()


func test_the_key_is_bound() -> void:
	assert_true(
		InputMap.has_action(PlayerInputSource.ACTION_USE),
		"the use action is not in the InputMap, so no key opens the bench"
	)


## Two verbs, two keys. F takes a thing away, E operates a thing that stays --
## folding both behind one key means deciding what a press means when a mushroom
## is growing next to the bench.
func test_use_and_interact_are_different_actions() -> void:
	assert_false(
		PlayerInputSource.ACTION_USE == PlayerInputSource.ACTION_INTERACT,
		"picking up and using are the same key"
	)


func test_the_bench_is_found_when_you_stand_near_it() -> void:
	_bench_at(Vector3(1.5, 0.0, 0.0))
	var interactor := _interactor_at(Vector3.ZERO)
	interactor.step()
	assert_not_null(interactor.target(), "the bench is right there and was not found")


func test_a_bench_across_the_room_is_not_in_reach() -> void:
	_bench_at(Vector3(6.0, 0.0, 0.0))
	var interactor := _interactor_at(Vector3.ZERO)
	interactor.step()
	assert_null(interactor.target(), "it reached a bench six metres away")


func test_pressing_the_key_uses_it() -> void:
	var bench := _bench_at(Vector3(1.2, 0.0, 0.0))
	var interactor := _interactor_at(Vector3.ZERO)
	var uses := [0]
	bench.used.connect(func(_by: Node) -> void: uses[0] += 1)

	_press_use(interactor)
	assert_eq(uses[0], 1, "the bench was used %d times" % uses[0])


## Holding the key must not open and close the panel sixty times a second.
func test_holding_the_key_uses_it_once() -> void:
	var bench := _bench_at(Vector3(1.2, 0.0, 0.0))
	var interactor := _interactor_at(Vector3.ZERO)
	var uses := [0]
	bench.used.connect(func(_by: Node) -> void: uses[0] += 1)

	(interactor.input_source as ScriptedInputSource).use(true)
	for _frame in 20:
		interactor.step()
	assert_eq(uses[0], 1, "a held key used the bench %d times" % uses[0])


## Same lesson as PickupCollector.collect(): a method whose docstring says "uses
## whatever is in reach" must look, not rely on an earlier step().
func test_using_directly_finds_its_own_target() -> void:
	var bench := _bench_at(Vector3(1.2, 0.0, 0.0))
	var interactor := _interactor_at(Vector3.ZERO)
	var uses := [0]
	bench.used.connect(func(_by: Node) -> void: uses[0] += 1)

	assert_true(interactor.use(), "use() did nothing without a step() first")
	assert_eq(uses[0], 1)


func test_the_prompt_names_the_bench() -> void:
	var bench := _bench_at(Vector3.ZERO)
	assert_true(bench.prompt_text().contains("Workbench"))


func _world() -> Node:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	return world


func test_the_world_has_a_bench_and_a_panel_wired_to_it() -> void:
	var world := _world()
	assert_not_null(world.get_node_or_null("Workbench"), "there is no bench in the world")

	var screen: CraftingScreen = world.get_node_or_null("CraftingScreen")
	assert_not_null(screen, "there is no crafting panel")
	assert_eq(screen.inventory, world.get_node("Player/Inventory"))
	assert_eq(screen.interactor, world.get_node("Player/Interactor"), "nothing would open it")

	var interactor: Interactor = world.get_node("Player/Interactor")
	assert_not_null(interactor.input_source, "nothing gave the interactor an input source")


## The bench has to be inside a building, not out in a field.
func test_the_bench_stands_indoors() -> void:
	var world := _world()
	var bench: Node3D = world.get_node("Workbench")
	var player: Node3D = world.get_node("Player")
	assert_true(
		bench.global_position.distance_to(player.global_position) < 12.0,
		"the bench is %.1f m from where the player wakes up"
			% bench.global_position.distance_to(player.global_position)
	)


func test_the_panel_starts_closed_and_opens_on_use() -> void:
	var world := _world()
	var screen: CraftingScreen = world.get_node("CraftingScreen")
	assert_false(screen.is_open(), "the panel was open before anyone used anything")

	screen.show_bench(world.get_node("Workbench/Bench"))
	assert_true(screen.is_open(), "using the bench did not open the panel")
	assert_eq(screen.bench(), world.get_node("Workbench/Bench"))


## Like the inventory: crafting is something your character does, and in
## multiplayer a bench that stops the world cannot exist.
func test_the_panel_does_not_pause_the_game() -> void:
	var world := _world()
	var screen: CraftingScreen = world.get_node("CraftingScreen")
	screen.show_bench(world.get_node("Workbench/Bench"))
	assert_false((Engine.get_main_loop() as SceneTree).paused, "the bench paused the world")


func test_escape_closes_it() -> void:
	var world := _world()
	var screen: CraftingScreen = world.get_node("CraftingScreen")
	screen.show_bench(world.get_node("Workbench/Bench"))

	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.physical_keycode = KEY_ESCAPE
	key.pressed = true
	world.get_tree().root.push_input(key)
	assert_false(screen.is_open(), "escape did not close the panel")


## The whole loop, in the assembled world: mushrooms in the bag, use the bench,
## press the button, soup.
func test_crafting_from_the_panel_makes_soup() -> void:
	var world := _world()
	var screen: CraftingScreen = world.get_node("CraftingScreen")
	var inventory: InventoryComponent = world.get_node("Player/Inventory")
	inventory.collect(load(MUSHROOM_PATH), 4)

	screen.show_bench(world.get_node("Workbench/Bench"))
	assert_eq(screen.craft(0), 1, "the button made nothing")
	assert_eq(inventory.count_of(&"mushroom_soup"), 1)
	assert_eq(inventory.count_of(&"mushroom"), 1)


func test_the_panel_greys_out_what_cannot_be_made() -> void:
	var world := _world()
	var screen: CraftingScreen = world.get_node("CraftingScreen")
	var inventory: InventoryComponent = world.get_node("Player/Inventory")

	screen.show_bench(world.get_node("Workbench/Bench"))
	var button: Button = screen.rows.get_child(0)
	assert_true(button.disabled, "an impossible recipe was offered as possible")
	assert_true(
		button.tooltip_text.contains("Need"),
		"it does not say what is missing: '%s'" % button.tooltip_text
	)

	inventory.collect(load(MUSHROOM_PATH), 5)
	assert_false(button.disabled, "the recipe is possible and still greyed out")


## A hard-coded height in the scene file was correct for exactly as long as the
## terrain did not change, and then the bench was under the floor with nothing
## to say so. The world drops it, like everything else.
func test_the_bench_stands_on_the_floor() -> void:
	var world := _world()
	var bench: Node3D = world.get_node("Workbench")
	var terrain: Terrain = world.get_node("Terrain")
	var ground := terrain.height_at_world(bench.global_position)

	assert_true(
		absf(bench.global_position.y - ground) < 0.2,
		"the bench sits %.1f m from the floor" % (bench.global_position.y - ground)
	)
	assert_true(
		absf(bench.global_position.y - (world.get_node("Player") as Node3D).global_position.y)
			< 1.5,
		"the bench is on a different level from the player"
	)


## Without a prompt, nothing in the game says E does anything at all.
func test_the_hud_says_what_the_use_key_would_do() -> void:
	var world := _world()
	var hud: PlayerHud = world.get_node("PlayerHud")
	assert_eq(hud.interactor, world.get_node("Player/Interactor"), "the HUD cannot see the bench")

	(world.get_node("Player") as Node3D).global_position = (
		(world.get_node("Workbench") as Node3D).global_position + Vector3(1.0, 0.0, 0.0)
	)
	(world.get_node("Player/Interactor") as Interactor).step()

	assert_true(hud.prompt_label.visible, "standing at the bench showed no prompt")
	assert_true(
		hud.prompt_label.text.contains("[E]"),
		"the prompt reads '%s'" % hud.prompt_label.text
	)


## Both at once when both are in reach. Showing only the nearer one means a
## mushroom by your foot hides the bench.
func test_both_prompts_show_together() -> void:
	var world := _world()
	var hud: PlayerHud = world.get_node("PlayerHud")
	var bench: Node3D = world.get_node("Workbench")
	var player: Node3D = world.get_node("Player")
	player.global_position = bench.global_position + Vector3(1.0, 0.0, 0.0)

	var mushroom: Node3D = load("res://items/mushroom.tscn").instantiate()
	world.add_child(mushroom)
	mushroom.global_position = player.global_position + Vector3(0.4, 0.0, 0.0)

	# The router owns F now, so it is what the prompt asks.
	(world.get_node("Player/Router") as InteractionRouter).step()
	(world.get_node("Player/Interactor") as Interactor).step()

	assert_true(hud.prompt_label.text.contains("[F]"), "the mushroom prompt is missing")
	assert_true(hud.prompt_label.text.contains("[E]"), "the bench prompt is missing")


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


## The bench had the same fault the shop was reported with: escape opened the
## pause menu over the panel instead of closing it, because `_unhandled_input`
## runs in reverse tree order and the menu sits after the panel.
func test_escape_closes_the_bench_without_opening_the_pause_menu() -> void:
	var world := _world()
	var screen: CraftingScreen = world.get_node("CraftingScreen")
	var pause: PauseMenu = world.get_node("PauseMenu")
	screen.show_bench(world.get_node("Workbench/Bench"))

	world.get_tree().root.push_input(_key_event(KEY_ESCAPE))

	assert_false(screen.is_open(), "escape did not close the bench panel")
	assert_false(pause.visible, "escape opened the pause menu over the panel")
	assert_false((Engine.get_main_loop() as SceneTree).paused)


func test_the_use_key_closes_the_bench() -> void:
	var world := _world()
	var screen: CraftingScreen = world.get_node("CraftingScreen")
	screen.show_bench(world.get_node("Workbench/Bench"))

	world.get_tree().root.push_input(_key_event(KEY_E))
	assert_false(screen.is_open(), "E did not close the bench panel")
