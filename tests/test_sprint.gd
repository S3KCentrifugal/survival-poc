extends TestCase
## Sprint: movement asking stamina to pay for speed.
##
## The two components are useful apart, so the interesting cases are all about
## the seam between them -- who decides, who pays, and what happens when the
## bar runs out.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount_player() -> CharacterBody3D:
	var tree := Engine.get_main_loop() as SceneTree
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	tree.root.add_child(player)
	_mounted.append(player)
	return player


func _sprinting_input() -> ScriptedInputSource:
	var source := ScriptedInputSource.new()
	source.move_towards_direction(Vector2(1.0, 0.0))
	source.sprint(true)
	return source


## Runs the pair the way the scene does: movement decides and requests, stamina
## ticks afterwards and pays.
func _tick(movement: MovementComponent, source: ScriptedInputSource, seconds: float) -> void:
	for _frame in int(round(seconds / STEP)):
		movement.consume_sprint(source.poll())
		movement.stamina.step(STEP)


func test_the_config_carries_a_sprint_multiplier() -> void:
	var config: MovementConfig = load("res://resources/movement/player_movement.tres")
	assert_true(config.sprint_multiplier > 1.0, "sprinting would be no faster than walking")


func test_speed_for_applies_the_multiplier_only_when_sprinting() -> void:
	assert_eq(MovementSolver.speed_for(4.0, 2.0, false), 4.0)
	assert_eq(MovementSolver.speed_for(4.0, 2.0, true), 8.0)


## A multiplier below 1 would make sprinting a penalty, which is never what a
## mistyped .tres meant.
func test_a_multiplier_below_one_cannot_slow_an_actor_down() -> void:
	assert_eq(MovementSolver.speed_for(4.0, 0.5, true), 4.0)


func test_the_player_scene_wires_movement_to_stamina() -> void:
	var player := _mount_player()
	var movement: MovementComponent = player.get_node("Movement")
	assert_not_null(movement.stamina, "sprint would never cost anything")
	assert_eq(movement.stamina, player.get_node("Stamina"))


func test_sprinting_reaches_a_higher_top_speed() -> void:
	var player := _mount_player()
	var movement: MovementComponent = player.get_node("Movement")
	var source := _sprinting_input()

	var walking := Vector3.ZERO
	var sprinting := Vector3.ZERO
	for _frame in 300:
		player.velocity = walking
		walking = movement.solve_velocity(source.poll(), STEP, false)
		player.velocity = sprinting
		sprinting = movement.solve_velocity(source.poll(), STEP, true)

	# Ground speed only. Nothing holds this test actor up, so by frame 300 the
	# fall dominates the 3D magnitude and both would look identical.
	var ratio := (
		Vector2(sprinting.x, sprinting.z).length() / Vector2(walking.x, walking.z).length()
	)
	assert_true(
		is_equal_approx(ratio, movement.config.sprint_multiplier),
		"sprinting was %f times walking speed" % ratio
	)


func test_sprinting_costs_stamina() -> void:
	var player := _mount_player()
	var movement: MovementComponent = player.get_node("Movement")
	var source := _sprinting_input()

	var before := movement.stamina.current()
	_tick(movement, source, 1.0)
	assert_true(movement.stamina.current() < before, "a second of sprinting was free")


## Without the movement check, holding the key while standing still drains the
## bar for nothing and the player arrives at the fight already tired.
func test_sprinting_on_the_spot_is_not_sprinting() -> void:
	var player := _mount_player()
	var movement: MovementComponent = player.get_node("Movement")
	var source := ScriptedInputSource.new()
	source.sprint(true)  # key held, no direction

	assert_false(movement.consume_sprint(source.poll()))
	_tick(movement, source, 1.0)
	assert_eq(movement.stamina.current(), movement.stamina.maximum(), "standing still cost stamina")


func test_walking_costs_no_stamina() -> void:
	var player := _mount_player()
	var movement: MovementComponent = player.get_node("Movement")
	var source := ScriptedInputSource.new()
	source.move_towards_direction(Vector2(1.0, 0.0))

	_tick(movement, source, 1.0)
	assert_eq(movement.stamina.current(), movement.stamina.maximum())


func test_an_exhausted_actor_drops_back_to_a_walk() -> void:
	var player := _mount_player()
	var movement: MovementComponent = player.get_node("Movement")
	var source := _sprinting_input()

	# Long enough to empty the bar at any sane tuning.
	_tick(movement, source, 30.0)
	assert_true(movement.stamina.is_exhausted(), "30s of sprinting did not exhaust")
	assert_false(movement.consume_sprint(source.poll()), "sprinted while exhausted")


## An actor with no stamina component runs as long as it likes -- which is what
## a deer should do, and what an enemy does until it is given a bar of its own.
func test_an_actor_without_stamina_sprints_freely() -> void:
	var movement := MovementComponent.new()
	movement.config = MovementConfig.new()
	_mounted.append(movement)

	var source := _sprinting_input()
	assert_null(movement.stamina)
	assert_true(movement.consume_sprint(source.poll()))


func test_it_reports_whether_it_sprinted() -> void:
	var player := _mount_player()
	var movement: MovementComponent = player.get_node("Movement")
	assert_false(movement.is_sprinting(), "sprinting before it has ever moved")

	var source := _sprinting_input()
	movement.input_source = source
	movement.step(STEP)
	assert_true(movement.is_sprinting())

	source.sprint(false)
	movement.step(STEP)
	assert_false(movement.is_sprinting())
