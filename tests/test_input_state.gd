extends TestCase
## The intent payload.


func test_a_fresh_state_is_neutral() -> void:
	var state := InputState.new()
	assert_eq(state.move, Vector2.ZERO)
	assert_false(state.sprint)
	assert_false(state.has_aim, "aim must be invalid until something resolves it")
	assert_false(state.is_moving())


func test_is_moving_ignores_negligible_input() -> void:
	var state := InputState.new()
	state.move = Vector2(0.0000001, 0.0)
	assert_false(state.is_moving(), "stick drift is not movement")
	state.move = Vector2(0.5, 0.0)
	assert_true(state.is_moving())


func test_move_3d_lies_on_the_ground_plane() -> void:
	var state := InputState.new()
	state.move = Vector2(0.6, -0.8)
	assert_eq(state.move_3d(), Vector3(0.6, 0.0, -0.8))


## Sources may reuse one state object between ticks, so anything that stores
## intent has to copy it or it will silently alias live data.
func test_copy_is_independent() -> void:
	var state := InputState.new()
	state.move = Vector2(1.0, 0.0)
	state.sprint = true
	state.aim_point = Vector3(5.0, 0.0, 5.0)
	state.has_aim = true

	var snapshot := state.copy()
	state.move = Vector2.ZERO
	state.sprint = false
	state.has_aim = false

	assert_eq(snapshot.move, Vector2(1.0, 0.0))
	assert_true(snapshot.sprint)
	assert_eq(snapshot.aim_point, Vector3(5.0, 0.0, 5.0))
	assert_true(snapshot.has_aim)


func test_clear_returns_to_neutral() -> void:
	var state := InputState.new()
	state.move = Vector2(1.0, 1.0)
	state.sprint = true
	state.has_aim = true
	state.clear()

	assert_eq(state.move, Vector2.ZERO)
	assert_false(state.sprint)
	assert_false(state.has_aim)
