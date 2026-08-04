class_name MovementSolver
extends RefCounted
## The maths of walking: velocity, gravity and turning.
##
## Pure static functions -- no nodes, no physics server -- so the parts that are
## easy to get subtly wrong can be checked exactly instead of by feel.

## Advances horizontal velocity toward what the actor wants.
##
## Acceleration is linear (a fixed m/s² applied over delta), which is exactly
## frame-rate independent: the same real time produces the same speed change
## regardless of how it is sliced.
##
## [param desired] is a direction of length at most 1; its magnitude scales the
## target speed, so a half-pressed stick walks at half pace.
static func horizontal_velocity(
	current: Vector2,
	desired: Vector2,
	walk_speed: float,
	acceleration: float,
	deceleration: float,
	delta: float
) -> Vector2:
	var target := desired * walk_speed
	# Stopping and starting use different rates, which is most of what makes
	# movement feel deliberate rather than slippery.
	var rate := acceleration if not desired.is_zero_approx() else deceleration
	return current.move_toward(target, rate * delta)


## Advances vertical velocity.
##
## Standing on the ground zeroes it rather than letting it accumulate: an
## unbounded downward velocity while grounded makes the actor punch through
## thin geometry the moment it steps off an edge.
static func apply_gravity(
	vertical_velocity: float, gravity: float, delta: float, on_floor: bool
) -> float:
	if on_floor:
		return 0.0
	return vertical_velocity - gravity * delta


## Rotates [param current_yaw] toward [param target_yaw] by at most
## [param max_step] radians.
##
## Uses [method @GlobalScope.angle_difference] so the turn always takes the
## short way round: naive subtraction sends an actor the long way whenever the
## angles straddle ±π, which looks like a spin-out.
static func turn_towards(current_yaw: float, target_yaw: float, max_step: float) -> float:
	var difference := angle_difference(current_yaw, target_yaw)
	return current_yaw + clampf(difference, -max_step, max_step)


## Yaw that points an actor's forward axis along [param direction] on the
## ground plane, where direction is (x, z).
##
## Godot's convention is that a node faces its local -Z, so a yaw of 0 looks
## toward -Z.
static func yaw_towards(direction: Vector2) -> float:
	return atan2(-direction.x, -direction.y)


## Ground-plane direction from one point to another, or zero if they are
## effectively stacked.
static func ground_direction(from: Vector3, to: Vector3) -> Vector2:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	return Vector2.ZERO if flat.is_zero_approx() else flat.normalized()
