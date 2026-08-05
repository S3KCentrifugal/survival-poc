class_name Cooldown
extends RefCounted
## A thing you cannot do again yet.
##
## Deliberately generic. Punching wants one; so will eating, crafting, and
## anything else that must not be spammable. Getting the frame-rate independence
## and the edges right once is worth more than five slightly different countdown
## floats scattered through components.
##
## Node-free, so "does it drift at 144 fps" is an assertion rather than
## something you find out on someone else's machine.

## Seconds between uses. Zero or less means no limit at all.
var duration: float

## Seconds still to wait. Zero when ready.
var remaining: float = 0.0


func _init(p_duration: float = 0.0) -> void:
	duration = maxf(p_duration, 0.0)


func is_ready() -> bool:
	return remaining <= 0.0


## Starts the wait if it is over, and reports whether it did.
##
## The check and the start are one call on purpose. Two calls invite the bug
## where something asks whether it may act, acts, and forgets to say so.
func use() -> bool:
	if not is_ready():
		return false
	remaining = duration
	return true


## Counts down by [param delta].
func advance(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(remaining - delta, 0.0)


## How much of the wait is left, 1 at the moment of use and 0 when ready. Zero
## for a cooldown with no duration, which is always ready.
func fraction() -> float:
	return 0.0 if duration <= 0.0 else clampf(remaining / duration, 0.0, 1.0)


## Makes it usable immediately.
func clear() -> void:
	remaining = 0.0
