class_name SkyComponent
extends Node
## Pushes the sky's colours onto the shader as the sun moves.
##
## Sits between [DayNightComponent], which owns the clock and the sun, and
## [WorldEnvironment], which owns the sky material. Both are explicit exports:
## this never goes looking for either, so the same component works in a test
## scene with a bare environment and no clock at all.
##
## It writes uniforms and nothing else. What colour the sky should be at a given
## sun elevation is [SkyGradient]'s decision, and that has no shader in it.

@export var config: SkyConfig

## Where the clock and the sun's direction come from. Optional: without one the
## sky is drawn once at whatever [member fallback_elevation] says and left there,
## which is exactly what a lighting test wants.
@export var day_night: DayNightComponent

## The environment holding the sky material to write to.
@export var environment: WorldEnvironment

## Used when there is no clock. Noon, so a scene with no cycle is lit.
@export_range(-1.0, 1.0, 0.01) var fallback_elevation: float = 1.0

var _gradient: SkyGradient
var _material: ShaderMaterial


func _ready() -> void:
	if config == null:
		push_warning("SkyComponent has no config; falling back to defaults")
	_gradient = SkyGradient.new(config)
	_material = _find_material()
	if _material == null:
		push_warning("SkyComponent found no sky ShaderMaterial; the sky will not change")
	if day_night != null:
		day_night.time_changed.connect(_on_time_changed)
	apply()


## Reads the sun's position and writes every uniform that depends on it.
##
## Public so a test, or a tool that scrubs through a day, can force the sky to
## catch up without waiting for a frame.
func apply() -> void:
	if _material == null:
		return
	var to_sun := sun_position()
	var elevation := to_sun.y

	_material.set_shader_parameter(&"sun_direction", to_sun)
	_material.set_shader_parameter(&"zenith_color", _gradient.zenith_color(elevation))
	_material.set_shader_parameter(&"horizon_color", _gradient.horizon_color(elevation))
	_material.set_shader_parameter(&"sun_color", _gradient.sun_color(elevation))
	_material.set_shader_parameter(&"ground_color", _gradient.ground_color(elevation))
	_material.set_shader_parameter(&"halo_strength", _gradient.halo_strength(elevation))
	_material.set_shader_parameter(&"star_fade", _gradient.star_fade(elevation))

	# Constants as far as the day is concerned, but they still come from the
	# config rather than the shader's own defaults -- two places to change a
	# number is one place too many.
	var settings := config if config != null else SkyConfig.new()
	_material.set_shader_parameter(&"halo_color", settings.halo_color)
	_material.set_shader_parameter(&"sun_angular_radius", settings.sun_angular_radius)
	_material.set_shader_parameter(&"sun_energy", settings.sun_energy)
	_material.set_shader_parameter(&"star_brightness", settings.star_brightness)
	_material.set_shader_parameter(&"star_sparsity", settings.star_sparsity)
	_material.set_shader_parameter(&"star_density", settings.star_density)


## Unit vector pointing at the sun.
##
## Taken from the light's own basis rather than recomputed from the clock: a
## sun drawn somewhere the shadows do not come from is the kind of wrongness
## that is obvious in a screenshot and invisible in code.
func sun_position() -> Vector3:
	if day_night != null and day_night.sun != null:
		# A DirectionalLight3D shines along its local -Z, so the direction back
		# toward the sun is +Z.
		return day_night.sun.global_transform.basis.z.normalized()
	return Vector3(0.0, fallback_elevation, sqrt(maxf(1.0 - fallback_elevation * fallback_elevation, 0.0)))


## The material being written to, so a test can read the uniforms back.
func material() -> ShaderMaterial:
	return _material


func _on_time_changed(_time_of_day: float) -> void:
	apply()


func _find_material() -> ShaderMaterial:
	if environment == null or environment.environment == null:
		return null
	var sky := environment.environment.sky
	return null if sky == null else sky.sky_material as ShaderMaterial
