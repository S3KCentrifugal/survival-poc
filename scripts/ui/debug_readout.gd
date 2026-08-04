class_name DebugReadout
extends RefCounted
## Formats the debug overlay's lines.
##
## Pure text from plain numbers, with no idea where any of it came from. The
## overlay is the only UI in the project and it is the thing most likely to be
## read at a glance during a bug, so what it says is worth testing -- a bar that
## silently reads full when a value is NaN is worse than no bar.
##
## Bars are ASCII on purpose. The default theme font is whatever Godot ships,
## and a debug tool that renders as boxes on someone else's machine has failed
## at its one job.

const BAR_WIDTH: int = 10
const LABEL_WIDTH: int = 8

## Shown in place of a value the overlay was never given.
const ABSENT: String = "--"


## A meter like [code][####------][/code].
##
## The fraction is clamped and NaN reads as empty, because the overlay is most
## useful in exactly the situation that produced the NaN.
static func bar(fraction: float, width: int = BAR_WIDTH) -> String:
	var safe := 0.0 if is_nan(fraction) else clampf(fraction, 0.0, 1.0)
	var filled := int(round(safe * width))
	return "[%s%s]" % ["#".repeat(filled), "-".repeat(width - filled)]


## A vital as a bar and its numbers: [code]health   [#####-----]  50 / 100[/code].
static func vital(name: String, current: float, maximum: float) -> String:
	var fraction := 0.0 if maximum <= 0.0 else current / maximum
	return "%s %s %5.0f / %.0f" % [_label(name), bar(fraction), current, maximum]


static func position(point: Vector3) -> String:
	return "%s %.1f, %.1f, %.1f" % [_label("pos"), point.x, point.y, point.z]


## Ground speed only -- a falling actor reading 20 m/s tells you nothing about
## how fast it is travelling.
static func speed(velocity: Vector3, sprinting: bool) -> String:
	var ground := Vector2(velocity.x, velocity.z).length()
	return "%s %.2f m/s%s" % [_label("speed"), ground, "  (sprint)" if sprinting else ""]


static func clock(time_text: String, daytime: bool) -> String:
	return "%s %s  (%s)" % [_label("time"), time_text, "day" if daytime else "night"]


static func frames_per_second(fps: int) -> String:
	return "%s %d" % [_label("fps"), fps]


static func state(name: String, value: String) -> String:
	return "%s %s" % [_label(name), value]


## A line for something the overlay is not watching. Present but blank, rather
## than missing: a line that disappears makes the panel jump around, and you
## cannot tell "no stamina component" from "I forgot to add the line".
static func absent(name: String) -> String:
	return "%s %s" % [_label(name), ABSENT]


static func _label(name: String) -> String:
	return name.rpad(LABEL_WIDTH)
