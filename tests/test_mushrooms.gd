extends TestCase
## Mushrooms in the world: where they grow, that they grow, and that they come
## back.

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


func _patch(count: int, regrow_seconds: float = 1.0) -> MushroomPatch:
	var patch := MushroomPatch.new()
	patch.scene = load(MUSHROOM_SCENE)
	patch.count = count
	patch.regrow_seconds = regrow_seconds
	patch.area = Rect2(-10.0, -10.0, 20.0, 20.0)
	patch.avoid = Rect2(-2.0, -2.0, 4.0, 4.0)
	_mount(patch)
	return patch


func test_the_patch_fills_on_the_first_frame() -> void:
	var patch := _patch(8)
	assert_eq(patch.standing(), 8, "the world started with %d mushrooms" % patch.standing())


## The world should look established, not like a field of seedlings planted as
## you arrived.
func test_the_first_crop_starts_full_size() -> void:
	var patch := _patch(4)
	for mushroom: Node3D in patch.mushrooms():
		assert_eq((mushroom as MushroomGrowth).maturity(), 1.0, "a starting mushroom was a sprout")


func test_none_grow_inside_the_building() -> void:
	var patch := _patch(20)
	for mushroom: Node3D in patch.mushrooms():
		var where := Vector2(mushroom.global_position.x, mushroom.global_position.z)
		assert_false(patch.avoid.has_point(where), "a mushroom grew at %v, inside the base" % where)


## A patch of identical props in identical poses reads as a spawner firing.
func test_they_are_scattered_rather_than_stacked() -> void:
	var patch := _patch(10)
	var seen: Array[Vector3] = []
	for mushroom: Node3D in patch.mushrooms():
		for other: Vector3 in seen:
			assert_true(
				mushroom.global_position.distance_to(other) > 0.01,
				"two mushrooms grew in the same place"
			)
		seen.append(mushroom.global_position)


func test_the_same_seed_gives_the_same_field() -> void:
	var first := _patch(6)
	var second := _patch(6)
	for index in 6:
		assert_true(
			first.mushrooms()[index].global_position.is_equal_approx(
				second.mushrooms()[index].global_position
			),
			"two patches with the same seed disagreed"
		)


func test_picking_one_leaves_a_gap() -> void:
	var patch := _patch(5)
	var mushroom := patch.mushrooms()[0]
	mushroom.get_node("Pickup").collect_into(_a_bag())
	assert_eq(patch.standing(), 4, "the picked mushroom is still counted")


## The delay has to apply to the *first* gap. A fresh Cooldown is ready, not
## waiting -- which is exactly how the wanderer respawner refilled instantly.
func test_the_first_gap_waits_before_it_regrows() -> void:
	var patch := _patch(3, 1.0)
	patch.mushrooms()[0].get_node("Pickup").collect_into(_a_bag())
	assert_eq(patch.standing(), 2)

	patch._process(0.1)
	patch._process(0.5)
	assert_eq(patch.standing(), 2, "it regrew before the delay was up")

	patch._process(0.6)
	assert_eq(patch.standing(), 3, "it never regrew")


func test_a_regrown_mushroom_sprouts_rather_than_appearing() -> void:
	var patch := _patch(2, 0.5)
	var before := patch.mushrooms()
	before[0].get_node("Pickup").collect_into(_a_bag())

	patch._process(0.1)
	patch._process(0.6)
	var grown: MushroomGrowth = null
	for mushroom: Node3D in patch.mushrooms():
		if not before.has(mushroom):
			grown = mushroom
	assert_not_null(grown, "nothing regrew")
	assert_true(grown.maturity() < 1.0, "the replacement appeared at full size")


func test_it_stops_at_the_count_it_was_given() -> void:
	var patch := _patch(3, 0.1)
	for _frame in 40:
		patch._process(0.1)
	assert_eq(patch.standing(), 3, "the patch grew past its count")


## A half-grown mushroom is a real mushroom. Waiting for an animation to finish
## before you may pick something up is a rule nobody enjoys discovering.
func test_a_sprouting_mushroom_can_still_be_picked() -> void:
	var mushroom: Node3D = load(MUSHROOM_SCENE).instantiate()
	_mount(mushroom)
	var growth := mushroom as MushroomGrowth
	growth._process(0.01)

	assert_true(growth.maturity() < 1.0, "it is already grown, so this proves nothing")
	assert_eq(mushroom.get_node("Pickup").collect_into(_a_bag()), 1, "a sprout could not be picked")


func test_growing_scales_the_model_and_stops() -> void:
	var mushroom: Node3D = load(MUSHROOM_SCENE).instantiate()
	_mount(mushroom)
	var growth := mushroom as MushroomGrowth
	var model: Node3D = mushroom.get_node("Model")

	assert_true(model.scale.x < 0.2, "it did not start small")
	for _frame in 60:
		growth._process(0.1)
	assert_true(model.scale.is_equal_approx(Vector3.ONE), "it never reached full size")
	assert_eq(growth.maturity(), 1.0)


func test_the_world_has_a_patch() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	_mount(world)
	var patch: MushroomPatch = world.get_node_or_null("Mushrooms")
	assert_not_null(patch, "there are no mushrooms in the world")
	assert_not_null(patch.scene, "the patch has nothing to grow")
	assert_eq(patch.terrain, world.get_node("Terrain"), "they would grow at sea level")
	assert_true(patch.standing() > 0, "the patch is empty")


## Dropped onto the surface, not left hanging over a hill or buried in one.
func test_they_sit_on_the_ground() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	_mount(world)
	var patch: MushroomPatch = world.get_node("Mushrooms")
	var terrain: Terrain = world.get_node("Terrain")

	for mushroom: Node3D in patch.mushrooms():
		var ground := terrain.height_at_world(mushroom.global_position)
		assert_true(
			absf(mushroom.global_position.y - ground) < 0.1,
			"a mushroom sits %f m off the ground" % (mushroom.global_position.y - ground)
		)


func _a_bag() -> InventoryComponent:
	var inventory := InventoryComponent.new()
	_mount(inventory)
	return inventory
