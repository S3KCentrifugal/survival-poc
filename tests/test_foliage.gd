extends TestCase
## What grows where, and the two properties that decide what a field costs.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const SEED: int = 20260807


func _layer(kind: FoliageLayer.Kind = FoliageLayer.Kind.GRASS) -> FoliageLayer:
	var layer := FoliageLayer.new()
	layer.layer_name = &"probe"
	layer.kind = kind
	layer.density = 2.0
	layer.radius = 40.0
	layer.chunk_size = 16.0
	layer.max_slope_degrees = 30.0
	return layer


## A hillside: flat on one side, steep on the other, so slope rules can be
## checked without generating a whole terrain.
func _ramp(size: int = 64, rise: float = 1.0) -> Heightfield:
	var resolution := size + 1
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	for z in resolution:
		for x in resolution:
			heights[z * resolution + x] = 0.0 if x < resolution / 2 else (x - resolution / 2) * rise
	return Heightfield.new(size, heights)


# --- The ground it reads ------------------------------------------------------

func test_flat_ground_has_an_upward_normal() -> void:
	assert_true(Heightfield.flat(32, 4.0).normal_at_local(0.0, 0.0).is_equal_approx(Vector3.UP))


func test_flat_ground_has_no_slope() -> void:
	assert_true(Heightfield.flat(32).slope_at_local(3.0, -2.0) < 0.001)


func test_a_hillside_reports_the_angle_it_actually_is() -> void:
	# One metre of rise per metre across is 45 degrees, and getting this wrong
	# by a factor of two is invisible until foliage climbs a cliff.
	var slope := _ramp(64, 1.0).slope_at_local(10.0, 0.0)
	assert_true(absf(slope - 45.0) < 2.0, "a 1:1 slope measured %f degrees" % slope)


## Central differences rather than the triangle a point falls in: a faceted
## normal makes slope-scattered foliage come and go across a triangle edge for
## no reason a player could see.
func test_the_slope_does_not_jump_between_grid_cells() -> void:
	var field := _ramp(64, 0.6)
	var previous := field.slope_at_local(6.0, 0.0)
	for step in 20:
		var slope := field.slope_at_local(6.0 + step * 0.1, 0.0)
		assert_true(absf(slope - previous) < 4.0, "the slope jumped at %f" % (6.0 + step * 0.1))
		previous = slope


# --- Where things grow --------------------------------------------------------

func test_a_flat_field_grows_something() -> void:
	var placed := FoliageScatter.place(
		_layer(), Rect2(0.0, 0.0, 16.0, 16.0), SEED, Heightfield.flat(64)
	)
	assert_true(placed.size() > 100, "only %d placed in 256 square metres" % placed.size())


func test_nothing_grows_on_a_cliff() -> void:
	var layer := _layer()
	layer.max_slope_degrees = 20.0
	var field := _ramp(64, 2.0)
	# The steep half, well inside the radius.
	assert_false(FoliageScatter.accepts(layer, Vector2(12.0, 0.0), field, []))
	assert_true(FoliageScatter.accepts(layer, Vector2(-12.0, 0.0), field, []))


func test_nothing_grows_through_a_wall() -> void:
	var keep_out: Array[Rect2] = [Rect2(-5.0, -5.0, 10.0, 10.0)]
	var field := Heightfield.flat(64)
	assert_false(FoliageScatter.accepts(_layer(), Vector2(0.0, 0.0), field, keep_out))
	assert_true(FoliageScatter.accepts(_layer(), Vector2(8.0, 0.0), field, keep_out))


func test_nothing_grows_past_the_edge_of_the_field() -> void:
	var layer := _layer()
	layer.radius = 20.0
	assert_false(FoliageScatter.accepts(layer, Vector2(25.0, 0.0), Heightfield.flat(64), []))


func test_an_excluded_chunk_places_nothing_rather_than_erroring() -> void:
	var keep_out: Array[Rect2] = [Rect2(-100.0, -100.0, 200.0, 200.0)]
	var placed := FoliageScatter.place(
		_layer(), Rect2(0.0, 0.0, 16.0, 16.0), SEED, Heightfield.flat(64), keep_out
	)
	assert_eq(placed.size(), 0)


## The whole point of seeding per chunk: a chunk contains the same field
## whether it was built first or fortieth, so nothing depends on iteration
## order and a chunk can be rebuilt alone later.
func test_a_chunk_is_the_same_field_however_it_was_reached() -> void:
	var area := Rect2(32.0, -16.0, 16.0, 16.0)
	var first := FoliageScatter.place(_layer(), area, SEED, Heightfield.flat(64))
	var again := FoliageScatter.place(_layer(), area, SEED, Heightfield.flat(64))
	assert_eq(first.size(), again.size())
	for index in first.size():
		assert_true(first[index].origin.is_equal_approx(again[index].origin))


func test_two_chunks_do_not_grow_the_same_field() -> void:
	var left := FoliageScatter.place(
		_layer(), Rect2(0.0, 0.0, 16.0, 16.0), SEED, Heightfield.flat(64)
	)
	var right := FoliageScatter.place(
		_layer(), Rect2(16.0, 0.0, 16.0, 16.0), SEED, Heightfield.flat(64)
	)
	assert_ne(left[0].origin.x - 0.0, right[0].origin.x - 16.0, "both chunks placed identically")


## A negative coordinate folding onto a positive one would make two chunks
## across the origin identical, which reads as a repeating pattern in the field.
func test_chunks_either_side_of_the_origin_get_different_seeds() -> void:
	assert_ne(
		FoliageScatter.chunk_seed(SEED, Vector2(-16.0, 0.0)),
		FoliageScatter.chunk_seed(SEED, Vector2(16.0, 0.0))
	)


func test_a_different_world_seed_grows_a_different_field() -> void:
	var area := Rect2(0.0, 0.0, 16.0, 16.0)
	var first := FoliageScatter.place(_layer(), area, SEED, Heightfield.flat(64))
	var other := FoliageScatter.place(_layer(), area, SEED + 1, Heightfield.flat(64))
	assert_ne(first[0].origin, other[0].origin)


func test_everything_stands_on_the_ground_it_was_placed_on() -> void:
	var field := _ramp(64, 0.4)
	var layer := _layer()
	layer.max_slope_degrees = 90.0
	for placed: Transform3D in FoliageScatter.place(
		layer, Rect2(-16.0, -16.0, 16.0, 16.0), SEED, field
	):
		var ground := field.height_at_local(placed.origin.x, placed.origin.z)
		assert_true(
			absf(placed.origin.y - ground) < 0.01,
			"something is floating %f metres up" % (placed.origin.y - ground)
		)


## A blade grows up whatever it is standing on. Tilting it into the hillside is
## what makes scattered foliage read as stickers rather than as plants.
func test_nothing_is_tilted_into_the_hillside() -> void:
	var layer := _layer()
	layer.max_slope_degrees = 90.0
	for placed: Transform3D in FoliageScatter.place(
		layer, Rect2(8.0, 0.0, 16.0, 16.0), SEED, _ramp(64, 1.0)
	):
		assert_true(
			placed.basis.y.normalized().is_equal_approx(Vector3.UP),
			"something grew at an angle"
		)


func test_the_chunk_grid_covers_the_whole_radius() -> void:
	var layer := _layer()
	var reach := 0.0
	for area: Rect2 in FoliageScatter.chunks(layer):
		reach = maxf(reach, maxf(absf(area.position.x), absf(area.end.x)))
	assert_true(reach >= layer.radius, "the grid reaches %f of %f" % [reach, layer.radius])


# --- What it costs ------------------------------------------------------------

## Grass casting shadows would be the single most expensive decision in the
## project: the shadow pass already draws three to four times what the camera
## does, and this is the densest thing in the world.
func test_grass_does_not_cast_a_shadow() -> void:
	var grass: FoliageLayer = load("res://resources/foliage/grass.tres")
	assert_false(grass.casts_shadow, "grass casts into the shadow map")


func test_trees_do_cast_one() -> void:
	# Few enough to afford it, and large enough that missing shadows would read
	# as the trees not being there.
	var tree: FoliageLayer = load("res://resources/foliage/tree.tres")
	assert_true(tree.casts_shadow)


func test_every_committed_layer_is_a_sane_thing_to_grow() -> void:
	for name: String in ["grass", "shrub", "tree"]:
		var layer: FoliageLayer = load("res://resources/foliage/%s.tres" % name)
		var problems := layer.problems()
		assert_true(problems.is_empty(), "%s: %s" % [name, ", ".join(problems)])


func test_a_layer_with_one_chunk_for_the_whole_field_is_refused() -> void:
	# A MultiMesh has one bounding box, so a single chunk is either entirely
	# drawn or entirely culled -- which is the thing chunking exists to avoid.
	var layer := _layer()
	layer.chunk_size = layer.radius * 4.0
	assert_false(layer.problems().is_empty())


func test_a_layer_that_grows_nothing_is_refused() -> void:
	var layer := _layer()
	layer.density = 0.0
	assert_false(layer.problems().is_empty())


# --- The meshes ---------------------------------------------------------------

func test_a_clump_is_built_one_unit_tall_so_the_layer_owns_its_size() -> void:
	var mesh := FoliageMesh.blades(3, 0.5, Color.BLACK, Color.WHITE)
	assert_true(absf(mesh.get_aabb().size.y - 1.0) < 0.05, "a clump is %f tall" % mesh.get_aabb().size.y)


func test_a_clump_has_triangles_in_it() -> void:
	var mesh := FoliageMesh.blades(3, 0.5, Color.BLACK, Color.WHITE)
	assert_eq(mesh.get_surface_count(), 1)
	assert_true(mesh.surface_get_array_len(0) >= 18, "three quads is eighteen vertices")


## One surface, not two. A MultiMesh issues a draw call per surface, so a
## two-surface tree doubles the draw calls of every chunk it appears in.
func test_a_tree_is_one_surface() -> void:
	assert_eq(FoliageMesh.tree(Color.BROWN, Color.BLACK, Color.WHITE).get_surface_count(), 1)


func test_a_tree_is_taller_than_it_is_wide() -> void:
	var box := FoliageMesh.tree(Color.BROWN, Color.BLACK, Color.WHITE).get_aabb()
	assert_true(box.size.y > box.size.x, "a %f x %f tree is a bush" % [box.size.x, box.size.y])


## Vertex colours are handed to the shader exactly as stored, and ALBEDO is
## linear -- so a palette authored the way a colour picker shows it renders
## about twice as bright as it reads on the page.
func test_the_palette_is_converted_out_of_srgb_before_it_reaches_the_mesh() -> void:
	var layer := _layer()
	layer.base_color = Color(0.5, 0.5, 0.5)
	layer.tip_color = Color(0.5, 0.5, 0.5)
	var mesh := FoliageMesh.for_layer(layer)
	var colours: PackedColorArray = mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	assert_true(
		colours[0].r < 0.35,
		"mid grey reached the mesh at %f, so it was never linearised" % colours[0].r
	)


## Banding each end of a gradient separately lands both on the same brightness
## and flattens the blade into a single colour.
func test_a_blade_still_gets_lighter_toward_its_tip() -> void:
	var layer := _layer()
	var mesh := FoliageMesh.for_layer(layer)
	var arrays := mesh.surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var root := 1.0
	var tip := 0.0
	for index in colours.size():
		var level := SurfacePalette.linear_luminance(colours[index])
		if uvs[index].y < 0.5:
			root = minf(root, level)
		else:
			tip = maxf(tip, level)
	assert_true(tip > root * 1.5, "root %f and tip %f are the same colour" % [root, tip])


## UV.y is the sway weight. A root that swayed would tear the clump out of the
## ground; a tip that did not would not move at all.
func test_the_root_is_pinned_and_the_tip_is_free() -> void:
	var arrays := FoliageMesh.blades(3, 0.5, Color.BLACK, Color.WHITE).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	for index in vertices.size():
		if vertices[index].y < 0.1:
			assert_eq(uvs[index].y, 0.0, "a root vertex is free to sway")
		if vertices[index].y > 0.9:
			assert_eq(uvs[index].y, 1.0, "a tip vertex is pinned")


# --- In the world -------------------------------------------------------------

func test_the_world_grows_a_field() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var foliage: FoliageComponent = world.get_node_or_null("Foliage")
	assert_not_null(foliage, "the world has no foliage")
	assert_true(foliage.instance_count() > 1000, "only %d things grew" % foliage.instance_count())


## Chunked so the renderer has something to cull with. One chunk would mean the
## whole field is drawn whenever any of it is.
func test_the_field_is_split_into_chunks_the_renderer_can_cull() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var foliage: FoliageComponent = world.get_node("Foliage")
	assert_true(foliage.chunk_count() > 20, "the field is in %d chunks" % foliage.chunk_count())


## Checked through [FoliageScatter] with the world's own layers and exclusions,
## never by reading the [MultiMesh] back.
##
## A MultiMesh keeps its instance transforms in the rendering server, and the
## headless server does not keep them: every write is accepted, every read
## returns identity, `buffer` is empty, and nothing errors. A test that verified
## placement through the MultiMesh would report every instance sitting at the
## world origin -- inside the building -- which is a failure of the harness
## reported as a failure of the feature. See CLAUDE.md.
func test_nothing_grows_inside_the_building() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var foliage: FoliageComponent = world.get_node("Foliage")
	var terrain: Terrain = world.get_node("Terrain")
	assert_false(foliage.avoid.is_empty(), "the building is not excluded from the field")

	var checked := 0
	for layer: FoliageLayer in foliage.layers:
		for area: Rect2 in FoliageScatter.chunks(layer):
			for placed: Transform3D in FoliageScatter.place(
				layer, area, foliage.seed_value, terrain.field(), foliage.avoid
			):
				checked += 1
				for keep_out: Rect2 in foliage.avoid:
					assert_false(
						keep_out.has_point(Vector2(placed.origin.x, placed.origin.z)),
						"something grew at %s" % placed.origin
					)
	assert_true(checked > 1000, "only %d placements were checked" % checked)


## The limitation above, asserted rather than left as a comment -- so that if a
## future Godot starts keeping the buffer, the test that was written around the
## gap is the thing that tells somebody.
func test_a_multimesh_keeps_nothing_in_a_headless_run() -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = BoxMesh.new()
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3(1.0, 2.0, 3.0)))
	assert_eq(
		multi.buffer.size(),
		0,
		"the headless server is keeping MultiMesh transforms now; the foliage tests can read them"
	)


func test_growing_twice_does_not_double_the_field() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var foliage: FoliageComponent = world.get_node("Foliage")
	var before := foliage.instance_count()
	foliage.grow()
	assert_eq(foliage.instance_count(), before, "regrowing added a second field on top")
