class_name MovementConfig
extends Resource
## Tuning for a walking actor.
##
## Shared by anything that walks -- the player now, enemies later -- with a
## different .tres per actor.

## What an actor turns to face.
enum FacingMode {
	## Face the way you are travelling. Reads as a character who looks where
	## they are going.
	MOVEMENT,
	## Face the cursor regardless of travel, so the actor can strafe and back
	## away while still pointing at something. What an ARPG does while fighting.
	CURSOR,
}

## Which candidate wins when both are available.
##
## A design decision rather than a detail, which is why it is a config value and
## not a rule buried in the component. Combat may well want [constant
## FacingMode.CURSOR] later without every actor changing with it.
@export var facing_mode: FacingMode = FacingMode.MOVEMENT

## Ground speed in metres per second.
@export_range(0.5, 20.0, 0.1) var walk_speed: float = 4.5

## How fast the actor reaches walk speed, in m/s². Higher feels snappier.
@export_range(1.0, 200.0, 1.0) var acceleration: float = 30.0

## How fast the actor stops. Usually higher than acceleration, so releasing the
## keys feels responsive without making starts feel twitchy.
@export_range(1.0, 200.0, 1.0) var deceleration: float = 45.0

## What sprinting multiplies walk speed by.
##
## A multiplier rather than a second speed, so retuning the walk keeps the
## relationship between the two -- the gap is what the player feels, not the
## absolute number.
@export_range(1.0, 4.0, 0.05) var sprint_multiplier: float = 1.7

## Turn rate in degrees per second. Top-down games turn fast; anything slower
## than a few hundred feels like steering a boat.
@export_range(45.0, 2000.0, 5.0) var turn_speed_degrees: float = 720.0

## Downward acceleration in m/s². Higher than Earth's on purpose -- real
## gravity feels floaty in a game at this scale.
@export_range(1.0, 60.0, 0.5) var gravity: float = 20.0


func turn_speed_radians() -> float:
	return deg_to_rad(turn_speed_degrees)
