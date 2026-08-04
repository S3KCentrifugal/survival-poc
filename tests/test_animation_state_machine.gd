extends TestCase
## Turning motion into an animation state, and the hysteresis that keeps it
## from flickering.

var _config: AnimationConfig


func before_each() -> void:
	_config = AnimationConfig.new()
	_config.move_enter_speed = 0.4
	_config.move_exit_speed = 0.15


func _machine() -> AnimationStateMachine:
	return AnimationStateMachine.new(_config)


func _name_of(state: AnimationStateMachine.State) -> String:
	return String(AnimationStateMachine.state_name(state))


func test_it_starts_idle() -> void:
	assert_eq(_machine().state(), AnimationStateMachine.State.IDLE)


func test_a_standing_actor_is_idle() -> void:
	var machine := _machine()
	assert_eq(machine.update(0.0, false, true), AnimationStateMachine.State.IDLE)


func test_walking_speed_walks() -> void:
	var machine := _machine()
	var state := machine.update(3.0, false, true)
	assert_eq(state, AnimationStateMachine.State.WALK, "got %s" % _name_of(state))


func test_sprinting_runs() -> void:
	var machine := _machine()
	var state := machine.update(7.0, true, true)
	assert_eq(state, AnimationStateMachine.State.RUN, "got %s" % _name_of(state))


## The flag alone is not enough: an actor holding the sprint key against a wall
## is going nowhere and should not be playing a run.
func test_sprinting_on_the_spot_is_still_idle() -> void:
	var machine := _machine()
	var state := machine.update(0.0, true, true)
	assert_eq(state, AnimationStateMachine.State.IDLE, "got %s" % _name_of(state))


## Ground speed only: an actor falling straight down is not walking.
func test_leaving_the_ground_falls() -> void:
	var machine := _machine()
	machine.update(5.0, false, true)
	var state := machine.update(5.0, false, false)
	assert_eq(state, AnimationStateMachine.State.FALL, "got %s" % _name_of(state))


func test_landing_returns_to_the_ground_states() -> void:
	var machine := _machine()
	machine.update(0.0, false, false)
	assert_eq(machine.update(3.0, false, true), AnimationStateMachine.State.WALK)


func test_a_crawl_below_the_enter_speed_stays_idle() -> void:
	var machine := _machine()
	assert_eq(machine.update(0.3, false, true), AnimationStateMachine.State.IDLE)


## The whole point of two thresholds. With one, an actor drifting at exactly
## that speed flips every frame, restarting the clip over and over.
func test_a_moving_actor_keeps_moving_below_the_enter_speed() -> void:
	var machine := _machine()
	machine.update(3.0, false, true)
	assert_eq(
		machine.update(0.3, false, true),
		AnimationStateMachine.State.WALK,
		"dropped to idle inside the hysteresis band"
	)


func test_it_stops_below_the_exit_speed() -> void:
	var machine := _machine()
	machine.update(3.0, false, true)
	assert_eq(machine.update(0.1, false, true), AnimationStateMachine.State.IDLE)


func test_speed_hovering_at_the_boundary_does_not_flicker() -> void:
	var machine := _machine()
	var transitions := 0
	var previous := machine.state()
	for frame in 100:
		# Straddles move_enter_speed by a hair, sixty times a second.
		var speed := 0.4 + (0.01 if frame % 2 == 0 else -0.01)
		var state := machine.update(speed, false, true)
		if state != previous:
			transitions += 1
			previous = state
	assert_eq(transitions, 1, "flipped state %d times" % transitions)


## A .tres with the two the wrong way round would flicker worse than a single
## threshold, so the exit speed is capped rather than trusted.
func test_a_backwards_config_cannot_make_it_flicker() -> void:
	_config.move_enter_speed = 0.2
	_config.move_exit_speed = 2.0
	var machine := _machine()
	machine.update(0.5, false, true)
	assert_eq(
		machine.update(0.3, false, true),
		AnimationStateMachine.State.WALK,
		"the inverted exit speed stopped an actor that was still moving"
	)


func test_each_state_maps_to_its_clip() -> void:
	_config.idle_animation = &"stand"
	_config.walk_animation = &"stroll"
	_config.run_animation = &"dash"
	_config.fall_animation = &"plummet"
	var machine := _machine()

	assert_eq(machine.animation_for(AnimationStateMachine.State.IDLE), &"stand")
	assert_eq(machine.animation_for(AnimationStateMachine.State.WALK), &"stroll")
	assert_eq(machine.animation_for(AnimationStateMachine.State.RUN), &"dash")
	assert_eq(machine.animation_for(AnimationStateMachine.State.FALL), &"plummet")


## The overlay reads these; they must not follow whatever a rig calls its clips.
func test_state_names_are_independent_of_the_clip_names() -> void:
	_config.walk_animation = &"stroll"
	assert_eq(AnimationStateMachine.state_name(AnimationStateMachine.State.WALK), &"walk")
	assert_eq(AnimationStateMachine.state_name(AnimationStateMachine.State.RUN), &"run")
	assert_eq(AnimationStateMachine.state_name(AnimationStateMachine.State.FALL), &"fall")
	assert_eq(AnimationStateMachine.state_name(AnimationStateMachine.State.IDLE), &"idle")
