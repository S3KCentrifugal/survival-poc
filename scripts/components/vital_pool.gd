class_name VitalPool
extends RefCounted
## A bounded quantity that goes down and comes back up.
##
## Health and stamina are the same shape -- a current value, a ceiling, and the
## rule that neither end overshoots -- so the clamping lives here once and both
## components compose one rather than each getting the edge cases subtly
## different. Hunger, thirst and temperature will want the same thing.
##
## Node-free on purpose: every rule below can be checked without a scene tree.

var maximum: float
var current: float


func _init(pool_maximum: float, start_full: bool = true) -> void:
	maximum = maxf(pool_maximum, 0.0)
	current = maximum if start_full else 0.0


## Moves the ceiling, keeping the current value underneath it.
##
## Lowering the maximum spills the excess; raising it does not heal, which is
## what a buff that grants extra capacity should feel like.
func set_maximum(value: float) -> void:
	maximum = maxf(value, 0.0)
	current = minf(current, maximum)


func set_current(value: float) -> void:
	current = clampf(value, 0.0, maximum)


## Removes up to [param amount] and returns how much was actually removed.
##
## The return value is what lets a caller tell a partial spend from a full one:
## draining 30 from a pool holding 10 costs 10, and the caller often needs to
## know that. Negative amounts remove nothing rather than quietly healing.
func drain(amount: float) -> float:
	var taken := minf(maxf(amount, 0.0), current)
	current -= taken
	return taken


## Adds up to [param amount] and returns how much was actually added.
func restore(amount: float) -> float:
	var given := minf(maxf(amount, 0.0), maximum - current)
	current += given
	return given


func fill() -> void:
	current = maximum


func empty() -> void:
	current = 0.0


## Proportion of the ceiling, 0..1. A zero maximum reads as empty rather than
## dividing by zero -- UI asks for this every frame and must never see a NaN.
func fraction() -> float:
	return 0.0 if maximum <= 0.0 else current / maximum


func is_empty() -> bool:
	return current <= 0.0


func is_full() -> bool:
	return current >= maximum


func _to_string() -> String:
	return "<VitalPool %.1f/%.1f>" % [current, maximum]
