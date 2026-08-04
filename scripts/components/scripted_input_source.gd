class_name ScriptedInputSource
extends InputSource
## Intent set directly in code rather than read from a device.
##
## This is what makes the abstraction worth having: an enemy walks by having
## its AI write to one of these, and a movement test drives a character with no
## keyboard and no frames. The same movement code runs in both cases.

var state: InputState = InputState.new()


func poll() -> InputState:
	return state


## Walks in a world-space ground direction. Normalised, so callers can pass an
## unnormalised vector toward a destination.
func move_towards_direction(direction: Vector2) -> void:
	state.move = direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO


## Walks from [param from] toward [param to] on the ground plane.
func move_between(from: Vector3, to: Vector3) -> void:
	move_towards_direction(Vector2(to.x - from.x, to.z - from.z))


func stop() -> void:
	state.move = Vector2.ZERO


func sprint(enabled: bool) -> void:
	state.sprint = enabled


func aim_at(point: Vector3) -> void:
	state.aim_point = point
	state.has_aim = true


func clear_aim() -> void:
	state.has_aim = false
