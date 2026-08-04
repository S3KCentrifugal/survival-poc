extends TestCase
## Terrain generation and sampling.

const SIZE: int = 16

var config: TerrainConfig


func before_each() -> void:
	config = TerrainConfig.new()
	config.size_meters = SIZE
	config.height_scale = 5.0
	config.noise_seed = 42


func test_resolution_follows_from_size_at_unit_spacing() -> void:
	var field := Heightfield.generate(config)
	assert_eq(field.size_meters, SIZE)
	assert_eq(field.resolution, SIZE + 1)
	assert_eq(field.heights().size(), (SIZE + 1) * (SIZE + 1))


func test_generation_is_deterministic_for_a_seed() -> void:
	var first := Heightfield.generate(config)
	var second := Heightfield.generate(config)
	assert_eq(first.heights(), second.heights())


func test_different_seeds_give_different_terrain() -> void:
	var first := Heightfield.generate(config)
	config.noise_seed = 99
	var second := Heightfield.generate(config)
	assert_ne(first.heights(), second.heights())


func test_heights_stay_within_the_configured_scale() -> void:
	var field := Heightfield.generate(config)
	assert_true(field.lowest() >= -config.height_scale, "dipped below the scale")
	assert_true(field.highest() <= config.height_scale, "rose above the scale")


func test_a_zero_scale_gives_flat_ground() -> void:
	config.height_scale = 0.0
	var field := Heightfield.generate(config)
	assert_eq(field.lowest(), 0.0)
	assert_eq(field.highest(), 0.0)


func test_index_sampling_clamps_outside_the_field() -> void:
	var field := Heightfield.generate(config)
	assert_eq(field.height_at_index(-5, 0), field.height_at_index(0, 0))
	assert_eq(field.height_at_index(0, -5), field.height_at_index(0, 0))
	assert_eq(field.height_at_index(9999, 0), field.height_at_index(SIZE, 0))
	assert_eq(field.height_at_index(0, 9999), field.height_at_index(0, SIZE))


func test_local_sampling_matches_the_grid_at_vertices() -> void:
	# Local space is centred, so grid point (0,0) sits at -size/2 on both axes.
	var field := Heightfield.generate(config)
	var half := SIZE * 0.5
	for x in field.resolution:
		for z in field.resolution:
			var sampled := field.height_at_local(x - half, z - half)
			assert_true(
				is_equal_approx(sampled, field.height_at_index(x, z)),
				"vertex (%d, %d) sampled %f, grid says %f" % [
					x, z, sampled, field.height_at_index(x, z)
				]
			)


func test_local_sampling_interpolates_between_vertices() -> void:
	# A midpoint must land between its neighbours, not snap to one of them.
	var field := Heightfield.flat(4)
	assert_eq(field.height_at_local(0.0, 0.0), 0.0)

	var sloped := Heightfield.new(2, PackedFloat32Array([
		0.0, 0.0, 0.0,
		0.0, 0.0, 0.0,
		10.0, 10.0, 10.0,
	]))
	# z runs 0..2 over local -1..1, so local z = 0 is halfway to the far row.
	assert_true(is_equal_approx(sloped.height_at_local(0.0, 0.0), 0.0))
	assert_true(is_equal_approx(sloped.height_at_local(0.0, 0.5), 5.0))
	assert_true(is_equal_approx(sloped.height_at_local(0.0, 1.0), 10.0))


func test_local_sampling_clamps_outside_the_tile() -> void:
	var field := Heightfield.generate(config)
	var half := SIZE * 0.5
	assert_eq(field.height_at_local(-1000.0, 0.0), field.height_at_local(-half, 0.0))
	assert_eq(field.height_at_local(1000.0, 0.0), field.height_at_local(half, 0.0))


func test_vertex_positions_centre_the_tile_on_its_origin() -> void:
	var field := Heightfield.flat(SIZE)
	var half := SIZE * 0.5
	assert_eq(field.vertex_position(0, 0), Vector3(-half, 0.0, -half))
	assert_eq(field.vertex_position(SIZE, SIZE), Vector3(half, 0.0, half))


func test_a_flat_field_is_flat() -> void:
	var field := Heightfield.flat(8, 3.5)
	assert_eq(field.resolution, 9)
	assert_eq(field.lowest(), 3.5)
	assert_eq(field.highest(), 3.5)
