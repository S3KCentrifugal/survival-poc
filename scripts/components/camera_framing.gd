class_name CameraFraming
extends RefCounted
## The maths behind a follow camera.
##
## Pure functions over explicit angles -- no nodes, no config, no frame timing
## -- so framing can be verified exactly rather than judged by eye. Where the
## angles *come from* is [CameraOrbit]'s problem.

## Camera position relative to the point it is looking at.
##
## Yaw sweeps around Y, pitch lifts the camera above the horizon. At yaw 0 the
## camera sits on +Z looking back toward -Z -- which is directly behind a node
## at the same yaw, because a node faces its local -Z.
static func offset_from_focus(yaw: float, pitch: float, distance: float) -> Vector3:
	var ground_distance := distance * cos(pitch)
	return Vector3(sin(yaw) * ground_distance, distance * sin(pitch), cos(yaw) * ground_distance)


## The point the camera aims at: the focus, raised by [param focus_height].
static func aim_point(focus: Vector3, focus_height: float) -> Vector3:
	return focus + Vector3.UP * focus_height


## Where the camera sits when framing [param focus].
static func position_for(
	focus: Vector3, focus_height: float, yaw: float, pitch: float, distance: float
) -> Vector3:
	return aim_point(focus, focus_height) + offset_from_focus(yaw, pitch, distance)


## Full camera transform framing [param focus].
##
## Built with [method Transform3D.looking_at] rather than a hand-assembled
## basis: composing one from axis vectors is easy to get transposed, and the
## symptom (a rolled horizon) is subtle.
static func transform_for(
	focus: Vector3, focus_height: float, yaw: float, pitch: float, distance: float
) -> Transform3D:
	var target := aim_point(focus, focus_height)
	var transform := Transform3D.IDENTITY
	transform.origin = target + offset_from_focus(yaw, pitch, distance)
	if transform.origin.is_equal_approx(target):
		return transform
	return transform.looking_at(target, Vector3.UP)


## Interpolation weight for one frame of exponential smoothing.
##
## Frame-rate independent: `1 - exp(-speed * delta)` composes exactly, so two
## half-steps land in the same place as one whole step. The common
## `speed * delta` form does not, and makes the camera behave differently at 30
## and 144 fps.
##
## A speed of zero or less means no smoothing -- the weight is 1 and the camera
## is rigidly locked to its target.
static func smoothing_weight(follow_speed: float, delta: float) -> float:
	if follow_speed <= 0.0:
		return 1.0
	if delta <= 0.0:
		return 0.0
	return 1.0 - exp(-follow_speed * delta)


## How far the camera may sit from its aim point given something solid in the
## way at [param hit_distance], keeping [param margin] clear of the surface.
##
## Never returns a negative distance: a camera pulled through its own focus
## ends up looking at the back of the character's head from inside it.
static func unobstructed_distance(
	wanted: float, hit_distance: float, margin: float
) -> float:
	return clampf(minf(wanted, hit_distance - margin), 0.0, wanted)
