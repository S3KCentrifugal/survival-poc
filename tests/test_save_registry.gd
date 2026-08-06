extends TestCase
## The registry a save pass walks, and the duplicate check that is the point of
## having one.


## A component with a fixed id, not in the tree: the registry only ever asks
## for the id.
func _component(id: StringName) -> SaveIdComponent:
	var component := SaveIdComponent.new()
	component.id = id
	mount(component)
	return component


func _registry(ids: Array[StringName]) -> SaveRegistry:
	var components: Array[SaveIdComponent] = []
	for id: StringName in ids:
		components.append(_component(id))
	return SaveRegistry.new(components)


func test_an_empty_registry_holds_nothing() -> void:
	var registry := SaveRegistry.new()
	assert_eq(registry.size(), 0)
	assert_false(registry.has_duplicates())
	assert_null(registry.find(&"player"))


func test_it_indexes_what_it_is_given() -> void:
	var registry := _registry([&"player", &"chest", &"campfire"])
	assert_eq(registry.size(), 3)
	assert_true(registry.has(&"chest"))
	assert_eq(registry.ids(), [&"campfire", &"chest", &"player"] as Array[StringName])


func test_it_finds_an_object_by_id() -> void:
	var player := _component(&"player")
	var registry := SaveRegistry.new([player] as Array[SaveIdComponent])
	assert_eq(registry.find(&"player"), player)


func test_an_unknown_id_finds_nothing() -> void:
	assert_null(_registry([&"player"]).find(&"chest"))


## Not a crash: a save where one object quietly overwrites the other, found by
## a player a week later when their chest is empty.
func test_a_duplicate_id_is_reported_rather_than_swallowed() -> void:
	var registry := _registry([&"chest", &"chest"])
	assert_true(registry.has_duplicates())
	assert_eq(registry.duplicates(), [&"chest"] as Array[StringName])
	assert_eq(registry.size(), 1, "both objects were indexed under one id")


func test_the_first_claim_on_an_id_wins() -> void:
	var first := _component(&"chest")
	var second := _component(&"chest")
	var registry := SaveRegistry.new([first, second] as Array[SaveIdComponent])
	assert_eq(registry.find(&"chest"), first, "the later object displaced the earlier one")


func test_adding_reports_whether_the_id_was_free() -> void:
	var registry := SaveRegistry.new()
	assert_true(registry.add(_component(&"chest")))
	assert_false(registry.add(_component(&"chest")), "a taken id was reported as free")


func test_a_repeated_collision_is_only_listed_once() -> void:
	var registry := _registry([&"chest", &"chest", &"chest"])
	assert_eq(registry.duplicates().size(), 1)


func test_the_duplicate_list_cannot_be_edited_from_outside() -> void:
	var registry := _registry([&"chest", &"chest"])
	registry.duplicates().clear()
	assert_true(registry.has_duplicates(), "a caller emptied the registry's own list")


func test_a_null_component_is_refused_rather_than_indexed() -> void:
	var registry := SaveRegistry.new()
	assert_false(registry.add(null))
	assert_eq(registry.size(), 0)


func test_it_collects_everything_in_the_tree() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world := Node.new()
	world.name = "SaveWorld"
	for id: StringName in [&"one", &"two", &"three"]:
		var holder := Node.new()
		var component := SaveIdComponent.new()
		component.id = id
		holder.add_child(component)
		world.add_child(holder)
	mount(world)

	var registry := SaveRegistry.from_tree(tree())
	for id: StringName in [&"one", &"two", &"three"]:
		assert_true(registry.has(id), "%s was not collected" % id)


func test_the_assembled_world_has_no_duplicate_ids() -> void:
	# The check that matters: a real scene, walked the way a save pass would.
	var world: Node = load("res://scenes/main.tscn").instantiate()
	mount(world)

	var registry := SaveRegistry.from_tree(tree())
	assert_false(registry.has_duplicates(), "duplicate ids: %s" % [registry.duplicates()])
	assert_true(registry.has(&"player"), "the player is not in the registry")
