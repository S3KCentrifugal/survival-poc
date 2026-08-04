class_name CameraConfig
extends Resource
## Framing and follow behaviour for a fixed-angle camera.
##
## Edit the .tres under resources/camera/ rather than these defaults.

## Compass direction the camera looks from, in degrees around Y.
##
## Fixed, not gameplay state -- the camera does not turn with its target. That
## stability is what makes an isometric view readable.
@export_range(0.0, 360.0, 1.0) var yaw_degrees: float = 45.0

## Downward tilt. 0 is horizontal, 90 would be straight down.
##
## Clamped below vertical because [method Transform3D.looking_at] is degenerate
## when forward is parallel to up: the basis collapses and the view spins.
@export_range(5.0, 89.0, 0.5) var pitch_degrees: float = 50.0:
	set(value):
		pitch_degrees = clampf(value, MIN_PITCH_DEGREES, MAX_PITCH_DEGREES)

## Distance from the focus point, in metres.
@export_range(1.0, 200.0, 0.5) var distance: float = 18.0:
	set(value):
		distance = maxf(0.1, value)

## Raises the focus point off the ground so the camera frames a character's
## chest rather than their feet.
@export_range(0.0, 10.0, 0.1) var focus_height: float = 1.0

## How quickly the focus catches up to the target, per second.
##
## Zero or less means no smoothing at all -- the camera is rigidly locked.
@export_range(0.0, 40.0, 0.5) var follow_speed: float = 8.0

@export var orthographic: bool = false

## Vertical field of view, used when [member orthographic] is false.
@export_range(20.0, 90.0, 1.0) var fov: float = 45.0

## Vertical span in metres, used when [member orthographic] is true.
@export_range(1.0, 100.0, 0.5) var orthographic_size: float = 20.0

const MIN_PITCH_DEGREES: float = 5.0
const MAX_PITCH_DEGREES: float = 89.0


func yaw_radians() -> float:
	return deg_to_rad(yaw_degrees)


func pitch_radians() -> float:
	return deg_to_rad(pitch_degrees)
