class_name DebugOverlay
extends CanvasLayer
## The project's only UI: what the game thinks is happening, in the corner.
##
## Watches things it is handed and reports on them. Every reference is optional
## and every missing one prints as [code]--[/code], so this can be dropped into
## a scene with half a world in it and still be useful.
##
## The formatting lives in [DebugReadout]; this only gathers values and decides
## when to redraw.

## Toggles the panel.
##
## Read from the key event queue rather than from the [Input] singleton, which
## the project reserves for [PlayerInputSource]. That rule exists so gameplay
## intent always arrives through an [InputSource] and can come from an AI or a
## network peer instead -- a debug panel is neither, and has no business in an
## actor's intent.
@export var toggle_key: Key = KEY_F3

## Seconds between refreshes. Rebuilding this string sixty times a second is
## pointless garbage for something the eye reads a few times a second.
@export_range(0.0, 1.0, 0.01) var refresh_interval: float = 0.1

@export var label: Label

@export_group("Watching")
@export var body: CharacterBody3D
@export var movement: MovementComponent
@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var animation: AnimationComponent
@export var day_night: DayNightComponent

var _since_refresh: float = 0.0


func _ready() -> void:
	if label == null:
		push_warning("DebugOverlay has no label; it will not show anything")
	refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_since_refresh += delta
	if _since_refresh < refresh_interval:
		return
	_since_refresh = 0.0
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != toggle_key:
		return
	visible = not visible
	if visible:
		refresh()
	get_viewport().set_input_as_handled()


## Rebuilds the panel now.
func refresh() -> void:
	if label == null:
		return
	label.text = build_text()


## The whole panel as text.
##
## Public and free of side effects so a test can read what the overlay would
## say without a viewport, a font, or a frame.
func build_text() -> String:
	var lines: PackedStringArray = [
		DebugReadout.frames_per_second(Engine.get_frames_per_second()),
		_clock_line(),
		_position_line(),
		_speed_line(),
		_state_line(),
		_vital_line("health", health),
		_stamina_line(),
	]
	return "\n".join(lines)


func _clock_line() -> String:
	if day_night == null:
		return DebugReadout.absent("time")
	return DebugReadout.clock(day_night.time_string(), day_night.is_daytime())


func _position_line() -> String:
	if body == null:
		return DebugReadout.absent("pos")
	return DebugReadout.position(body.global_position)


func _speed_line() -> String:
	if body == null:
		return DebugReadout.absent("speed")
	return DebugReadout.speed(body.velocity, movement != null and movement.is_sprinting())


func _state_line() -> String:
	if animation == null:
		return DebugReadout.absent("state")
	return DebugReadout.state("state", String(animation.state_name()))


func _vital_line(name: String, component: HealthComponent) -> String:
	if component == null:
		return DebugReadout.absent(name)
	return DebugReadout.vital(name, component.current(), component.maximum())


## Stamina reads like a vital but is a different component, and says so when the
## actor is locked out.
func _stamina_line() -> String:
	if stamina == null:
		return DebugReadout.absent("stamina")
	var line := DebugReadout.vital("stamina", stamina.current(), stamina.maximum())
	return line + "  (spent)" if stamina.is_exhausted() else line
