extends TestCase
## The keyboard-and-cursor source, and the maths it depends on.

const FORWARD_RAW: Vector2 = Vector2(0.0, -1.0) # Input.get_vector: forward is -y.
const RIGHT_RAW: Vector2 = Vector2(1.0, 0.0)

var source: PlayerInputSource


func before_each() -> void:
	source = PlayerInputSource.new()


func after_each() -> void:
	# Action state is global and survives the test that set it.
	for action: StringName in PlayerInputSource.REQUIRED_ACTIONS:
		Input.action_release(action)


## Without these the source silently reads nothing and the player cannot move.
func test_every_required_action_is_bound() -> void:
	for action: StringName in PlayerInputSource.REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "InputMap is missing '%s'" % action)


func test_wasd_is_bound_by_physical_key() -> void:
	# Physical keycodes keep WASD under the same fingers on AZERTY and Dvorak.
	var expected: Dictionary = {
		KEY_W: PlayerInputSource.ACTION_MOVE_FORWARD,
		KEY_S: PlayerInputSource.ACTION_MOVE_BACK,
		KEY_A: PlayerInputSource.ACTION_MOVE_LEFT,
		KEY_D: PlayerInputSource.ACTION_MOVE_RIGHT,
		KEY_SHIFT: PlayerInputSource.ACTION_SPRINT,
	}
	for code: Key in expected:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = true
		assert_true(
			InputMap.event_is_action(event, expected[code]),
			"key %d is not bound to %s" % [code, expected[code]]
		)


func test_forward_at_yaw_zero_walks_into_the_screen() -> void:
	# The camera sits on +Z looking toward -Z, so forward is -Z.
	var world := PlayerInputSource.to_world_direction(FORWARD_RAW, 0.0)
	assert_true(is_zero_approx(world.x), "forward should not drift sideways")
	assert_true(world.y < 0.0, "forward should head toward -Z")


func test_right_at_yaw_zero_walks_to_positive_x() -> void:
	var world := PlayerInputSource.to_world_direction(RIGHT_RAW, 0.0)
	assert_true(world.x > 0.0)
	assert_true(is_zero_approx(world.y))


func test_movement_rotates_with_the_camera() -> void:
	# Turn the camera a quarter turn and forward must follow it.
	var world := PlayerInputSource.to_world_direction(FORWARD_RAW, deg_to_rad(90.0))
	assert_true(world.x < 0.0, "forward should now head toward -X")
	assert_true(is_zero_approx(world.y))


func test_rotation_preserves_magnitude() -> void:
	for yaw_degrees: float in [0.0, 45.0, 90.0, 217.0, 359.0]:
		var world := PlayerInputSource.to_world_direction(
			Vector2(0.0, -1.0), deg_to_rad(yaw_degrees)
		)
		assert_true(
			is_equal_approx(world.length(), 1.0),
			"yaw %f changed the speed (length %f)" % [yaw_degrees, world.length()]
		)


func test_no_input_produces_no_movement_at_any_yaw() -> void:
	for yaw_degrees: float in [0.0, 33.0, 180.0]:
		var world := PlayerInputSource.to_world_direction(Vector2.ZERO, deg_to_rad(yaw_degrees))
		assert_true(world.is_zero_approx())


func test_yaw_is_recovered_from_a_camera_basis() -> void:
	# Round-trip: frame from a known yaw, read it back off the basis.
	var config := CameraConfig.new()
	for yaw_degrees: float in [0.0, 45.0, 120.0, 300.0]:
		config.yaw_degrees = yaw_degrees
		var transform := CameraFraming.transform_for(Vector3.ZERO, config)
		var recovered := PlayerInputSource.yaw_from_basis(transform.basis)
		var expected := deg_to_rad(yaw_degrees)
		assert_true(
			is_equal_approx(cos(recovered), cos(expected))
				and is_equal_approx(sin(recovered), sin(expected)),
			"yaw %f came back as %f" % [yaw_degrees, rad_to_deg(recovered)]
		)


func test_aim_lands_where_the_ray_meets_the_plane() -> void:
	var hit: Variant = PlayerInputSource.ground_intersection(
		Vector3(0.0, 10.0, 0.0), Vector3.DOWN, 0.0
	)
	assert_not_null(hit)
	assert_eq(hit, Vector3.ZERO)


func test_aim_respects_the_plane_height() -> void:
	var hit: Variant = PlayerInputSource.ground_intersection(
		Vector3(2.0, 10.0, -3.0), Vector3.DOWN, 4.0
	)
	assert_eq(hit, Vector3(2.0, 4.0, -3.0))


func test_aim_at_the_sky_resolves_to_nothing() -> void:
	# Consumers must check has_aim; this is why.
	var hit: Variant = PlayerInputSource.ground_intersection(
		Vector3(0.0, 10.0, 0.0), Vector3.UP, 0.0
	)
	assert_null(hit)


func test_aim_parallel_to_the_ground_resolves_to_nothing() -> void:
	var hit: Variant = PlayerInputSource.ground_intersection(
		Vector3(0.0, 10.0, 0.0), Vector3.RIGHT, 0.0
	)
	assert_null(hit)


func test_polling_without_a_camera_is_safe() -> void:
	# The source outlives cameras and may be built before one exists.
	var state := source.poll()
	assert_false(state.has_aim, "no camera means no aim")
	assert_eq(source.camera_yaw(), 0.0, "should fall back to world axes")


func test_pressing_forward_moves_the_actor() -> void:
	Input.action_press(PlayerInputSource.ACTION_MOVE_FORWARD)
	var state := source.poll()
	assert_true(state.is_moving(), "a held key produced no intent")
	assert_true(state.move.y < 0.0, "forward should head toward -Z at yaw 0")


func test_opposing_keys_cancel() -> void:
	Input.action_press(PlayerInputSource.ACTION_MOVE_FORWARD)
	Input.action_press(PlayerInputSource.ACTION_MOVE_BACK)
	assert_false(source.poll().is_moving())


func test_diagonals_are_not_faster_than_straight_lines() -> void:
	# The classic bug: pressing two keys should not grant 41% more speed.
	Input.action_press(PlayerInputSource.ACTION_MOVE_FORWARD)
	Input.action_press(PlayerInputSource.ACTION_MOVE_RIGHT)
	var length := source.poll().move.length()
	assert_true(length <= 1.0001, "diagonal speed was %f" % length)


func test_sprint_is_reported() -> void:
	assert_false(source.poll().sprint)
	Input.action_press(PlayerInputSource.ACTION_SPRINT)
	assert_true(source.poll().sprint)
