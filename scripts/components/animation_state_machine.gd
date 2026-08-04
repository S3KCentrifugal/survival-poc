class_name AnimationStateMachine
extends RefCounted
## Decides which animation an actor should be playing.
##
## Deliberately knows nothing about rigs, clips or blending -- it turns motion
## into a state, and [AnimationComponent] turns that state into whatever the
## actor happens to be drawn with. That is what lets the state machine be tested
## with numbers instead of with a character model that does not exist yet.
##
## Stateful, because the interesting behaviour is hysteresis: the threshold for
## starting to move is higher than the threshold for stopping, so an actor
## drifting near the boundary settles instead of flickering.

enum State { IDLE, WALK, RUN, FALL }

var _config: AnimationConfig
var _state: State = State.IDLE


func _init(config: AnimationConfig) -> void:
	_config = config


## Recomputes the state from one tick of motion and returns it.
##
## [param ground_speed] is horizontal only: an actor falling straight down is
## not walking, and a lift is not a sprint.
func update(ground_speed: float, sprinting: bool, on_floor: bool) -> State:
	if not on_floor:
		_state = State.FALL
	elif not _is_moving(ground_speed):
		_state = State.IDLE
	elif sprinting:
		_state = State.RUN
	else:
		_state = State.WALK
	return _state


func state() -> State:
	return _state


## Which clip name this state maps to, given the actor's config.
func animation_for(state_value: State) -> StringName:
	match state_value:
		State.WALK:
			return _config.walk_animation
		State.RUN:
			return _config.run_animation
		State.FALL:
			return _config.fall_animation
		_:
			return _config.idle_animation


## Human-readable state, for the debug overlay and test failure messages. Kept
## separate from the clip names, which belong to whatever rig is attached.
static func state_name(state_value: State) -> StringName:
	match state_value:
		State.WALK:
			return &"walk"
		State.RUN:
			return &"run"
		State.FALL:
			return &"fall"
		_:
			return &"idle"


## The hysteresis. Which threshold applies depends on what the actor is already
## doing: it takes more speed to start moving than it takes to keep moving.
##
## A config with the two the wrong way round would flicker worse than a single
## threshold, so the exit speed is capped at the enter speed rather than
## trusted.
func _is_moving(ground_speed: float) -> bool:
	var already_moving := _state == State.WALK or _state == State.RUN
	var threshold := (
		minf(_config.move_exit_speed, _config.move_enter_speed)
		if already_moving
		else _config.move_enter_speed
	)
	return ground_speed >= threshold
