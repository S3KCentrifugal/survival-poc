extends TestCase
## The assembled prototype level: levelled ground, buildings on it, and a way
## out of the room you start in.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const CONFIG_RESOURCE: String = "res://resources/structures/prototype_structure.tres"


## The real scene, built the way the game builds it.
func _mount_world() -> Node:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	return world


func _level(world: Node) -> PrototypeLevel:
	return world.get_node("Level")


func test_the_config_resource_loads() -> void:
	var config: StructureConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not a StructureConfig" % CONFIG_RESOURCE)
	assert_true(
		config.doorway_height > 1.8, "a 1.8 m character would walk into every lintel"
	)
	assert_true(config.doorway_width > 0.8, "doorways narrower than a person")


func test_the_main_scene_carries_a_level() -> void:
	var world := _mount_world()
	var level := _level(world)
	assert_not_null(level, "the main scene has no level")
	assert_not_null(level.terrain, "the level cannot flatten ground it was never given")
	assert_not_null(level.structure_config, "config is not wired in the scene")


func test_it_builds_both_structures() -> void:
	var level := _level(_mount_world())
	assert_not_null(level.get_node_or_null("Base"), "no base was built")
	assert_not_null(level.get_node_or_null("Tower"), "no outdoor structure was built")


## A building on unlevelled ground floats at one corner and buries itself at
## another, and the step at its doorway is not something a character can climb.
func test_the_ground_under_the_base_is_levelled() -> void:
	var world := _mount_world()
	var level := _level(world)
	var terrain: Terrain = world.get_node("Terrain")

	var low := INF
	var high := -INF
	var x := PrototypeLevel.BASE_AREA.position.x
	while x <= PrototypeLevel.BASE_AREA.end.x:
		var z := PrototypeLevel.BASE_AREA.position.y
		while z <= PrototypeLevel.BASE_AREA.end.y:
			var height := terrain.height_at_world(Vector3(x, 0.0, z))
			low = minf(low, height)
			high = maxf(high, height)
			z += 1.0
		x += 1.0

	assert_true(high - low < 0.01, "the floor of the base still slopes by %f m" % (high - low))


func test_the_ground_eases_back_to_real_terrain_beyond_the_pad() -> void:
	# Otherwise the pad is a plateau stamped into the hillside, which is worse
	# than the problem it solves.
	var world := _mount_world()
	var terrain: Terrain = world.get_node("Terrain")
	var level := _level(world)

	var edge := terrain.height_at_world(Vector3(PrototypeLevel.BASE_AREA.end.x + 2.0, 0.0, 0.0))
	var away := terrain.height_at_world(Vector3(PrototypeLevel.BASE_AREA.end.x + 25.0, 0.0, 0.0))
	assert_true(
		absf(away - level.ground_height()) > 0.05,
		"the whole tile was flattened, not just the pad"
	)
	assert_true(absf(edge - level.ground_height()) < absf(away - level.ground_height()))


func test_the_player_starts_inside_the_start_room() -> void:
	var world := _mount_world()
	var level := _level(world)
	assert_true(
		level.is_in_start_room(world.spawn_point),
		"the authored spawn %v is not in the start room" % world.spawn_point
	)


func test_the_player_does_not_start_inside_a_wall() -> void:
	var world := _mount_world()
	var level := _level(world)
	var base: Structure = level.get_node("Base")
	var spawn := Vector3(world.spawn_point.x, level.ground_height() + 1.0, world.spawn_point.y)
	assert_false(base.is_solid_at(spawn), "the spawn point is inside the building's fabric")


## The point of the level: you can get out of the room you woke up in.
func test_both_doorways_are_actually_holes() -> void:
	var world := _mount_world()
	var level := _level(world)
	var base: Structure = level.get_node("Base")
	var head := level.ground_height() + 1.6

	# Through the internal wall at x = 0, and out through the south wall at x = 3.
	assert_false(
		base.is_solid_at(Vector3(PrototypeLevel.DIVIDER_X, head, 0.0)),
		"the internal doorway is walled up"
	)
	assert_false(
		base.is_solid_at(Vector3(3.0, head, PrototypeLevel.BASE_AREA.end.y)),
		"the way outside is walled up"
	)


func test_the_walls_either_side_of_a_doorway_are_solid() -> void:
	# A doorway proves nothing if the wall it is cut from is missing too.
	var world := _mount_world()
	var level := _level(world)
	var base: Structure = level.get_node("Base")
	var head := level.ground_height() + 1.6

	assert_true(base.is_solid_at(Vector3(-4.0, head, PrototypeLevel.BASE_AREA.end.y)))
	assert_true(base.is_solid_at(Vector3(PrototypeLevel.DIVIDER_X, head, 3.0)))


func test_the_tower_is_outside_the_base() -> void:
	assert_false(
		PrototypeLevel.BASE_AREA.grow(PrototypeLevel.PAD_MARGIN).intersects(
			PrototypeLevel.TOWER_AREA
		),
		"the outdoor structure overlaps the building it is supposed to be outside of"
	)
