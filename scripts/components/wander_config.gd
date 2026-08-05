class_name WanderConfig
extends Resource
## Tuning for an actor that mills about with nowhere to be.

## Shortest and longest stand-still between walks, in seconds.
@export_range(0.0, 60.0, 0.1) var pause_min: float = 1.5
@export_range(0.0, 60.0, 0.1) var pause_max: float = 5.0

## How far from home it is willing to stray, in metres.
@export_range(1.0, 200.0, 0.5) var radius: float = 8.0

## How close counts as arrived.
##
## Not tiny: a wanderer easing to a halt never lands exactly on a point, and one
## that demands precision shuffles on the spot forever.
@export_range(0.1, 5.0, 0.1) var arrival_distance: float = 0.7

## How long to keep trying before picking somewhere else.
##
## The important one. An actor wedged against a wall, or aiming at a spot inside
## a building, walks into it for the rest of the session without this.
@export_range(1.0, 120.0, 0.5) var give_up_seconds: float = 10.0


## Pause length limits, shortest first, with an inverted pair straightened out
## rather than trusted.
func pause_range() -> Vector2:
	return Vector2(minf(pause_min, pause_max), maxf(pause_min, pause_max))
