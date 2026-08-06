extends TestCase
## The commands themselves, run against the real world they operate on.

const MAIN_SCENE: String = "res://scenes/main.tscn"


func after_each() -> void:
	_kept.clear()


func _mount_world() -> Node:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	return world


func _ui(world: Node) -> DevConsoleUI:
	return world.get_node("DevConsole")


## Kept alive for the length of a test. A Callable stores an object id rather
## than a reference, so a GameCommands that goes out of scope takes every
## command's method with it.
var _kept: Array[RefCounted] = []


## A console wired to nothing, to prove the commands survive it.
func _unbound() -> DevConsole:
	var console := DevConsole.new()
	var commands := GameCommands.new()
	_kept.append(commands)
	commands.install(console)
	return console


func test_the_main_scene_carries_a_console_wired_to_the_world() -> void:
	var world := _mount_world()
	var ui := _ui(world)
	assert_not_null(ui, "the main scene has no dev console")
	assert_eq(ui.player, world.get_node("Player"))
	assert_eq(ui.health, world.get_node("Player/Health"))
	assert_eq(ui.day_night, world.get_node("DayNight"))
	assert_eq(ui.terrain, world.get_node("Terrain"))


func test_it_starts_closed() -> void:
	# A console that opens with the game is a console you have to close first.
	assert_false(_ui(_mount_world()).visible)


func test_help_lists_every_command() -> void:
	var console := _unbound()
	var listing := console.run("help")
	for name: StringName in [&"tp", &"time", &"heal", &"hurt", &"kill", &"where", &"speed"]:
		assert_true(listing.contains(String(name)), "help does not mention %s" % name)


func test_help_explains_one_command() -> void:
	assert_true(_unbound().run("help tp").contains("tp <x> <z>"))


func test_help_on_something_unknown_says_so() -> void:
	assert_true(_unbound().run("help frobnicate").contains("frobnicate"))


## The console is most useful in a half-built scene, so a missing reference has
## to produce a sentence rather than a crash.
func test_every_command_survives_having_nothing_to_work_on() -> void:
	var console := _unbound()
	for line: String in [
		"where", "tp 1 2", "time 12:00", "heal", "hurt 10", "kill", "stamina", "speed 5", "quit"
	]:
		var result := console.run(line)
		assert_false(result.is_empty(), "`%s` said nothing at all" % line)
		# "unknown command" is also non-empty, and would pass this vacuously.
		assert_false(result.contains("unknown"), "`%s` is not registered: %s" % [line, result])
		assert_false(result.contains("does nothing"), "`%s` lost its callable: %s" % [line, result])


func test_teleport_moves_the_player_onto_the_ground() -> void:
	var world := _mount_world()
	var ui := _ui(world)
	var player: CharacterBody3D = world.get_node("Player")
	var terrain: Terrain = world.get_node("Terrain")

	ui.submit("tp 12 -9")
	assert_true(is_equal_approx(player.global_position.x, 12.0))
	assert_true(is_equal_approx(player.global_position.z, -9.0))
	var ground := terrain.height_at_world(Vector3(12.0, 0.0, -9.0))
	assert_true(
		absf(player.global_position.y - ground) < 0.5,
		"landed at %f with the ground at %f" % [player.global_position.y, ground]
	)


func test_teleport_refuses_something_that_is_not_a_coordinate() -> void:
	var world := _mount_world()
	var player: CharacterBody3D = world.get_node("Player")
	var before := player.global_position

	var result := _ui(world).submit("tp north 4")
	assert_true(result.contains("number"), "got %s" % result)
	assert_eq(player.global_position, before, "the player moved on a bad command")


func test_time_sets_the_clock() -> void:
	var world := _mount_world()
	_ui(world).submit("time 12:00")
	var day_night: DayNightComponent = world.get_node("DayNight")
	assert_eq(day_night.time_string(), "12:00")
	assert_true(day_night.is_daytime())

	_ui(world).submit("time 0")
	assert_false(day_night.is_daytime())


func test_time_accepts_bare_hours() -> void:
	var world := _mount_world()
	_ui(world).submit("time 18")
	assert_eq((world.get_node("DayNight") as DayNightComponent).time_string(), "18:00")


func test_time_refuses_nonsense() -> void:
	var world := _mount_world()
	var before := (world.get_node("DayNight") as DayNightComponent).time_string()
	assert_true(_ui(world).submit("time teatime").contains("not a time"))
	assert_eq((world.get_node("DayNight") as DayNightComponent).time_string(), before)


func test_hurt_and_heal_move_health() -> void:
	var world := _mount_world()
	var health: HealthComponent = world.get_node("Player/Health")

	_ui(world).submit("hurt 30")
	assert_eq(health.current(), 70.0)
	_ui(world).submit("heal 10")
	assert_eq(health.current(), 80.0)
	_ui(world).submit("heal")
	assert_eq(health.current(), health.maximum(), "bare heal should fill the bar")


func test_kill_empties_health() -> void:
	var world := _mount_world()
	var health: HealthComponent = world.get_node("Player/Health")
	_ui(world).submit("kill")
	assert_false(health.is_alive())


func test_stamina_sets_the_bar_and_lifts_exhaustion() -> void:
	var world := _mount_world()
	var stamina: StaminaComponent = world.get_node("Player/Stamina")
	for _tick in 600:
		stamina.request_drain()
		stamina.step(1.0 / 60.0)
	assert_true(stamina.is_exhausted(), "could not exhaust the bar to set up the test")

	_ui(world).submit("stamina")
	assert_eq(stamina.current(), stamina.maximum())
	assert_false(stamina.is_exhausted(), "a full bar that still cannot sprint looks broken")


func test_speed_changes_only_this_actor() -> void:
	var world := _mount_world()
	var movement: MovementComponent = world.get_node("Player/Movement")
	_ui(world).submit("speed 9")
	assert_true(is_equal_approx(movement.config.walk_speed, 9.0))

	var other: MovementConfig = load("res://resources/movement/player_movement.tres")
	assert_false(
		is_equal_approx(other.walk_speed, 9.0), "the console edited the shared movement resource"
	)


func test_speed_refuses_a_standstill() -> void:
	var world := _mount_world()
	assert_true(_ui(world).submit("speed 0").contains("positive"))


func test_where_reports_the_position() -> void:
	var world := _mount_world()
	_ui(world).submit("tp 5 5")
	var said := _ui(world).submit("where")
	assert_true(said.contains("5.00"), "got %s" % said)
	assert_true(said.contains("ground"), "got %s" % said)


func test_what_you_typed_is_echoed_above_the_answer() -> void:
	var world := _mount_world()
	_ui(world).submit("where")
	var lines := _ui(world).lines()
	assert_true(lines[lines.size() - 2].begins_with("> where"), "no echo of the command")


func test_clear_empties_the_scrollback() -> void:
	var world := _mount_world()
	_ui(world).submit("where")
	_ui(world).submit("clear")
	assert_true(_ui(world).lines().is_empty())


func test_the_clock_parser_reads_what_the_clock_prints() -> void:
	assert_true(is_equal_approx(DayNightCycle.time_from_clock("12:00"), 0.5))
	assert_true(is_equal_approx(DayNightCycle.time_from_clock("06:00"), 0.25))
	assert_true(is_equal_approx(DayNightCycle.time_from_clock("18"), 0.75))
	assert_true(is_zero_approx(DayNightCycle.time_from_clock("00:00")))


func test_the_clock_parser_refuses_what_is_not_a_time() -> void:
	for text: String in ["teatime", "", "25:00", "-1", "12:xx", "1:2:3"]:
		assert_true(
			DayNightCycle.time_from_clock(text) < 0.0, '"%s" was accepted as a time' % text
		)
