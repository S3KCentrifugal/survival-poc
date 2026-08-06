class_name StaminaComponent
extends Node
## Runs an actor's [Stamina] on the physics clock.
##
## Attach to anything that gets tired. It never decides what effort is for --
## sprinting, swinging, climbing -- it only answers whether there is any to be
## had and drains it when asked.

## Emitted on every change, for a bar or anything else that watches.
signal changed(current: float, maximum: float)

## Emitted on running dry, and again when the lockout lifts. Useful for the
## grunt, the screen tint, or the AI deciding to break off a chase.
signal exhausted
signal recovered

@export var config: StaminaConfig

var _stamina: Stamina

## Intent for the coming tick, cleared as it is consumed.
var _requested: bool = false


func _ready() -> void:
	if config == null:
		push_warning("StaminaComponent has no config; falling back to defaults")
	_ensure_stamina()


func _physics_process(delta: float) -> void:
	step(delta)


## Asks to spend stamina on the next tick.
##
## A latch rather than a direct call: whatever wants the effort says so on every
## frame it wants it, and reads the answer back from [method can_spend]. Because
## the latch is cleared every tick, letting go of the key is simply the absence
## of a request -- there is no "stop" to forget, and no way to leave an actor
## draining forever.
func request_drain() -> void:
	_requested = true


## Advances one tick and returns whether effort was actually spent.
##
## Public so tests and tools can drive stamina deterministically rather than
## waiting on the physics clock.
func step(delta: float) -> bool:
	_ensure_stamina()
	var was_exhausted := _stamina.is_exhausted()
	var before := _stamina.pool.current

	var spent := _stamina.tick(delta, _requested)
	_requested = false

	if not is_equal_approx(before, _stamina.pool.current):
		changed.emit(_stamina.pool.current, _stamina.pool.maximum)
	if _stamina.is_exhausted() and not was_exhausted:
		exhausted.emit()
	elif was_exhausted and not _stamina.is_exhausted():
		recovered.emit()
	return spent


func current() -> float:
	_ensure_stamina()
	return _stamina.pool.current


func maximum() -> float:
	_ensure_stamina()
	return _stamina.pool.maximum


func fraction() -> float:
	_ensure_stamina()
	return _stamina.pool.fraction()


## Whether effort would be granted right now. Read this to gate an action.
func can_spend() -> bool:
	_ensure_stamina()
	return _stamina.can_spend()


func is_exhausted() -> bool:
	_ensure_stamina()
	return _stamina.is_exhausted()


## Sets the bar directly, for a debug console or a scripted scene. Announces the
## change like any other, so a bar redraws.
## Takes a lump sum out. Returns whether it was paid in full.
##
## Different from [method request_drain], which is the per-second cost of
## sprinting: this is one price for one action. Refuses outright rather than
## taking what it can -- a heavy attack that half-happens for half the stamina
## is not a thing anyone wants to explain.
func spend(amount: float) -> bool:
	_ensure_stamina()
	if amount <= 0.0:
		return true
	if current() < amount:
		return false
	set_current(current() - amount)
	return true


func set_current(value: float) -> void:
	_ensure_stamina()
	var was_exhausted := _stamina.is_exhausted()
	_stamina.set_current(value)
	changed.emit(_stamina.pool.current, _stamina.pool.maximum)
	if _stamina.is_exhausted() and not was_exhausted:
		exhausted.emit()
	elif was_exhausted and not _stamina.is_exhausted():
		recovered.emit()


## Builds the stamina on first use rather than only in [method _ready], so a
## test or a tool can drive it without mounting the actor in a scene tree.
func _ensure_stamina() -> void:
	if _stamina != null:
		return
	if config == null:
		config = StaminaConfig.new()
	_stamina = Stamina.new(config)
