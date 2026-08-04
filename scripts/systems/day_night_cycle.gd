class_name DayNightCycle
extends RefCounted
## Where the sun is, and what colour it is, at a given time of day.
##
## All of the trigonometry and none of the scene tree, so the awkward parts --
## the wrap at midnight, the sun's direction at dawn, the basis that aims it --
## can be checked exactly. [DayNightComponent] applies the answers to a light.

## Fraction of the day elapsed: 0 is midnight, 0.25 sunrise, 0.5 noon, 0.75
## sunset. Always in [0, 1).
var time_of_day: float = 0.0

var _config: DayNightConfig


func _init(config: DayNightConfig) -> void:
	_config = config
	time_of_day = fposmod(config.start_time, 1.0)


## Advances the clock, wrapping through midnight.
##
## A zero-length day would divide by zero and leave the time NaN, which is a
## much harder bug to read than a frozen sun.
func advance(delta: float) -> void:
	if _config.day_length_seconds <= 0.0:
		return
	time_of_day = fposmod(time_of_day + delta / _config.day_length_seconds, 1.0)


## Where the sun sits, as a unit vector from the world's centre.
##
## The arc is a circle from due east through the tilted overhead axis, so the
## sun rises in the east, leans past the zenith rather than through it, and sets
## in the west.
func sun_position() -> Vector3:
	var angle := TAU * (time_of_day - 0.25)
	var tilt := deg_to_rad(_config.sun_tilt_degrees)
	var overhead := Vector3(0.0, cos(tilt), sin(tilt))
	return Vector3.RIGHT * cos(angle) + overhead * sin(angle)


## The direction sunlight travels, which is what a [DirectionalLight3D] points
## along.
func sun_direction() -> Vector3:
	return -sun_position()


## Height of the sun, 0 at the horizon and 1 straight up.
func sun_elevation() -> float:
	return sun_position().y


func is_daytime() -> bool:
	return sun_elevation() > 0.0


## Full strength high in the sky, fading to moonlight below the horizon.
func light_energy() -> float:
	return lerpf(_config.night_energy, _config.day_energy, _daylight_amount())


## Cold at night, warm at the horizon, neutral overhead. Dawn and dusk share a
## colour because they are the same geometry.
func light_color() -> Color:
	if not is_daytime():
		return _config.night_color
	return _config.horizon_color.lerp(_config.day_color, _daylight_amount())


## Time as a 24-hour clock string, for the debug overlay.
func time_string() -> String:
	var minutes := int(round(time_of_day * 24.0 * 60.0)) % 1440
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func hours() -> float:
	return time_of_day * 24.0


## A basis that aims a light along [param direction].
##
## Built with [method Basis.looking_at] rather than written out: a hand-authored
## basis from computed axes is transposed as often as not, and a rolled sun is a
## diagonal horizon that nobody notices until it is in a screenshot.
static func sun_basis(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	if forward.is_zero_approx():
		return Basis.IDENTITY
	# Straight up or straight down leaves looking_at with no way to decide roll.
	var up := Vector3.BACK if absf(forward.dot(Vector3.UP)) > 0.999 else Vector3.UP
	return Basis.looking_at(forward, up)


## How much of full daylight applies, 0 below the horizon rising to 1 once the
## sun clears the twilight band.
func _daylight_amount() -> float:
	return clampf(sun_elevation() / maxf(_config.twilight_band, 0.01), 0.0, 1.0)
