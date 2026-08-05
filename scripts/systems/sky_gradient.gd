class_name SkyGradient
extends RefCounted
## What colour the sky is, given how high the sun is.
##
## Pure: it takes an elevation and returns colours. No shader, no node, no
## clock -- which is what lets "is the sunset actually warmer than noon?" be a
## test with numbers in it rather than a screenshot somebody has to squint at.
##
## Elevation is the sun's height as a fraction of straight up: -1 is midnight
## under your feet, 0 is exactly on the horizon, 1 is directly overhead.

var _config: SkyConfig


func _init(config: SkyConfig) -> void:
	_config = config if config != null else SkyConfig.new()


## How much of the day palette applies: 0 at and below the horizon, rising to 1
## once the sun clears the twilight band.
func daylight_amount(elevation: float) -> float:
	return clampf(elevation / maxf(_config.twilight_band, 0.01), 0.0, 1.0)


## How much of the dusk palette applies: 1 with the sun exactly on the horizon,
## falling away in both directions.
##
## Symmetric on purpose. Sunrise and sunset are the same geometry, and a game
## that tints them differently is inventing a distinction the sky does not have.
func dusk_amount(elevation: float) -> float:
	return clampf(1.0 - absf(elevation) / maxf(_config.dusk_band, 0.01), 0.0, 1.0)


## Overhead colour.
func zenith_color(elevation: float) -> Color:
	var base := _config.night_zenith.lerp(_config.day_zenith, daylight_amount(elevation))
	return base.lerp(_config.dusk_zenith, dusk_amount(elevation))


## Colour where the sky meets the ground, which is where a sunset happens.
func horizon_color(elevation: float) -> Color:
	var base := _config.night_horizon.lerp(_config.day_horizon, daylight_amount(elevation))
	return base.lerp(_config.dusk_horizon, dusk_amount(elevation))


## What is drawn below the horizon: the sky's own colour, darkened.
##
## Tied to the horizon so it is never a shade the sky is not already wearing --
## at sunset the ground haze is dark orange, at night it is nearly black, and
## neither needs its own palette.
func ground_color(elevation: float) -> Color:
	return horizon_color(elevation).darkened(clampf(_config.ground_darkening, 0.0, 1.0))


## The disc's own colour: warm at the horizon, white overhead.
func sun_color(elevation: float) -> Color:
	return _config.sun_low_color.lerp(_config.sun_high_color, daylight_amount(elevation))


## How strong the glow around the sun is.
##
## Peaks at the horizon rather than at noon: the halo is light scattered along a
## low path through thick air, so a midday sun in a clear sky has almost none.
## It is also cut off once the sun is properly down, or the glow outlives the
## thing casting it.
func halo_strength(elevation: float) -> float:
	return _config.halo_strength * dusk_amount(elevation) * _above_horizon(elevation)


## How visible the stars are: none in daylight, full once the sun is down.
##
## Tied to the *dusk* band rather than the twilight band so the first stars
## appear while the sky is still coloured, which is when they actually do.
func star_fade(elevation: float) -> float:
	return clampf(-elevation / maxf(_config.dusk_band, 0.01), 0.0, 1.0)


## Fades out over the last of the dusk band below the horizon, so the halo goes
## with the sun instead of hanging in the dark.
func _above_horizon(elevation: float) -> float:
	if elevation >= 0.0:
		return 1.0
	return clampf(1.0 + elevation / maxf(_config.dusk_band, 0.01), 0.0, 1.0)
