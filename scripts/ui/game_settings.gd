class_name GameSettings
extends RefCounted
## Everything the player can change about how the game looks and feels.
##
## Plain data with the rules about what is valid, and nothing that touches a
## window, a renderer or a file. [SettingsStore] persists one of these and
## [SettingsApplier] makes the machine obey it -- which is what lets the awkward
## parts (a monitor that was unplugged, a config file someone edited by hand) be
## tested without a display at all.

enum DisplayMode {
	## A normal window with a border, at [member resolution].
	WINDOWED,
	## Exclusive fullscreen: the monitor changes mode for us.
	FULLSCREEN,
	## Borderless window filling the monitor. Alt-tabs instantly, which is why
	## most people leave it here.
	BORDERLESS,
}

## Multisampling levels offered. Anything else is rounded down to one of these.
const MSAA_LEVELS: Array[int] = [0, 2, 4, 8]

## Frame rate caps offered. 0 is uncapped.
const FPS_CAPS: Array[int] = [0, 30, 60, 120, 144, 240]

const MIN_RESOLUTION: Vector2i = Vector2i(640, 360)

var display_mode: DisplayMode = DisplayMode.WINDOWED

## Window size when windowed. Ignored by the two fullscreen modes, which take
## the monitor's size -- but remembered, so going back to windowed restores it.
var resolution: Vector2i = Vector2i(1600, 900)

## Which screen to open on, zero-based.
var monitor: int = 0

var vsync: bool = true

## Frame cap, 0 for uncapped.
var max_fps: int = 0

var msaa: int = 0

## Fraction of the output resolution the 3D scene is rendered at. Below 1 it is
## upscaled -- the cheapest large performance win there is.
var render_scale: float = 1.0

## Linear, 0 silent to 1 full. Converted to decibels only when applied, because
## a slider that moves in decibels feels wrong for most of its travel.
var master_volume: float = 1.0

var look_sensitivity: float = 0.22

var invert_pitch: bool = false


## The resolutions offered in the menu.
##
## A fixed list rather than everything the monitor reports: the full list from
## [method DisplayServer.screen_get_size] includes a dozen near-duplicates and
## refresh-rate variants, and nobody wants to scroll it.
static func resolutions() -> Array[Vector2i]:
	return [
		Vector2i(1280, 720),
		Vector2i(1366, 768),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3440, 1440),
		Vector2i(3840, 2160),
	]


## Forces every value back into a range the machine can honour.
##
## [param screen_count] is how many monitors exist right now. A settings file
## written on a two-monitor desk and opened on a laptop would otherwise put the
## window on a screen that is not there, which looks exactly like the game
## failing to start.
func sanitise(screen_count: int = 1) -> void:
	display_mode = clampi(display_mode, 0, DisplayMode.size() - 1) as DisplayMode
	resolution = Vector2i(
		maxi(resolution.x, MIN_RESOLUTION.x), maxi(resolution.y, MIN_RESOLUTION.y)
	)
	monitor = clampi(monitor, 0, maxi(screen_count - 1, 0))
	max_fps = _nearest_at_or_below(max_fps, FPS_CAPS)
	msaa = _nearest_at_or_below(msaa, MSAA_LEVELS)
	render_scale = clampf(render_scale, 0.5, 2.0)
	master_volume = clampf(master_volume, 0.0, 1.0)
	look_sensitivity = clampf(look_sensitivity, 0.01, 2.0)


func duplicate_settings() -> GameSettings:
	return GameSettings.from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"display_mode": int(display_mode),
		"resolution_x": resolution.x,
		"resolution_y": resolution.y,
		"monitor": monitor,
		"vsync": vsync,
		"max_fps": max_fps,
		"msaa": msaa,
		"render_scale": render_scale,
		"master_volume": master_volume,
		"look_sensitivity": look_sensitivity,
		"invert_pitch": invert_pitch,
	}


## Reads a settings object out of loose values.
##
## Every field falls back to its default if it is missing or the wrong type, so
## a truncated or hand-edited file loses one setting rather than all of them.
static func from_dictionary(values: Dictionary) -> GameSettings:
	var settings := GameSettings.new()
	settings.display_mode = _int_from(values, "display_mode", settings.display_mode) as DisplayMode
	settings.resolution = Vector2i(
		_int_from(values, "resolution_x", settings.resolution.x),
		_int_from(values, "resolution_y", settings.resolution.y)
	)
	settings.monitor = _int_from(values, "monitor", settings.monitor)
	settings.vsync = _bool_from(values, "vsync", settings.vsync)
	settings.max_fps = _int_from(values, "max_fps", settings.max_fps)
	settings.msaa = _int_from(values, "msaa", settings.msaa)
	settings.render_scale = _float_from(values, "render_scale", settings.render_scale)
	settings.master_volume = _float_from(values, "master_volume", settings.master_volume)
	settings.look_sensitivity = _float_from(values, "look_sensitivity", settings.look_sensitivity)
	settings.invert_pitch = _bool_from(values, "invert_pitch", settings.invert_pitch)
	return settings


func matches(other: GameSettings) -> bool:
	return other != null and to_dictionary() == other.to_dictionary()


## Whether this mode draws at the monitor's size rather than [member
## resolution], which is what greys the resolution picker out.
func uses_monitor_size() -> bool:
	return display_mode != DisplayMode.WINDOWED


static func display_mode_name(mode: DisplayMode) -> String:
	match mode:
		DisplayMode.FULLSCREEN:
			return "Fullscreen"
		DisplayMode.BORDERLESS:
			return "Borderless fullscreen"
		_:
			return "Windowed"


## The largest allowed value at or below [param wanted], or the smallest allowed
## one if it is below them all. Rounding *down* on purpose: a settings file
## asking for more than we offer should not silently get more than it asked for.
static func _nearest_at_or_below(wanted: int, allowed: Array[int]) -> int:
	var best: int = allowed[0]
	for value: int in allowed:
		if value <= wanted and value > best:
			best = value
	return best if wanted >= allowed[0] else allowed[0]


static func _int_from(values: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = values.get(key)
	return int(value) if value is int or value is float else fallback


static func _float_from(values: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = values.get(key)
	return float(value) if value is int or value is float else fallback


static func _bool_from(values: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = values.get(key)
	return bool(value) if value is bool else fallback
