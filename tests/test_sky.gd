extends TestCase
## The sky: the colour decisions, and the wiring that gets them to the shader.
##
## What a sky *looks* like cannot be asserted, but every decision behind it can:
## that dusk is warmer than noon, that stars are out at midnight and not at
## midday, that the drawn sun points where the shadows come from.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const SHADER_PATH: String = "res://shaders/sky.gdshader"
const CONFIG_PATH: String = "res://resources/sky/default_sky.tres"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount_world() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node = load(MAIN_SCENE).instantiate()
	tree.root.add_child(world)
	_mounted.append(world)
	return world


func _gradient() -> SkyGradient:
	return SkyGradient.new(load(CONFIG_PATH))


func test_the_shader_and_config_exist() -> void:
	assert_true(ResourceLoader.exists(SHADER_PATH), "there is no sky shader")
	var config: SkyConfig = load(CONFIG_PATH)
	assert_not_null(config, "%s is missing or malformed" % CONFIG_PATH)
	assert_true(config.sun_angular_radius > 0.0, "the sun would be invisible")


## Below the horizon is night, above the twilight band is full day, and the
## band between is the only place anything interesting happens.
func test_daylight_runs_from_the_horizon_up() -> void:
	var gradient := _gradient()
	assert_eq(gradient.daylight_amount(-0.5), 0.0)
	assert_eq(gradient.daylight_amount(0.0), 0.0)
	assert_eq(gradient.daylight_amount(1.0), 1.0)
	assert_true(gradient.daylight_amount(0.1) > 0.0, "dawn never starts")
	assert_true(gradient.daylight_amount(0.1) < 1.0, "dawn is instant")


## Sunrise and sunset are the same geometry, so they get the same colours.
func test_dusk_peaks_on_the_horizon_and_is_symmetric() -> void:
	var gradient := _gradient()
	assert_eq(gradient.dusk_amount(0.0), 1.0, "the sunset is not at the horizon")
	for elevation: float in [0.02, 0.07, 0.14]:
		assert_true(
			is_equal_approx(gradient.dusk_amount(elevation), gradient.dusk_amount(-elevation)),
			"sunrise and sunset differ at %f" % elevation
		)
	assert_eq(gradient.dusk_amount(0.9), 0.0, "it is still sunset at noon")


func test_the_sunset_is_warmer_than_noon() -> void:
	var gradient := _gradient()
	var dusk := gradient.horizon_color(0.0)
	var noon := gradient.horizon_color(1.0)
	assert_true(dusk.r > noon.r, "the sunset has less red in it than midday")
	assert_true(dusk.b < noon.b, "the sunset is bluer than midday")


func test_night_is_darker_than_day() -> void:
	var gradient := _gradient()
	assert_true(
		gradient.zenith_color(-1.0).get_luminance() < gradient.zenith_color(1.0).get_luminance(),
		"the midnight sky is no darker than the midday one"
	)


## Never a shade the sky is not already wearing, and never brighter than it.
func test_the_ground_follows_the_horizon() -> void:
	var gradient := _gradient()
	for elevation: float in [-1.0, -0.1, 0.0, 0.3, 1.0]:
		var ground := gradient.ground_color(elevation)
		var horizon := gradient.horizon_color(elevation)
		assert_true(
			ground.get_luminance() <= horizon.get_luminance(),
			"the ground is brighter than the sky at elevation %f" % elevation
		)


## The halo is light scattered along a low path through thick air. A midday sun
## in a clear sky has almost none, and a sun that is properly down has none at
## all -- a glow outliving the thing casting it is the tell.
func test_the_halo_belongs_to_the_horizon() -> void:
	var gradient := _gradient()
	assert_true(gradient.halo_strength(0.0) > 0.0, "there is no glow at sunset")
	assert_eq(gradient.halo_strength(1.0), 0.0, "midday has a sunset glow")
	assert_eq(gradient.halo_strength(-0.9), 0.0, "the glow outlived the sun")


func test_stars_come_out_at_night() -> void:
	var gradient := _gradient()
	assert_eq(gradient.star_fade(0.5), 0.0, "there are stars at midday")
	assert_eq(gradient.star_fade(0.0), 0.0, "stars are out before the sun is down")
	assert_eq(gradient.star_fade(-1.0), 1.0, "midnight has no stars")
	assert_true(gradient.star_fade(-0.08) > 0.0, "the first stars never appear")


func test_the_scene_is_wired() -> void:
	var world := _mount_world()
	var sky: SkyComponent = world.get_node_or_null("Sky")
	assert_not_null(sky, "the world has no sky component")
	assert_eq(sky.day_night, world.get_node("DayNight"), "the sky has no clock")
	assert_eq(sky.environment, world.get_node("WorldEnvironment"))
	assert_not_null(sky.config, "the sky has no config, so it is using code defaults")

	var material := sky.material()
	assert_not_null(material, "the environment is not using the sky shader")
	assert_eq(material.shader, load(SHADER_PATH))


## The disc has to be drawn where the light is coming from. A sun in one corner
## of the sky and shadows pointing out of another is obvious in a screenshot and
## invisible in code.
func test_the_drawn_sun_matches_the_light() -> void:
	var world := _mount_world()
	var sky: SkyComponent = world.get_node("Sky")
	var day_night: DayNightComponent = world.get_node("DayNight")

	for time: float in [0.1, 0.25, 0.5, 0.7, 0.95]:
		day_night.set_time_of_day(time)
		var drawn := sky.sun_position()
		var lit := -day_night.sun.global_transform.basis.z.normalized()
		assert_true(
			drawn.dot(lit) < -0.999,
			"the sun is drawn at %s while lighting from %s" % [drawn, lit]
		)


func test_moving_the_clock_repaints_the_sky() -> void:
	var world := _mount_world()
	var sky: SkyComponent = world.get_node("Sky")
	var day_night: DayNightComponent = world.get_node("DayNight")
	var material := sky.material()

	day_night.set_time_of_day(0.5)
	var noon: Color = material.get_shader_parameter(&"horizon_color")
	var noon_stars: float = material.get_shader_parameter(&"star_fade")

	day_night.set_time_of_day(0.0)
	var midnight: Color = material.get_shader_parameter(&"horizon_color")

	assert_false(noon.is_equal_approx(midnight), "the sky did not change all day")
	assert_eq(noon_stars, 0.0, "stars at noon")
	assert_true(
		float(material.get_shader_parameter(&"star_fade")) > 0.9, "no stars at midnight"
	)


## Sub-resources are shared between instantiations of a scene unless they say
## otherwise, so without resource_local_to_scene one world's clock recolours
## every other world's sky. This project has been caught by the shared-resource
## trap three times already; this is the fourth place it would have applied.
func test_two_worlds_do_not_share_one_sky() -> void:
	var first: SkyComponent = _mount_world().get_node("Sky")
	var second: SkyComponent = _mount_world().get_node("Sky")
	assert_false(
		first.material() == second.material(),
		"both worlds are writing to the same sky material"
	)

	(first.day_night as DayNightComponent).set_time_of_day(0.5)
	(second.day_night as DayNightComponent).set_time_of_day(0.0)
	assert_false(
		Color(first.material().get_shader_parameter(&"horizon_color")).is_equal_approx(
			second.material().get_shader_parameter(&"horizon_color")
		),
		"midday and midnight produced the same sky"
	)


## Without a clock it should still draw something lit, not a black void: that is
## what a lighting or material test wants when it mounts a bare environment.
func test_it_works_with_no_clock_at_all() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var sky := SkyComponent.new()
	sky.config = load(CONFIG_PATH)
	tree.root.add_child(sky)
	_mounted.append(sky)

	assert_true(sky.sun_position().y > 0.9, "a sky with no clock is not lit")
	assert_null(sky.material(), "it found a material where there is no environment")
