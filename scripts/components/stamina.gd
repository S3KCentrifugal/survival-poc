class_name Stamina
extends RefCounted
## Spending and recovering effort over time, with an exhaustion lock.
##
## The state that makes sprinting feel like a decision rather than a toggle: a
## delay before the bar starts coming back, and a lockout that stops an actor
## sprinting the instant a single point returns.
##
## Node-free, so the timing can be tested at exact deltas instead of by feel.
## [StaminaComponent] runs one of these on the physics clock.

var pool: VitalPool

var _config: StaminaConfig

## Seconds still to wait before recovery resumes.
var _recovery_wait: float = 0.0

## True from running dry until [member StaminaConfig.exhausted_recovery_fraction]
## is back.
var _exhausted: bool = false


func _init(config: StaminaConfig) -> void:
	_config = config
	pool = VitalPool.new(config.maximum)


## Advances one tick.
##
## [param wants_to_drain] is the actor's intent; the return value is whether it
## was granted, and that is what a consumer gates its action on. Intent that
## cannot be granted still ticks recovery -- holding sprint with an empty bar
## must not stall the refill, or the actor never gets going again.
func tick(delta: float, wants_to_drain: bool) -> bool:
	if wants_to_drain and can_spend():
		_spend(delta)
		return true
	_recover(delta)
	return false


## True while there is effort left and the actor is not locked out.
func can_spend() -> bool:
	return not _exhausted and not pool.is_empty()


func is_exhausted() -> bool:
	return _exhausted


## Sets the bar directly, for a debug console or a scripted scene.
##
## Refilling past the recovery threshold lifts the lockout with it: an actor
## handed a full bar that still refuses to sprint looks broken. Setting it to
## empty exhausts, for the same reason in reverse.
func set_current(value: float) -> void:
	pool.set_current(value)
	if pool.is_empty():
		_exhausted = true
	elif pool.fraction() >= _config.exhausted_recovery_fraction:
		_exhausted = false


func _spend(delta: float) -> void:
	pool.drain(_config.drain_per_second * delta)
	_recovery_wait = _config.recovery_delay
	if pool.is_empty():
		_exhausted = true


## Counts down the delay, then refills with whatever time is left over.
##
## Splitting the tick rather than consuming the whole frame on the delay is what
## keeps recovery frame-rate independent: the same real time refills the same
## amount however it is sliced.
func _recover(delta: float) -> void:
	var available := delta
	if _recovery_wait > 0.0:
		var used := minf(_recovery_wait, available)
		_recovery_wait -= used
		available -= used
	if available <= 0.0:
		return

	pool.restore(_config.recovery_per_second * available)
	if _exhausted and pool.fraction() >= _config.exhausted_recovery_fraction:
		_exhausted = false
