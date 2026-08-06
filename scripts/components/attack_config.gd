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


@export_group("Heavy")
## Seconds between heavy attacks, and how long one shows.
##
## Long enough to play most of the rig's 1.29 s kick rather than cutting it into
## a jab the way [member cooldown] cuts the punch. The wait *is* the cost: a
## heavy attack you can throw as fast as a light one is just a better light one.
@export_range(0.1, 5.0, 0.05) var heavy_cooldown: float = 1.15

@export_range(0.0, 1000.0, 1.0) var heavy_damage: float = 34.0

## A kick reaches further than a fist.
@export_range(0.2, 6.0, 0.1) var heavy_reach: float = 2.3

## Narrower than the punch. The trade for the damage is that you have to mean
## it -- a heavy that also forgives your aim is strictly better in every way.
@export_range(10.0, 360.0, 5.0) var heavy_arc_degrees: float = 70.0

## Stamina a heavy attack spends. Zero makes it free, which makes the light
## attack pointless.
@export_range(0.0, 200.0, 1.0) var heavy_stamina_cost: float = 25.0


func arc_radians() -> float:
	return deg_to_rad(arc_degrees)


func heavy_arc_radians() -> float:
	return deg_to_rad(heavy_arc_degrees)
