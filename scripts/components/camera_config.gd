class_name CameraConfig
extends Resource
## Framing, follow and look behaviour for a third-person camera.
##
## Edit the .tres under resources/camera/ rather than these defaults.

const MIN_PITCH_DEGREES: float = 5.0
const MAX_PITCH_DEGREES: float = 89.0


## How the player turns the camera.
enum MouseLook {
	## Cursor is captured and every mouse movement turns the camera. What most
	## third-person games do. Escape releases it; clicking takes it back.
	CAPTURED,
	## Only turns while the right button is held, and the cursor stays visible.
	## Safer on a desktop, and the fallback if capture misbehaves.
	HOLD_RIGHT,
}

## Where the camera starts, in degrees around Y. Runtime yaw comes from the
## mouse; this is only the opening shot, and is overridden on spawn by placing
## the camera behind the player.
@export_range(0.0, 360.0, 1.0) var yaw_degrees: float = 0.0

## Downward tilt the camera starts at. 0 is horizontal, 90 straight down.
##
## Around 20 degrees is the usual third-person resting angle: enough to see the
## ground ahead of the character without looking down on the top of their head.
@export_range(5.0, 89.0, 0.5) var pitch_degrees: float = 20.0:
	set(value):
		pitch_degrees = clampf(value, MIN_PITCH_DEGREES, MAX_PITCH_DEGREES)

## Distance from the focus point, in metres. Also where zoom starts.
@export_range(1.0, 200.0, 0.5) var distance: float = 5.0:
	set(value):
		distance = maxf(0.1, value)

## Raises the focus point off the ground so the camera frames a character's
## chest rather than their feet. Roughly head height for a 1.8 m character.
@export_range(0.0, 10.0, 0.1) var focus_height: float = 1.5

## How quickly the focus catches up to the target, per second.
##
## Zero or less means no smoothing at all -- the camera is rigidly locked.
@export_range(0.0, 40.0, 0.5) var follow_speed: float = 8.0

@export_group("Look")
@export var mouse_look: MouseLook = MouseLook.CAPTURED

## Degrees of rotation per pixel of mouse movement.
@export_range(0.01, 2.0, 0.01) var look_sensitivity: float = 0.22

## Pushing the mouse forward looks up rather than down.
@export var invert_pitch: bool = false

## How far the camera may be tilted by hand. Kept clear of straight down, where
## [method Transform3D.looking_at] is degenerate and the view spins, and clear
## of the horizon, where a third-person camera ends up staring at the ground.
@export_range(0.0, 89.0, 0.5) var min_pitch_degrees: float = 3.0
@export_range(0.0, 89.0, 0.5) var max_pitch_degrees: float = 75.0

@export_group("Zoom")
@export_range(0.5, 50.0, 0.5) var min_distance: float = 1.5
@export_range(0.5, 200.0, 0.5) var max_distance: float = 14.0

## Metres added or removed per notch of the wheel.
@export_range(0.1, 10.0, 0.1) var zoom_step: float = 0.8

## How quickly the camera slides to a new zoom distance, per second. Zero snaps.
@export_range(0.0, 60.0, 0.5) var zoom_speed: float = 14.0

@export_group("Obstruction")
## Pull the camera in when something solid is between it and the player.
##
## Not optional in practice: the player starts inside a building, and a camera
## five metres behind them is five metres inside a wall.
@export var avoid_obstructions: bool = true

## How far off a surface the camera stops, so the near plane does not clip
## through it.
@export_range(0.0, 2.0, 0.05) var obstruction_margin: float = 0.25

## Physics layers the camera will not see through.
@export_flags_3d_physics var obstruction_mask: int = 1

@export_group("Projection")
@export var orthographic: bool = false

## Vertical field of view, used when [member orthographic] is false.
@export_range(20.0, 90.0, 1.0) var fov: float = 60.0

## Vertical span in metres, used when [member orthographic] is true.
@export_range(1.0, 100.0, 0.5) var orthographic_size: float = 20.0


func yaw_radians() -> float:
	return deg_to_rad(yaw_degrees)


func pitch_radians() -> float:
	return deg_to_rad(pitch_degrees)


## Tilt limits in radians, lowest first, with an inverted pair straightened out
## rather than trusted.
func pitch_limits() -> Vector2:
	var low := minf(min_pitch_degrees, max_pitch_degrees)
	var high := maxf(min_pitch_degrees, max_pitch_degrees)
	return Vector2(deg_to_rad(low), deg_to_rad(high))


## Zoom limits in metres, nearest first.
func distance_limits() -> Vector2:
	var near := minf(min_distance, max_distance)
	var far := maxf(min_distance, max_distance)
	return Vector2(near, far)
