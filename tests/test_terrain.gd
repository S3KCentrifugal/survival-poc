extends TestCase
## The terrain node: mesh construction, collision, and that the two agree.

const TERRAIN_SCENE: String = "res://world/terrain.tscn"
const CONFIG_RESOURCE: String = "res://resources/terrain/default_terrain.tres"

var _instance: Terrain


func after_each() -> void:
	if _instance != null:
		_instance.free()
		_instance = null


## Instantiates and attaches, so `_ready` builds the terrain.
func _mount() -> Terrain:
	var tree := Engine.get_main_loop() as SceneTree
	_instance = load(TERRAIN_SCENE).instantiate()
	tree.root.add_child(_instance)
	return _instance


func test_the_config_resource_loads() -> void:
	var config: TerrainConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not a TerrainConfig" % CONFIG_RESOURCE)
	assert_true(config.size_meters >= 4)
	assert_eq(config.resolution(), config.size_meters + 1)
	assert_eq(config.sample_count(), config.resolution() * config.resolution())


func test_config_clamps_nonsense_values() -> void:
	var config := TerrainConfig.new()
	config.size_meters = -10
	assert_true(config.size_meters >= 4, "a negative tile makes no sense")
	config.height_scale = -3.0
	assert_eq(config.height_scale, 0.0)
	config.noise_octaves = 999
	assert_true(config.noise_octaves <= 8)


func test_the_scene_loads_and_is_a_static_body() -> void:
	var scene: PackedScene = load(TERRAIN_SCENE)
	assert_not_null(scene, "%s is missing or malformed" % TERRAIN_SCENE)
	assert_true(scene.can_instantiate())
	var root: Node = scene.instantiate()
	assert_true(root is StaticBody3D, "terrain must collide, so it must be a body")
	root.free()


func test_ready_builds_a_mesh() -> void:
	var terrain := _mount()
	var mesh_instance: MeshInstance3D = terrain.get_node("MeshInstance3D")
	assert_not_null(mesh_instance.mesh, "_ready did not build a mesh")
	assert_eq(mesh_instance.mesh.get_surface_count(), 1)

	var expected_vertices := terrain.field().resolution * terrain.field().resolution
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size(), expected_vertices)


func test_ready_builds_collision_matching_the_mesh() -> void:
	var terrain := _mount()
	var collision: CollisionShape3D = terrain.get_node("CollisionShape3D")
	var shape: HeightMapShape3D = collision.shape
	assert_not_null(shape, "_ready did not build a collision shape")

	var field := terrain.field()
	assert_eq(shape.map_width, field.resolution)
	assert_eq(shape.map_depth, field.resolution)
	assert_eq(shape.map_data, field.heights())


## The whole reason vertex spacing is pinned to one metre: an unscaled
## HeightMapShape3D spans exactly as far as the mesh does. If either side ever
## grows a scale factor, collision silently stops matching what you can see.
func test_collision_and_mesh_span_the_same_ground() -> void:
	var terrain := _mount()
	var collision: CollisionShape3D = terrain.get_node("CollisionShape3D")
	var mesh_instance: MeshInstance3D = terrain.get_node("MeshInstance3D")
	assert_eq(collision.scale, Vector3.ONE, "a scaled shape desynchronises collision")
	assert_eq(mesh_instance.scale, Vector3.ONE)

	var field := terrain.field()
	var half := field.size_meters * 0.5
	var bounds: AABB = mesh_instance.mesh.get_aabb()
	assert_true(is_equal_approx(bounds.position.x, -half), "mesh is not centred on x")
	assert_true(is_equal_approx(bounds.position.z, -half), "mesh is not centred on z")
	assert_true(is_equal_approx(bounds.size.x, float(field.size_meters)))
	assert_true(is_equal_approx(bounds.size.z, float(field.size_meters)))


## Godot treats clockwise winding as front-facing. Wound the other way every
## triangle is back-face culled and the terrain is invisible from above -- which
## looks like a missing mesh, not a winding bug. Normals point up or it is wrong.
func test_the_ground_faces_upwards() -> void:
	var terrain := _mount()
	var mesh_instance: MeshInstance3D = terrain.get_node("MeshInstance3D")
	var arrays: Array = mesh_instance.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_true(normals.size() > 0, "mesh has no normals")

	var downward := 0
	for normal: Vector3 in normals:
		if normal.y <= 0.0:
			downward += 1
	assert_eq(downward, 0, "%d of %d normals point down" % [downward, normals.size()])


func test_world_height_lookup_agrees_with_the_field() -> void:
	var terrain := _mount()
	var field := terrain.field()
	for offset: float in [-8.0, -2.5, 0.0, 3.75, 9.0]:
		var expected := field.height_at_local(offset, offset)
		var actual := terrain.height_at_world(Vector3(offset, 0.0, offset))
		assert_true(
			is_equal_approx(actual, expected),
			"world lookup at %f gave %f, field says %f" % [offset, actual, expected]
		)


func test_rebuilding_with_a_new_config_changes_the_ground() -> void:
	var terrain := _mount()
	var before := terrain.field().heights()

	var flatter := TerrainConfig.new()
	flatter.size_meters = terrain.config.size_meters
	flatter.height_scale = 0.0
	terrain.config = flatter
	terrain.rebuild()

	assert_ne(terrain.field().heights(), before)
	assert_eq(terrain.field().highest(), 0.0, "a zero scale should flatten it")
