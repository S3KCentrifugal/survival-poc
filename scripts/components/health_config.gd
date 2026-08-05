class_name HealthConfig
extends Resource
## Tuning for anything that can be hurt.
##
## One .tres per kind of actor: the player is not as tough as a bear, and that
## difference should be an edit to a resource rather than to a script.

## Maximum health. The unit is arbitrary but shared -- every damage number in
## the game is denominated in these, so changing the scale here changes what
## every weapon means.
@export_range(1.0, 10000.0, 1.0) var maximum: float = 100.0

## Health returned per second once regeneration starts. Zero disables it.
@export_range(0.0, 100.0, 0.1) var regen_per_second: float = 3.0

## Quiet seconds after taking a hit before regeneration begins.
##
## The same shape as stamina's recovery delay, and for the same reason: without
## it, health ticks back up between blows and a fight has no attrition in it.
@export_range(0.0, 60.0, 0.1) var regen_delay: float = 6.0
