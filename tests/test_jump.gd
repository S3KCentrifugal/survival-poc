extends TestCase
## Jumping: the launch speed, the rising edge, what stops it, and the second one.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


## A player that believes it is standing on something, so jumping can be tested
## without a physics frame ever having run.
##
## Overrides *only* where the ground is. An earlier version overrode
## [method MovementComponent.consume_jump] itself, which meant every test below
## was checking a copy of the rule written in this file rather than the one the
## game runs -- and the copy quietly stopped matching the moment air jumps were
## added.
class GroundedMovement:
	extends MovementComponent

	var grounded: bool = true

	func is_grounded() -> bool:
		return grounded


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _grounded_actor() -> GroundedMovement:
	var tree := Engine.get_main_loop() as SceneTree
	var body := CharacterBody3D.new()
	tree.root.add_child(body)
	_mounted.append(body)

	var movement := GroundedMovement.new()
	movement.body = body
	movement.config = load("res://resources/movement/player_movement.tres").duplicate()
	movement.input_source = ScriptedInputSource.new()
	body.add_child(movement)
	return movement


func _source_of(movement: MovementComponent) -> ScriptedInputSource:
	return movement.input_source


func test_the_config_carries_a_jump_height() -> void:
	var config: MovementConfig = load("res://resources/movement/player_movement.tres")
	assert_true(config.jump_height > 0.0, "the character cannot leave the ground")


func test_the_action_is_bound() -> void:
	assert_true(
		InputMap.has_action(PlayerInputSource.ACTION_JUMP),
		"the jump action is not in the InputMap, so no key produces one"
	)


## v = sqrt(2gh), so the launch speed reaches exactly the height asked for.
func test_the_launch_speed_reaches_the_height_asked_for() -> void:
	var gravity := 20.0
	for height: float in [0.5, 1.1, 2.0]:
		var speed := MovementSolver.jump_velocity(height, gravity)
		# Time to the top, and the distance covered getting there.
		var apex := speed * speed / (2.0 * gravity)
		assert_true(
			is_equal_approx(apex, height), "%f m of jump reached %f m" % [height, apex]
		)


func test_no_jump_height_means_no_jump() -> void:
	assert_eq(MovementSolver.jump_velocity(0.0, 20.0), 0.0)
	assert_eq(MovementSolver.jump_velocity(-1.0, 20.0), 0.0)


func test_weightlessness_does_not_produce_a_nan() -> void:
	assert_eq(MovementSolver.jump_velocity(1.0, 0.0), 0.0)
	assert_false(is_nan(MovementSolver.jump_velocity(1.0, 0.0)))


func test_pressing_jump_leaves_the_ground() -> void:
	var movement := _grounded_actor()
	_source_of(movement).jump(true)
	movement.step(STEP)
	assert_true(movement.body.velocity.y > 0.0, "the actor did not launch")


func test_not_pressing_jump_keeps_the_feet_down() -> void:
	var movement := _grounded_actor()
	movement.step(STEP)
	assert_true(movement.body.velocity.y <= 0.0)


## A held key must not be a jump on every tick, or the character hovers.
func test_holding_the_key_jumps_once() -> void:
	var movement := _grounded_actor()
	_source_of(movement).jump(true)

	var launches := 0
	for _frame in 20:
		if movement.consume_jump(_source_of(movement).poll()):
			launches += 1
	assert_eq(launches, 1, "a held key launched %d times" % launches)


func test_releasing_and_pressing_again_jumps_again() -> void:
	var movement := _grounded_actor()
	var source := _source_of(movement)

	source.jump(true)
	assert_true(movement.consume_jump(source.poll()))
	source.jump(false)
	movement.consume_jump(source.poll())
	source.jump(true)
	assert_true(movement.consume_jump(source.poll()), "the second press did nothing")


## Nothing gains a second jump by sharing [MovementConfig]. It is the player's
## move, and a wanderer that could double jump would be a surprise nobody asked
## for.
func test_without_air_jumps_you_cannot_jump_in_mid_air() -> void:
	var movement := _grounded_actor()
	movement.config.air_jumps = 0
	var source := _source_of(movement)

	source.jump(true)
	assert_true(movement.consume_jump(source.poll()))
	movement.grounded = false
	source.jump(false)
	movement.consume_jump(source.poll())
	source.jump(true)
	assert_false(movement.consume_jump(source.poll()), "jumped again with no ground underfoot")


func test_the_player_can_jump_twice() -> void:
	var config: MovementConfig = load("res://resources/movement/player_movement.tres")
	assert_eq(config.air_jumps, 1, "the player has no double jump")


func _press(movement: GroundedMovement) -> bool:
	# A press is a release and a press: the rising edge is what launches.
	var source := _source_of(movement)
	source.jump(false)
	movement.consume_jump(source.poll())
	source.jump(true)
	return movement.consume_jump(source.poll())


func test_the_second_jump_happens_in_the_air() -> void:
	var movement := _grounded_actor()
	assert_true(_press(movement), "the first jump did not launch")

	movement.grounded = false
	assert_true(_press(movement), "the second jump did nothing")
	assert_eq(movement.air_jumps_used(), 1)


## Two, not unlimited. The count is what separates a double jump from flight.
func test_there_is_no_third_jump() -> void:
	var movement := _grounded_actor()
	_press(movement)
	movement.grounded = false
	_press(movement)
	assert_false(_press(movement), "the character can fly")


## One press must not spend both jumps in consecutive ticks.
func test_holding_the_key_does_not_spend_the_second_jump() -> void:
	var movement := _grounded_actor()
	var source := _source_of(movement)
	source.jump(true)

	var launches := 0
	for _frame in 30:
		if movement.consume_jump(source.poll()):
			launches += 1
		# Off the ground from the tick after the launch, as it would be.
		movement.grounded = launches == 0
	assert_eq(launches, 1, "a held key launched %d times" % launches)


func test_landing_gives_the_second_jump_back() -> void:
	var movement := _grounded_actor()
	_press(movement)
	movement.grounded = false
	_press(movement)
	assert_eq(movement.air_jumps_used(), 1)

	movement.grounded = true
	movement.consume_jump(_source_of(movement).poll())
	assert_eq(movement.air_jumps_used(), 0, "landing did not restore the air jump")
	assert_true(_press(movement), "could not jump again after landing")


## Walking off a ledge should leave the air jump available -- it was never
## spent, and a player who steps off an edge reaching for it has not done
## anything wrong.
func test_walking_off_a_ledge_keeps_the_air_jump() -> void:
	var movement := _grounded_actor()
	# Never jumped; simply ran out of floor.
	movement.consume_jump(_source_of(movement).poll())
	movement.grounded = false
	assert_true(_press(movement), "stepping off an edge cost the air jump")


## The launch replaces vertical velocity rather than adding to it, so the second
## jump is worth the same whether it is used at the apex or halfway down.
func test_the_second_jump_is_worth_as_much_when_falling() -> void:
	var movement := _grounded_actor()
	var expected := MovementSolver.jump_velocity(
		movement.config.jump_height, movement.config.gravity
	)

	movement.grounded = false
	movement.body.velocity.y = -12.0
	var source := _source_of(movement)
	source.jump(true)
	movement.step(STEP)
	assert_true(
		is_equal_approx(movement.body.velocity.y, expected),
		"a falling double jump launched at %f instead of %f" % [movement.body.velocity.y, expected]
	)


func test_it_announces_the_launch() -> void:
	var movement := _grounded_actor()
	var launches := [0]
	movement.jumped.connect(func() -> void: launches[0] += 1)

	_source_of(movement).jump(true)
	for _frame in 10:
		movement.step(STEP)
	assert_eq(launches[0], 1, "jumped signal fired %d times" % launches[0])


## Gravity is applied while solving velocity, so a launch written before that
## would be cancelled in the same tick it happened.
func test_gravity_does_not_swallow_the_launch() -> void:
	var movement := _grounded_actor()
	_source_of(movement).jump(true)
	movement.step(STEP)
	var expected := MovementSolver.jump_velocity(
		movement.config.jump_height, movement.config.gravity
	)
	assert_true(
		is_equal_approx(movement.body.velocity.y, expected),
		"launched at %f instead of %f" % [movement.body.velocity.y, expected]
	)


func test_jumping_does_not_stop_you_moving() -> void:
	var movement := _grounded_actor()
	var source := _source_of(movement)
	source.move_towards_direction(Vector2(1.0, 0.0))
	source.jump(true)

	movement.step(STEP)
	assert_true(movement.body.velocity.x > 0.0, "the jump killed the run-up")
	assert_true(movement.body.velocity.y > 0.0)


func test_the_rig_has_the_clip_the_config_names() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	tree.root.add_child(player)
	_mounted.append(player)

	var animation: AnimationComponent = player.get_node("Animation")
	var rig: AnimationPlayer = animation.animation_player
	assert_true(
		rig.has_animation(animation.config.jump_animation),
		'no clip named "%s" in %s' % [animation.config.jump_animation, rig.get_animation_list()]
	)
