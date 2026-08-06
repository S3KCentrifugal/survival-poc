class_name AnimationConfig
extends Resource
## Thresholds and clip names for an actor's animation state machine.
##
## The two speeds are a hysteresis band, not one threshold used twice. See
## [AnimationStateMachine] for why that matters.

## Ground speed at which a standing actor is considered to be moving.
@export_range(0.0, 10.0, 0.05) var move_enter_speed: float = 0.4

## Ground speed at which a moving actor is considered to have stopped.
##
## Lower than [member move_enter_speed] on purpose. With a single threshold, an
## actor drifting at exactly that speed flips between idle and walk every frame,
## which restarts the clip over and over and reads as a twitch.
@export_range(0.0, 10.0, 0.05) var move_exit_speed: float = 0.15

## Seconds to blend between clips. Zero snaps.
@export_range(0.0, 1.0, 0.01) var transition_time: float = 0.15

@export_group("Clips")
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var run_animation: StringName = &"run"
@export var jump_animation: StringName = &"jump"
@export var punch_animation: StringName = &"punch"

## The heavy attack. A different clip, not the punch played slowly: "make it
## obvious this one is stronger" is answered by a different move, and the rig
## already has a kick.
@export var heavy_animation: StringName = &"heavy"
@export var hurt_animation: StringName = &"hurt"
@export var fall_animation: StringName = &"fall"
