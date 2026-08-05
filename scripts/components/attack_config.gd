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
