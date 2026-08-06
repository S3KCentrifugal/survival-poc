extends TestCase
## The animation component: reading motion off a body and announcing the state.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const CONFIG_RESOURCE: String = "res://resources/animation/player_animation.tres"


## An animation component standing on solid ground.
##
## Substituting the floor query is the only way to test the ground states off a
## physics frame: a body that has never been through move_and_slide reports
## airborne, which would pin everything here to falling.
class GroundedAnimation:
	extends AnimationComponent

	var grounded: bool = true

	func on_floor() -> bool:
		return grounded


func _grounded_actor() -> GroundedAnimation:
	# Mounted, not bare: anything that ends up calling move_and_slide needs a
	# body that is actually in the tree, or the transform lookups fail.
	var body := CharacterBody3D.new()
	mount(body)

	var config := AnimationConfig.new()
	config.move_enter_speed = 0.4
	config.move_exit_speed = 0.15

	var animation := GroundedAnimation.new()
	animation.body = body
	animation.config = config
	body.add_child(animation)
	return animation


func _mount_player() -> CharacterBody3D:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	mount(player)
	return player


func test_the_config_resource_loads() -> void:
	var config: AnimationConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not an AnimationConfig" % CONFIG_RESOURCE)
	assert_true(
		config.move_exit_speed <= config.move_enter_speed, "the hysteresis band is inverted"
	)


func test_the_player_carries_an_animation_component() -> void:
	var player := _mount_player()
	var animation: AnimationComponent = player.get_node_or_null("Animation")
	assert_not_null(animation, "the player scene has no animation component")
	assert_eq(animation.body, player, "body reference is not wired in the scene")
	assert_not_null(animation.movement, "sprinting would never reach the state machine")
	assert_not_null(animation.config, "config is not wired in the scene")


func test_the_player_scene_wires_the_rig() -> void:
	var player := _mount_player()
	var animation: AnimationComponent = player.get_node("Animation")
	assert_not_null(animation.animation_player, "the model's AnimationPlayer is not wired")


## The clip names live in a .tres and the clips live in a .glb, and nothing
## connects the two but a string. Renaming either silently stops the character
## animating -- it just stands there, which reads as a physics bug.
func test_every_clip_the_config_names_exists_in_the_rig() -> void:
	var player := _mount_player()
	var animation: AnimationComponent = player.get_node("Animation")
	var rig: AnimationPlayer = animation.animation_player
	var config: AnimationConfig = animation.config

	for clip: StringName in [
		config.idle_animation,
		config.walk_animation,
		config.run_animation,
		config.fall_animation
	]:
		assert_true(
			rig.has_animation(clip),
			'the rig has no clip named "%s" -- it has %s' % [clip, rig.get_animation_list()]
		)


func test_a_still_actor_is_idle() -> void:
	var animation := _grounded_actor()
	animation.step()
	assert_eq(animation.state_name(), &"idle")


func test_a_moving_body_walks() -> void:
	var animation := _grounded_actor()
	animation.body.velocity = Vector3(3.0, 0.0, 0.0)
	animation.step()
	assert_eq(animation.state_name(), &"walk")


## Vertical motion is not travel: a body dropping down a hole would otherwise
## read as sprinting.
func test_falling_straight_down_is_not_walking() -> void:
	var animation := _grounded_actor()
	animation.body.velocity = Vector3(0.0, -30.0, 0.0)
	animation.step()
	assert_eq(animation.state_name(), &"idle")


func test_leaving_the_ground_falls() -> void:
	var animation := _grounded_actor()
	animation.body.velocity = Vector3(3.0, 0.0, 0.0)
	animation.step()
	animation.grounded = false
	animation.step()
	assert_eq(animation.state_name(), &"fall")


func test_sprinting_is_read_from_the_movement_component() -> void:
	var animation := _grounded_actor()
	var movement := MovementComponent.new()
	movement.config = MovementConfig.new()
	movement.body = animation.body
	movement.stamina = null
	animation.body.add_child(movement)

	var source := ScriptedInputSource.new()
	source.move_towards_direction(Vector2(1.0, 0.0))
	source.sprint(true)
	movement.input_source = source
	movement.step(1.0 / 60.0)

	animation.movement = movement
	animation.body.velocity = Vector3(7.0, 0.0, 0.0)
	animation.step()
	assert_eq(animation.state_name(), &"run")


func test_without_a_movement_component_it_never_runs() -> void:
	var animation := _grounded_actor()
	assert_false(animation.is_sprinting())
	animation.body.velocity = Vector3(9.0, 0.0, 0.0)
	animation.step()
	assert_eq(animation.state_name(), &"walk")


## Announcing on every frame would make a listener debounce for itself.
func test_a_transition_is_announced_once() -> void:
	var animation := _grounded_actor()
	var announced: Array[int] = []
	animation.state_changed.connect(func(state: int) -> void: announced.append(state))

	animation.body.velocity = Vector3(3.0, 0.0, 0.0)
	for _frame in 10:
		animation.step()
	assert_eq(announced.size(), 1, "announced %d times for one transition" % announced.size())
	assert_eq(announced[0], AnimationStateMachine.State.WALK)


func test_it_plays_the_clip_for_the_state() -> void:
	var animation := _grounded_actor()
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	library.add_animation(&"idle", Animation.new())
	library.add_animation(&"walk", Animation.new())
	player.add_animation_library(&"", library)
	animation.body.add_child(player)
	animation.animation_player = player

	animation.body.velocity = Vector3(3.0, 0.0, 0.0)
	animation.step()
	assert_eq(player.current_animation, "walk")


## A placeholder rig with only an idle should still idle, not spam the log on
## every transition it cannot honour.
func test_a_missing_clip_is_not_an_error() -> void:
	var animation := _grounded_actor()
	var player := AnimationPlayer.new()
	var library := AnimationLibrary.new()
	library.add_animation(&"idle", Animation.new())
	player.add_animation_library(&"", library)
	animation.body.add_child(player)
	animation.animation_player = player

	animation.body.velocity = Vector3(3.0, 0.0, 0.0)
	animation.step()
	assert_eq(animation.state_name(), &"walk", "the state must advance even with no clip")
	assert_eq(player.current_animation, "", "played a clip the rig does not have")
