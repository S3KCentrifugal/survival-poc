class_name CameraOrbit
extends RefCounted
## Where the camera is pointing from, and the rules about where it may point.
##
## The state a fixed camera did not need: yaw and pitch the player turns by
## hand, and a distance the wheel changes. Node-free, so the awkward parts --
## the wrap at north, the tilt clamp, a zoom that must not walk past its stops
## -- are assertions rather than things you notice while playing.
##
## Zoom keeps a *wanted* distance separate from the current one so the camera
## can slide toward it. Snapping the whole way on each notch reads as a jolt.

var yaw: float
var pitch: float

## What the camera is using right now.
var distance: float

## What the wheel has asked for. [method advance] walks [member distance]
## toward it.
var wanted_distance: float

var _config: CameraConfig


func _init(config: CameraConfig) -> void:
	_config = config
	yaw = config.yaw_radians()
	pitch = _clamp_pitch(config.pitch_radians())
	distance = _clamp_distance(config.distance)
	wanted_distance = distance


## Turns the camera by a mouse movement in pixels.
##
## Right is a positive yaw and down is a positive pitch, so pushing the mouse
## right swings the camera right and pulling it back tips the view down -- which
## is the way round every third-person game does it.
func look(movement: Vector2) -> void:
	if movement.is_zero_approx():
		return
	var radians_per_pixel := deg_to_rad(_config.look_sensitivity)
	yaw = wrapf(yaw - movement.x * radians_per_pixel, -PI, PI)
	var vertical := movement.y * radians_per_pixel
	pitch = _clamp_pitch(pitch + (-vertical if _config.invert_pitch else vertical))


## Asks for [param steps] notches of zoom. Positive pulls the camera out.
func zoom(steps: float) -> void:
	wanted_distance = _clamp_distance(wanted_distance + steps * _config.zoom_step)


## Puts the camera directly behind something facing [param target_yaw].
##
## A node faces its local -Z and the camera sits at +Z of its own yaw, so
## matching the two puts the camera at the target's back.
func place_behind(target_yaw: float) -> void:
	yaw = wrapf(target_yaw, -PI, PI)


## Slides the current distance toward what the wheel asked for.
func advance(delta: float) -> void:
	var weight := CameraFraming.smoothing_weight(_config.zoom_speed, delta)
	distance = lerpf(distance, wanted_distance, weight)


## Jumps zoom to where it is heading, for a spawn or a teleport.
func settle() -> void:
	distance = wanted_distance


func _clamp_pitch(value: float) -> float:
	var limits := _config.pitch_limits()
	return clampf(value, limits.x, limits.y)


func _clamp_distance(value: float) -> float:
	var limits := _config.distance_limits()
	return clampf(value, limits.x, limits.y)
