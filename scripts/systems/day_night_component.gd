class_name DayNightComponent
extends Node
## Drives a [DirectionalLight3D] from a [DayNightCycle].
##
## The sun is the only thing it touches. [SkyComponent] listens to
## [signal time_changed] and repaints the sky to match; the ambient light then
## comes from that sky, so one rotation still moves the whole atmosphere.
##
## This used to be true for a different reason: the scene ran a stock
## [ProceduralSkyMaterial], which takes its gradient from the brightest
## directional light on its own. That sky could not do a sunset or a star, so
## it was replaced -- and the coupling that came free had to be wired up by
## hand. See devblog 030.

## Emitted every frame the clock advances. Carries the fraction of the day
## elapsed, not seconds.
signal time_changed(time_of_day: float)

## Emitted as the sun crosses the horizon. The hooks a survival loop wants:
## what comes out at night, what stops spawning at dawn.
signal day_began
signal night_began

@export var config: DayNightConfig

## The sun. Assign in the scene; without one the clock still runs and the world
## simply stays as it was lit.
@export var sun: DirectionalLight3D

var _cycle: DayNightCycle
var _was_daytime: bool = true


func _ready() -> void:
	if config == null:
		push_warning("DayNightComponent has no config; falling back to defaults")
	if sun == null:
		push_warning("DayNightComponent has no sun; the light will not move")
	_ensure_cycle()
	_was_daytime = _cycle.is_daytime()
	apply()


## Lighting is presentation, so this runs on the idle clock: the sun should
## sweep as smoothly as the framerate allows rather than in 60 Hz steps.
func _process(delta: float) -> void:
	step(delta)


## Advances the clock by [param delta] seconds and relights the world.
##
## Public so tests and tools can jump the day around without waiting for it.
func step(delta: float) -> void:
	_ensure_cycle()
	_cycle.advance(delta)
	apply()
	time_changed.emit(_cycle.time_of_day)

	var daytime := _cycle.is_daytime()
	if daytime == _was_daytime:
		return
	_was_daytime = daytime
	if daytime:
		day_began.emit()
	else:
		night_began.emit()


## Points the sun where the clock says it should be, and tints it to match.
func apply() -> void:
	if sun == null:
		return
	var basis := DayNightCycle.sun_basis(_cycle.sun_direction())
	sun.transform = Transform3D(basis, sun.transform.origin)
	sun.light_energy = _cycle.light_energy()
	sun.light_color = _cycle.light_color()


## Jumps straight to a time of day, for a debug key or a scripted scene.
func set_time_of_day(time: float) -> void:
	_ensure_cycle()
	_cycle.time_of_day = fposmod(time, 1.0)
	_was_daytime = _cycle.is_daytime()
	apply()
	time_changed.emit(_cycle.time_of_day)


func time_of_day() -> float:
	_ensure_cycle()
	return _cycle.time_of_day


## The clock as "HH:MM", for the debug overlay.
func time_string() -> String:
	_ensure_cycle()
	return _cycle.time_string()


func is_daytime() -> bool:
	_ensure_cycle()
	return _cycle.is_daytime()


func _ensure_cycle() -> void:
	if _cycle != null:
		return
	if config == null:
		config = DayNightConfig.new()
	_cycle = DayNightCycle.new(config)
