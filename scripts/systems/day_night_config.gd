class_name DayNightConfig
extends Resource
## Tuning for the day/night cycle.
##
## A placeholder in scope but not in structure: the numbers that decide how long
## a day lasts and what dusk looks like are the ones a designer will want to
## argue about, so they live in a .tres from the start.

## Real seconds in a full game day. Ten minutes is short enough to see the whole
## cycle in a play session and long enough that noon is not a strobe.
@export_range(10.0, 7200.0, 10.0) var day_length_seconds: float = 600.0

## Where a fresh world starts, as a fraction of the day: 0 is midnight, 0.25
## sunrise, 0.5 noon, 0.75 sunset. Morning by default -- a survival game that
## opens in the dark is a worse first impression than one that does not.
@export_range(0.0, 1.0, 0.01) var start_time: float = 0.3

## How far the sun's arc leans away from vertical, in degrees.
##
## Zero would send it exactly through the zenith, where the light direction is
## parallel to up and the basis that aims it is degenerate. A lean also gives
## shadows a direction at midday instead of stamping them underfoot.
@export_range(5.0, 60.0, 1.0) var sun_tilt_degrees: float = 20.0

## Elevation, as a fraction of straight up, over which the sun is at full
## strength. The band between the horizon and this is dawn and dusk.
@export_range(0.05, 1.0, 0.01) var twilight_band: float = 0.25

@export_group("Light")
@export_range(0.0, 16.0, 0.05) var day_energy: float = 1.0

## Never zero: a pitch-black night is not atmosphere, it is a bug report.
@export_range(0.0, 16.0, 0.01) var night_energy: float = 0.05

@export var day_color: Color = Color(1.0, 0.98, 0.94)
@export var horizon_color: Color = Color(1.0, 0.6, 0.35)
@export var night_color: Color = Color(0.45, 0.55, 0.85)
