extends TestCase
## Making soup: the recipe, the bench, and what happens when you cannot.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const RECIPE_PATH: String = "res://resources/recipes/mushroom_soup.tres"
const MUSHROOM_PATH: String = "res://resources/items/mushroom.tres"
const SOUP_PATH: String = "res://resources/items/soup.tres"

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


func _recipe() -> Recipe:
	return load(RECIPE_PATH)


func _bag_with(mushrooms: int, capacity: int = 10) -> Inventory:
	var bag := Inventory.new(capacity)
	if mushrooms > 0:
		bag.add(load(MUSHROOM_PATH), mushrooms)
	return bag


func test_the_soup_item_is_usable() -> void:
	var soup: ItemDefinition = load(SOUP_PATH)
	assert_not_null(soup, "%s is missing or malformed" % SOUP_PATH)
	assert_true(soup.is_valid())
	assert_eq(soup.id, &"mushroom_soup")
	assert_not_null(soup.icon, "soup has no icon, so a cell would be a blank swatch")
	assert_true(soup.can_drop(), "soup can be made but never put down")


func test_the_recipe_loads_and_makes_sense() -> void:
	var recipe := _recipe()
	assert_not_null(recipe, "%s is missing or malformed" % RECIPE_PATH)
	assert_true(recipe.is_valid(), "the recipe is not usable")
	assert_eq(recipe.output.id, &"mushroom_soup")
	assert_eq(recipe.ingredients.size(), 1)
	assert_eq(recipe.ingredients[0].item.id, &"mushroom")
	assert_true(recipe.ingredients[0].count > 1, "one mushroom for one soup is not a recipe")


func test_enough_mushrooms_make_soup() -> void:
	var recipe := _recipe()
	var needed: int = recipe.ingredients[0].count
	var bag := _bag_with(needed)

	assert_true(recipe.can_craft(bag))
	assert_eq(recipe.craft(bag), recipe.output_count)
	assert_eq(bag.count_of(&"mushroom"), 0, "it did not eat the mushrooms")
	assert_eq(bag.count_of(&"mushroom_soup"), recipe.output_count)


func test_too_few_mushrooms_make_nothing() -> void:
	var recipe := _recipe()
	var bag := _bag_with(recipe.ingredients[0].count - 1)

	assert_false(recipe.can_craft(bag), "it would craft without the ingredients")
	assert_eq(recipe.craft(bag), 0)
	assert_eq(
		bag.count_of(&"mushroom"),
		recipe.ingredients[0].count - 1,
		"a failed craft ate the ingredients"
	)


## The worst bug this system could have: taking the mushrooms and then finding
## nowhere to put the soup. All or nothing.
func test_a_failed_craft_changes_nothing() -> void:
	var recipe := _recipe()
	var bag := Inventory.new(1)
	var stone := ItemDefinition.new()
	stone.id = &"stone"
	stone.max_stack = 1
	bag.add(stone, 1)

	assert_eq(recipe.craft(bag), 0, "it crafted into a full bag")
	assert_eq(bag.count_of(&"stone"), 1, "the craft ate something it should not have")


## The ingredients usually free the room the result needs, so refusing to make
## soup in a full bag when the soup replaces the mushrooms would be a rule
## nobody could work out.
func test_a_full_bag_still_crafts_when_the_ingredients_free_the_slot() -> void:
	var recipe := _recipe()
	var needed: int = recipe.ingredients[0].count
	var bag := Inventory.new(1)
	bag.add(load(MUSHROOM_PATH), needed)

	assert_true(bag.has_room_for(load(SOUP_PATH), 1) == false, "the bag is not actually full")
	assert_true(recipe.can_craft(bag), "it refused a craft that frees its own slot")
	assert_eq(recipe.craft(bag), 1)
	assert_eq(bag.count_of(&"mushroom_soup"), 1)


func test_leftovers_stay_in_the_bag() -> void:
	var recipe := _recipe()
	var bag := _bag_with(recipe.ingredients[0].count + 2)
	recipe.craft(bag)
	assert_eq(bag.count_of(&"mushroom"), 2, "it took more than the recipe asked for")


func test_the_summary_names_both_ends() -> void:
	var summary := _recipe().summary()
	assert_true(summary.contains("Mushroom"), "the recipe does not say what it needs")
	assert_true(summary.contains("Soup"), "the recipe does not say what it makes")


func _bench_and_bag(mushrooms: int) -> Array:
	var bench_scene: Node3D = load("res://world/workbench.tscn").instantiate()
	_mount(bench_scene)
	var bench: WorkbenchComponent = bench_scene.get_node("Bench")

	var inventory := InventoryComponent.new()
	_mount(inventory)
	if mushrooms > 0:
		inventory.collect(load(MUSHROOM_PATH), mushrooms)
	return [bench, inventory]


func test_the_bench_scene_carries_the_recipe() -> void:
	var pair := _bench_and_bag(0)
	var bench: WorkbenchComponent = pair[0]
	assert_eq(bench.recipes.size(), 1, "the bench makes nothing")
	assert_eq(bench.recipes[0].id, &"mushroom_soup")
	assert_true(bench.is_in_group(WorkbenchComponent.GROUP), "nothing will ever find it")
	assert_true(bench.is_available())


func test_the_bench_makes_soup() -> void:
	var pair := _bench_and_bag(4)
	var bench: WorkbenchComponent = pair[0]
	var inventory: InventoryComponent = pair[1]

	assert_eq(bench.craft(bench.recipes[0], inventory), 1)
	assert_eq(inventory.count_of(&"mushroom_soup"), 1)
	assert_eq(inventory.count_of(&"mushroom"), 1)


## A bag that changed without saying so is a UI showing yesterday's items.
func test_crafting_announces_the_change() -> void:
	var pair := _bench_and_bag(4)
	var inventory: InventoryComponent = pair[1]
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)

	(pair[0] as WorkbenchComponent).craft((pair[0] as WorkbenchComponent).recipes[0], inventory)
	assert_true(changes[0] > 0, "the bag changed silently")


## It should say why rather than doing nothing, which is indistinguishable from
## being broken.
func test_the_bench_says_why_it_refused() -> void:
	var pair := _bench_and_bag(1)
	var bench: WorkbenchComponent = pair[0]
	var reasons: Array[String] = []
	bench.refused.connect(func(_r: Recipe, why: String) -> void: reasons.append(why))

	assert_eq(bench.craft(bench.recipes[0], pair[1]), 0)
	assert_eq(reasons.size(), 1, "it refused silently")
	assert_true(reasons[0].length() > 0)


func test_a_bench_will_not_make_a_recipe_it_does_not_have() -> void:
	var pair := _bench_and_bag(9)
	var bench: WorkbenchComponent = pair[0]
	var foreign := Recipe.new()
	foreign.id = &"cake"
	assert_eq(bench.craft(foreign, pair[1]), 0, "the bench made something it does not know")


func test_available_recipes_follows_the_bag() -> void:
	var pair := _bench_and_bag(0)
	var bench: WorkbenchComponent = pair[0]
	var inventory: InventoryComponent = pair[1]

	assert_eq(bench.available_recipes(inventory).size(), 0, "it can craft with an empty bag")
	inventory.collect(load(MUSHROOM_PATH), 5)
	assert_eq(bench.available_recipes(inventory).size(), 1, "it cannot craft with the ingredients")
