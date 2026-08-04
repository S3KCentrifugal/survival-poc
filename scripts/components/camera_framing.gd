class_name CameraFraming
extends RefCounted
## The maths behind a fixed-angle follow camera.
##
## Pure functions over a [CameraConfig] -- no nodes, no frame timing -- so
## framing can be verified exactly rather than judged by eye.

## Camera position relative to the point it is looking at.
##
## Yaw sweeps around Y, pitch lifts the camera above the horizon. At yaw 0 the
## camera sits on +Z looking back toward -Z.
static func offset_from_focus(config: CameraConfig) -> Vector3:
	var pitch := config.pitch_radians()
	var yaw := config.yaw_radians()
	var ground_distance := config.distance * cos(pitch)
	return Vector3(
		sin(yaw) * ground_distance,
		config.distance * sin(pitch),
		cos(yaw) * ground_distance
	)


## The point the camera aims at: the focus, raised by the configured height.
static func aim_point(focus: Vector3, config: CameraConfig) -> Vector3:
	return focus + Vector3.UP * config.focus_height


## Where the camera sits when framing [param focus].
static func position_for(focus: Vector3, config: CameraConfig) -> Vector3:
	return aim_point(focus, config) + offset_from_focus(config)


## Full camera transform framing [param focus].
##
## Built with [method Transform3D.looking_at] rather than a hand-assembled
## basis: composing one from axis vectors is easy to get transposed, and the
## symptom (a rolled horizon) is subtle.
static func transform_for(focus: Vector3, config: CameraConfig) -> Transform3D:
	var transform := Transform3D.IDENTITY
	transform.origin = position_for(focus, config)
	return transform.looking_at(aim_point(focus, config), Vector3.UP)


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
