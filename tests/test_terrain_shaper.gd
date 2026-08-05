extends TestCase
## The shape of the ground: that it has plains, hills and steep parts, in
## roughly the proportions a landscape has them.
##
## Everything here is a number taken off the real config. "Does it look like
## terrain" is a screenshot; "is a third of it walkable, and is the tall ground
## rarer than the low ground" is a test, and the second one is what stops a
## tuning pass three features from now quietly turning the map into a field.

const CONFIG_PATH: String = "res://resources/terrain/default_terrain.tres"

## Slope bands, in degrees from flat.
const WALKABLE: float = 4.0
const ROLLING: float = 16.0
const STEEP: float = 40.0


func _config() -> TerrainConfig:
	return load(CONFIG_PATH)


## Fractions of the tile in each slope band, as [flat, gentle, steep, cliff].
##
## Sampled every other vertex: the answer moves by well under a percent at full
## resolution and this runs four times faster.
func _slope_profile(field: Heightfield) -> Array[float]:
	var counts := [0, 0, 0, 0]
	var total := 0
	var step := 2
	var x := step
	while x < field.resolution - step:
		var z := step
		while z < field.resolution - step:
			var dx := field.height_at_index(x + 1, z) - field.height_at_index(x - 1, z)
			var dz := field.height_at_index(x, z + 1) - field.height_at_index(x, z - 1)
			var slope := rad_to_deg(atan(Vector2(dx, dz).length() / 2.0))
			total += 1
			if slope < WALKABLE:
				counts[0] += 1
			elif slope < ROLLING:
				counts[1] += 1
			elif slope < STEEP:
				counts[2] += 1
			else:
				counts[3] += 1
			z += step
		x += step

	var profile: Array[float] = []
	for count: int in counts:
		profile.append(float(count) / maxf(total, 1))
	return profile


func test_the_config_describes_a_large_tile() -> void:
	var config := _config()
	assert_true(
		config.size_meters >= 256, "the sample world is %d m across" % config.size_meters
	)
	assert_eq(config.sample_count(), config.resolution() * config.resolution())


## The whole point of the relief layer. Without flat ground there is nowhere to
## build, and without steep ground it is a field.
func test_the_land_has_plains_hills_and_steep_ground() -> void:
	var profile := _slope_profile(Heightfield.generate(_config()))
	assert_true(
		profile[0] > 0.12,
		"only %d%% of the map is flat enough to build on" % roundi(profile[0] * 100.0)
	)
	assert_true(
		profile[1] > 0.2, "only %d%% of the map is rolling hills" % roundi(profile[1] * 100.0)
	)
	assert_true(
		profile[2] > 0.05, "only %d%% of the map is steep" % roundi(profile[2] * 100.0)
	)


## Steep ground should be the exception. A map that is mostly cliff is not a
## landscape, it is a quarry.
func test_most_of_the_land_is_walkable() -> void:
	var profile := _slope_profile(Heightfield.generate(_config()))
	assert_true(
		profile[0] + profile[1] > 0.55,
		"only %d%% of the map can be walked over comfortably"
			% roundi((profile[0] + profile[1]) * 100.0)
	)
	assert_true(profile[3] < 0.15, "%d%% of the map is cliff" % roundi(profile[3] * 100.0))


## Hills you can see from across the map, not corrugation.
func test_there_is_real_relief() -> void:
	var field := Heightfield.generate(_config())
	var relief := field.highest() - field.lowest()
	assert_true(relief > 12.0, "the tallest hill is %.1f m above the lowest ground" % relief)
	assert_true(relief < 120.0, "%.1f m of relief on a 256 m tile is a cliff face" % relief)


## The mask has to have both ends. All high is a mountain range with nowhere to
## stand; all low is a field.
func test_the_relief_mask_uses_its_whole_range() -> void:
	var config := _config()
	var shaper := TerrainShaper.new(config)
	var lowest := INF
	var highest := -INF
	for x in range(0, config.size_meters, 4):
		for z in range(0, config.size_meters, 4):
			var relief := shaper.relief_at(x, z)
			lowest = minf(lowest, relief)
			highest = maxf(highest, relief)

	assert_true(lowest < 0.35, "nowhere on the map is plain (lowest relief %.2f)" % lowest)
	assert_true(highest > 0.8, "nowhere on the map is hill (highest relief %.2f)" % highest)


## Never zero. A mask that switches off entirely leaves the hills standing on a
## flat sheet like cones dropped on a table -- which is what the first version
## looked like, and the whole reason this floor exists.
func test_the_relief_mask_never_reaches_zero() -> void:
	var config := _config()
	assert_true(config.relief_floor > 0.0, "plains would be perfectly flat")

	var shaper := TerrainShaper.new(config)
	for x in range(0, config.size_meters, 8):
		for z in range(0, config.size_meters, 8):
			assert_true(
				shaper.relief_at(x, z) >= config.relief_floor - 0.001,
				"relief fell below the floor at %d, %d" % [x, z]
			)


## Same seed, same world. The difference between a bug you can chase and one
## you cannot.
func test_the_same_seed_gives_the_same_ground() -> void:
	var config := _config()
	var first := Heightfield.generate(config)
	var second := Heightfield.generate(config)
	for index in [0, 137, 5000, first.heights().size() - 1]:
		assert_eq(first.heights()[index], second.heights()[index], "sample %d moved" % index)


func test_a_different_seed_gives_different_ground() -> void:
	var config: TerrainConfig = _config().duplicate()
	var original := Heightfield.generate(config)
	config.noise_seed += 1
	var changed := Heightfield.generate(config)

	var moved := 0
	for index in range(0, original.heights().size(), 97):
		if not is_equal_approx(original.heights()[index], changed.heights()[index]):
			moved += 1
	assert_true(moved > 0, "changing the seed changed nothing")


## Each layer gets its own seed offset. Sharing one lines the features up, and
## land where every layer agrees looks stamped rather than grown.
func test_the_layers_do_not_share_a_seed() -> void:
	var config: TerrainConfig = _config().duplicate()
	config.hill_weight = 1.0
	config.ridge_weight = 0.0
	config.detail_weight = 0.0
	var hills_only := Heightfield.generate(config)

	config.hill_weight = 0.0
	config.ridge_weight = 1.0
	var ridges_only := Heightfield.generate(config)

	var identical := 0
	var samples := 0
	for index in range(0, hills_only.heights().size(), 53):
		samples += 1
		if is_equal_approx(hills_only.heights()[index], ridges_only.heights()[index]):
			identical += 1
	assert_true(
		identical < samples / 4, "the hill and ridge layers are producing the same field"
	)


## Turning a layer off has to actually turn it off, or the config is decoration.
func test_every_weight_does_something() -> void:
	var base := Heightfield.generate(_config())
	for property: String in ["hill_weight", "ridge_weight", "detail_weight"]:
		var config: TerrainConfig = _config().duplicate()
		config.set(property, 0.0)
		var without := Heightfield.generate(config)
		assert_false(
			is_equal_approx(base.highest(), without.highest()),
			"%s changes nothing" % property
		)


## Ground is mostly not a hilltop. The exponent on the hill layer is what makes
## the low ground more common than the high ground; at 1.0 it spends half its
## time above the midpoint, which reads as corrugation.
func test_low_ground_is_more_common_than_high_ground() -> void:
	var field := Heightfield.generate(_config())
	var midpoint := (field.highest() + field.lowest()) * 0.5
	var below := 0
	var total := 0
	for height: float in field.heights():
		total += 1
		if height < midpoint:
			below += 1
	assert_true(
		float(below) / total > 0.6,
		"only %d%% of the map is below the midpoint" % roundi(100.0 * below / total)
	)
