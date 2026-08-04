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
