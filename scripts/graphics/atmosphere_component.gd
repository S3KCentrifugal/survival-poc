class_name AtmosphereComponent
extends Node
## Pushes the atmosphere onto the [Environment] as the sun moves.
##
## The exact shape of [SkyComponent], deliberately: it sits between
## [DayNightComponent], which owns the clock, and [WorldEnvironment], which owns
## the thing being written to, and it never goes looking for either. What the
## air should be at a given sun elevation is [Atmosphere]'s decision and has no
## renderer in it.
##
## Everything it writes was previously either a default nobody had chosen or,
## in the case of the ambient term at night, absent — which is why the project
## measured 100% of its night frame below the readable floor.

## The palette the fog and ambient are derived from. The *same resource* the sky
## shader is drawn with, so the air is always made of the sky the player can
## see. A second copy here is how fog ends up a colour the sky is not wearing.
@export var sky_config: SkyConfig

## Where the sun's elevation comes from. Optional: without one the atmosphere is
## applied once at [member fallback_elevation] and left there, which is what a
## lighting test wants.
@export var day_night: DayNightComponent

@export var environment: WorldEnvironment

## Used when there is no clock. Noon, so a scene with no cycle is lit.
@export_range(-1.0, 1.0, 0.01) var fallback_elevation: float = 1.0

var _atmosphere: Atmosphere


func _ready() -> void:
	if sky_config == null:
		push_warning("AtmosphereComponent has no sky config; falling back to defaults")
	if environment == null:
		push_warning("AtmosphereComponent has no environment; the air will not change")
	_atmosphere = Atmosphere.new(sky_config)
	_apply_constants()
	if day_night != null:
		day_night.time_changed.connect(_on_time_changed)
	apply()


## Reads the sun's elevation and writes everything that depends on it.
##
## Public so a test, or a tool scrubbing through a day, can force the air to
## catch up without waiting for a frame.
func apply() -> void:
	var settings := _environment()
	if settings == null:
		return
	var elevation := sun_elevation()

	settings.ambient_light_energy = _atmosphere.ambient_energy(elevation)
	settings.ambient_light_color = _atmosphere.ambient_color(elevation)
	settings.ambient_light_sky_contribution = _atmosphere.sky_contribution(elevation)

	settings.fog_light_color = _atmosphere.fog_color(elevation)
	settings.fog_density = _atmosphere.fog_density(elevation)

	settings.tonemap_exposure = _atmosphere.exposure(elevation)


## How high the sun is, as a fraction of straight up.
##
## Taken from the light's own basis rather than recomputed from the clock, for
## the same reason [SkyComponent] does it: air lit from a direction the shadows
## do not come from is the kind of wrongness that is obvious in a screenshot and
## invisible in code.
func sun_elevation() -> float:
	if day_night != null and day_night.sun != null:
		return day_night.sun.global_transform.basis.z.normalized().y
	return fallback_elevation


## The environment being written to, so a test can read the values back.
func environment_settings() -> Environment:
	return _environment()


## The settings that do not depend on the hour.
##
## Written here rather than left in the `.tscn` so that `ART.md` rule 8 holds:
## a tonemapper chosen in a scene file is a number in a place nobody will think
## to look, and this project has already paid for that lesson at the interface
## layer.
func _apply_constants() -> void:
	var settings := _environment()
	if settings == null:
		return
	settings.tonemap_mode = ArtTokens.TONEMAP
	settings.tonemap_white = ArtTokens.TONEMAP_WHITE

	# Sky ambient with a floor, rather than sky ambient alone. The blend between
	# the two is what [method Atmosphere.sky_contribution] moves.
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_SKY

	settings.fog_enabled = true
	settings.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	settings.fog_aerial_perspective = ArtTokens.FOG_AERIAL_PERSPECTIVE
	settings.fog_sky_affect = ArtTokens.FOG_SKY_AFFECT
	settings.fog_sun_scatter = ArtTokens.FOG_SUN_SCATTER


func _on_time_changed(_time_of_day: float) -> void:
	apply()


func _environment() -> Environment:
	return null if environment == null else environment.environment
