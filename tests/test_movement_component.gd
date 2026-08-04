extends TestCase
## The movement component and the assembled player scene.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const CONFIG_RESOURCE: String = "res://resources/movement/player_movement.tres"
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


func _movement_of(player: CharacterBody3D) -> MovementComponent:
	return player.get_node("Movement")


func test_the_config_resource_loads() -> void:
	var config: MovementConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not a MovementConfig" % CONFIG_RESOURCE)
	assert_true(config.walk_speed > 0.0)
	assert_true(is_equal_approx(config.turn_speed_radians(), deg_to_rad(config.turn_speed_degrees)))


func test_the_player_scene_is_assembled() -> void:
	var player := _mount_player()
	assert_true(player is CharacterBody3D, "the player must collide")
	assert_not_null(player.get_node_or_null("CollisionShape3D"), "no collision shape")
	assert_not_null(player.get_node_or_null("Body"), "no visible body")
	assert_not_null(player.get_node_or_null("Movement"), "no movement component")


## The component must not reach upward for its collaborators, so the scene has
## to hand it a body explicitly.
func test_the_component_is_wired_to_its_body() -> void:
	var player := _mount_player()
	var movement := _movement_of(player)
	assert_eq(movement.body, player, "body reference is not wired in the scene")
	assert_not_null(movement.config, "config is not wired in the scene")


func test_nothing_moves_without_an_input_source() -> void:
	# Deliberate: an actor with no source is inert rather than crashing.
	var player := _mount_player()
	var movement := _movement_of(player)
	assert_null(movement.input_source)
	movement.step(STEP)
	assert_eq(player.velocity, Vector3.ZERO)


func test_it_accelerates_in_the_commanded_direction() -> void:
	var player := _mount_player()
	var movement := _movement_of(player)
	var source := ScriptedInputSource.new()
	movement.input_source = source

	source.move_towards_direction(Vector2(1.0, 0.0))
	var velocity := movement.solve_velocity(source.poll(), STEP)
	assert_true(velocity.x > 0.0, "did not accelerate along +x")
	assert_true(is_zero_approx(velocity.z))


func test_an_airborne_actor_is_pulled_down() -> void:
	var player := _mount_player()
	var movement := _movement_of(player)
	movement.input_source = ScriptedInputSource.new()

	var velocity := movement.solve_velocity(movement.input_source.poll(), STEP)
	assert_true(velocity.y < 0.0, "gravity was not applied off the ground")


## Facing the cursor while walking a different way is the whole point of a
## top-down control scheme.
func test_aim_beats_movement_for_facing() -> void:
	var player := _mount_player()
	player.global_position = Vector3.ZERO
	var movement := _movement_of(player)
	var source := ScriptedInputSource.new()
	movement.input_source = source

	source.move_towards_direction(Vector2(1.0, 0.0))  # walking +x
	source.aim_at(Vector3(0.0, 0.0, -10.0))           # looking -z

	var target: Variant = movement.facing_target(source.poll())
	assert_not_null(target)
	assert_true(
		is_zero_approx(angle_difference(target, MovementSolver.yaw_towards(Vector2(0.0, -1.0)))),
		"should face the aim point, not the walk direction"
	)


func test_without_aim_it_faces_where_it_walks() -> void:
	var player := _mount_player()
	var movement := _movement_of(player)
	var source := ScriptedInputSource.new()
	movement.input_source = source

	source.move_towards_direction(Vector2(1.0, 0.0))
	var target: Variant = movement.facing_target(source.poll())
	assert_not_null(target)
	assert_true(
		is_zero_approx(angle_difference(target, MovementSolver.yaw_towards(Vector2(1.0, 0.0))))
	)


func test_standing_still_keeps_its_current_facing() -> void:
	# Snapping to a default heading when the player lets go looks like a twitch.
	var player := _mount_player()
	var movement := _movement_of(player)
	movement.input_source = ScriptedInputSource.new()
	assert_null(movement.facing_target(movement.input_source.poll()))


func test_aiming_at_your_own_feet_is_not_a_facing_command() -> void:
	# The cursor passes over the character constantly; the direction to it is
	# zero-length there and must not produce a garbage yaw.
	var player := _mount_player()
	player.global_position = Vector3(3.0, 0.0, 3.0)
	var movement := _movement_of(player)
	var source := ScriptedInputSource.new()
	movement.input_source = source

	source.aim_at(Vector3(3.0, 0.0, 3.0))
	assert_null(movement.facing_target(source.poll()))


func test_turning_reaches_the_aim_over_several_frames() -> void:
	var player := _mount_player()
	player.global_position = Vector3.ZERO
	player.rotation.y = 0.0
	var movement := _movement_of(player)
	var source := ScriptedInputSource.new()
	movement.input_source = source
	source.aim_at(Vector3(10.0, 0.0, 0.0))

	for _frame in 120:
		movement.apply_facing(source.poll(), STEP)

	var expected := MovementSolver.yaw_towards(Vector2(1.0, 0.0))
	assert_true(
		is_zero_approx(angle_difference(player.rotation.y, expected)),
		"settled at %f, wanted %f" % [player.rotation.y, expected]
	)
