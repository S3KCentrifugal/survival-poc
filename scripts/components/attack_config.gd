class_name AttackConfig
extends Resource
## Tuning for an actor's melee swing.

## Seconds between punches, and also how long the punch shows.
##
## The two are the same number on purpose. The rig's swing is 1.21 s; at the
## default this deliberately cuts it into a jab, because a punch you have to
## wait out is not a punch you would click twice. Raise it and you get the
## fuller swing along with the slower rate.
@export_range(0.05, 3.0, 0.05) var cooldown: float = 0.35

## How far a punch reaches, in metres from the attacker's centre.
##
## Generous next to an arm, because both characters are 0.4 m capsules and a
## reach measured centre-to-centre has two radii to cross before it touches.
@export_range(0.2, 6.0, 0.1) var reach: float = 1.8

## Width of the swing, in degrees. Wide enough to forgive aim, narrow enough
## that punching forwards does not hit somebody behind your shoulder.
@export_range(10.0, 360.0, 5.0) var arc_degrees: float = 110.0

## Damage per landed punch.
@export_range(0.0, 1000.0, 1.0) var damage: float = 12.0

## Physics layers a punch can land on.
@export_flags_3d_physics var hit_mask: int = 1

## Most bodies a single swing may land on. A punch into a crowd should not have
## to walk an unbounded list.
@export_range(1, 32, 1) var max_targets: int = 8


func arc_radians() -> float:
	return deg_to_rad(arc_degrees)
