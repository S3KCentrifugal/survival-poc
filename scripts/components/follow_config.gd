class_name FollowConfig
extends Resource
## Tuning for an actor that tags along.

## Seconds before it sets off after you. Short, but not zero: a companion that
## moves on the same frame you do is glued to you rather than following you.
@export_range(0.0, 10.0, 0.05) var start_delay: float = 0.6

## How close it settles. Closer than this and it stops.
@export_range(0.5, 20.0, 0.1) var stop_distance: float = 2.2

## How far you have to get before it sets off again.
##
## Larger than [member stop_distance] on purpose. With one threshold a companion
## hovering at exactly that range starts and stops every frame -- the same
## hysteresis the animation state machine needs, for the same reason.
@export_range(0.5, 30.0, 0.1) var resume_distance: float = 3.2

## Beyond this it sprints to catch up, spending stamina like anyone else.
@export_range(1.0, 60.0, 0.5) var sprint_distance: float = 9.0

## Seconds between path recalculations. Every frame is wasteful; too rare and it
## walks into walls you have already gone round.
@export_range(0.05, 5.0, 0.05) var repath_interval: float = 0.25


## Stop and resume distances, nearest first, with an inverted pair straightened
## out rather than trusted.
func distances() -> Vector2:
	return Vector2(minf(stop_distance, resume_distance), maxf(stop_distance, resume_distance))
