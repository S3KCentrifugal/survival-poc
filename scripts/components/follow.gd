class_name Follow
extends RefCounted
## Deciding whether to set off, keep going, or stop.
##
## Distances and a clock, nothing else -- no nodes, no navigation, no physics.
## Where the *route* comes from is [FollowComponent]'s problem; this answers
## whether it should be walking at all and how hard.

enum State {
	## Noticed you, has not set off yet.
	WAITING,
	## On its way.
	FOLLOWING,
	## Close enough.
	ARRIVED,
}

var _config: FollowConfig
var _state: State = State.ARRIVED

## Seconds left of the start delay.
var _delay: float = 0.0


func _init(config: FollowConfig) -> void:
	_config = config


## One tick. [param distance] is how far away the thing being followed is.
func tick(distance: float, delta: float) -> State:
	var limits := _config.distances()
	match _state:
		State.ARRIVED:
			# Only a real gap starts the clock, not the jitter of standing still.
			if distance > limits.y:
				_state = State.WAITING
				_delay = _config.start_delay
		State.WAITING:
			if distance <= limits.x:
				_state = State.ARRIVED
			else:
				_delay -= delta
				if _delay <= 0.0:
					_state = State.FOLLOWING
		State.FOLLOWING:
			if distance <= limits.x:
				_state = State.ARRIVED
	return _state


## Whether it should be moving right now.
func is_moving() -> bool:
	return _state == State.FOLLOWING


func state() -> State:
	return _state


## Seconds still to wait before setting off. Zero unless waiting.
func delay_left() -> float:
	return maxf(_delay, 0.0) if _state == State.WAITING else 0.0


## Whether it should sprint to close the gap, spending stamina like anyone else.
func should_sprint(distance: float) -> bool:
	return is_moving() and distance >= _config.sprint_distance


## Drops it back to standing, for a teleport or a respawn.
func settle() -> void:
	_state = State.ARRIVED
	_delay = 0.0
