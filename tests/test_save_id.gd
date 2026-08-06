extends TestCase
## Save identifiers: where an object's name comes from and how stable it is.

const PLAYER_SCENE: String = "res://characters/player.tscn"


## A component under a named parent, mounted so it has a path to derive from.
func _component_under(parent_name: String, id: StringName = &"") -> SaveIdComponent:
	var tree := Engine.get_main_loop() as SceneTree
	var holder := Node.new()
	holder.name = parent_name
	var component := SaveIdComponent.new()
	component.name = "SaveId"
	component.id = id
	holder.add_child(component)
	mount(holder)
	return component


func test_an_authored_id_is_kept() -> void:
	var component := _component_under("Chest", &"starting_chest")
	assert_eq(component.save_key(), &"starting_chest")


func test_the_player_has_an_authored_id() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	mount(player)

	var save_id: SaveIdComponent = player.get_node_or_null("SaveId")
	assert_not_null(save_id, "the player is not addressable by a save file")
	assert_eq(save_id.save_key(), &"player", "the player's id should not be derived")


## The first thing anyone does with an unfamiliar save file is look for
## something they recognise.
func test_a_derived_id_is_readable() -> void:
	var component := _component_under("Boulder")
	var key := String(component.save_key())
	assert_true(key.contains("Boulder"), "derived %s, which names nothing" % key)
	assert_true(key.contains("SaveId"), "derived %s" % key)


func test_a_derived_id_does_not_change_while_the_object_sits_still() -> void:
	var component := _component_under("Boulder")
	var first := component.save_key()
	assert_eq(component.save_key(), first)
	assert_eq(component.derive_id(), first)


func test_two_objects_in_different_places_derive_different_ids() -> void:
	assert_ne(_component_under("BoulderA").save_key(), _component_under("BoulderB").save_key())


## A path is not an identity for something that did not exist when the level
## was authored.
func test_a_spawned_object_gets_an_id_of_its_own() -> void:
	var first := SaveIdComponent.random_id()
	var second := SaveIdComponent.random_id()
	assert_ne(first, second, "two spawns were handed the same id")
	assert_true(String(first).begins_with(SaveIdComponent.SPAWNED_PREFIX))


func test_generated_ids_do_not_collide_in_bulk() -> void:
	var seen := {}
	for _spawn in 500:
		seen[SaveIdComponent.random_id()] = true
	assert_eq(seen.size(), 500, "%d of 500 generated ids collided" % (500 - seen.size()))


## Nothing keeps a list of saveable objects, so a component that never joins the
## group is invisible to a save and fails silently.
func test_it_joins_the_group_a_save_pass_walks() -> void:
	var component := _component_under("Chest", &"chest")
	assert_true(component.is_in_group(SaveIdComponent.GROUP))


func test_a_component_outside_the_tree_still_answers() -> void:
	# Whoever spawns an object may want its id before parenting it.
	var component := SaveIdComponent.new()
	mount(component)
	var key := component.save_key()
	assert_false(String(key).is_empty())
	assert_eq(component.save_key(), key, "the id changed on a second read")
