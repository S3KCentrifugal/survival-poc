extends TestCase
## The day/night component and its wiring into the main scene.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const CONFIG_RESOURCE: String = "res://resources/day_night/default_day_night.tres"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


## A component with its own sun, off the physics clock and out of the way.
func _day_night(start_time: float = 0.5) -> DayNightComponent:
	var config := DayNightConfig.new()
	config.day_length_seconds = 100.0
	config.start_time = start_time
	config.day_energy = 1.0
	config.night_energy = 0.05

	# In the tree, so _ready fires and the first aim actually happens.
	var tree := Engine.get_main_loop() as SceneTree
	var sun := DirectionalLight3D.new()
	var component := DayNightComponent.new()
	component.config = config
	component.sun = sun
	sun.add_child(component)
	tree.root.add_child(sun)
	_mounted.append(sun)
	return component


func test_the_config_resource_loads() -> void:
	var config: DayNightConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not a DayNightConfig" % CONFIG_RESOURCE)
	assert_true(config.day_length_seconds > 0.0)
	assert_true(config.night_energy > 0.0, "night would be pitch black")


func test_the_main_scene_wires_the_cycle_to_the_sun() -> void:
	var root: Node = load(MAIN_SCENE).instantiate()
	_mounted.append(root)
	var day_night: DayNightComponent = root.get_node_or_null("DayNight")
	assert_not_null(day_night, "the main scene has no day/night cycle")
	assert_not_null(day_night.config, "config is not wired in the scene")
	assert_not_null(day_night.sun, "the sun reference is not wired -- nothing would move")
	assert_eq(day_night.sun, root.get_node("Sun"))


func test_it_aims_the_sun_when_it_enters_the_scene() -> void:
	var day_night := _day_night(0.5)
	var direction := -day_night.sun.transform.basis.z
	assert_true(direction.y < 0.0, "the midday sun was shining upwards")


func test_the_sun_moves_as_the_day_runs() -> void:
	var day_night := _day_night(0.3)
	var before := day_night.sun.transform.basis.z
	day_night.step(20.0)
	assert_false(before.is_equal_approx(day_night.sun.transform.basis.z), "the sun did not move")


func test_the_light_dims_and_cools_after_dark() -> void:
	var day_night := _day_night(0.5)
	var noon_energy := day_night.sun.light_energy
	day_night.set_time_of_day(0.0)
	assert_true(day_night.sun.light_energy < noon_energy, "midnight was as bright as noon")
	assert_ne(day_night.sun.light_color, Color.WHITE)


func test_it_announces_dusk_and_dawn() -> void:
	var day_night := _day_night(0.7)
	var days := [0]
	var nights := [0]
	day_night.day_began.connect(func() -> void: days[0] += 1)
	day_night.night_began.connect(func() -> void: nights[0] += 1)

	# A full day from late afternoon: one sunset, then one sunrise.
	for _tick in 200:
		day_night.step(0.5)
	assert_eq(nights[0], 1, "night began %d times in one day" % nights[0])
	assert_eq(days[0], 1, "day began %d times in one day" % days[0])


## Whoever listens for dusk should not have to filter out a dusk that never
## happened because the clock was set rather than run.
func test_jumping_the_clock_does_not_announce_a_transition() -> void:
	var day_night := _day_night(0.5)
	var nights := [0]
	day_night.night_began.connect(func() -> void: nights[0] += 1)

	day_night.set_time_of_day(0.0)
	assert_eq(nights[0], 0)
	assert_false(day_night.is_daytime(), "the jump did not take")

	# ...and the next real tick must not fire it late either.
	day_night.step(0.1)
	assert_eq(nights[0], 0)


func test_it_reports_the_time_for_the_overlay() -> void:
	var day_night := _day_night(0.5)
	assert_eq(day_night.time_string(), "12:00")
	assert_true(is_equal_approx(day_night.time_of_day(), 0.5))


func test_a_cycle_with_no_sun_still_runs() -> void:
	# Deliberate: a headless or test scene with no light must not crash.
	var component := DayNightComponent.new()
	component.config = DayNightConfig.new()
	_mounted.append(component)

	component.step(1.0)
	assert_true(component.time_of_day() > 0.0)
