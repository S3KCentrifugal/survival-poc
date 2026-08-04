class_name HealthComponent
extends Node
## Tracks whether an actor is alive.
##
## Attach to anything that can be hurt. It holds no opinion about what damage
## means -- no armour, no damage types, no death animation, no respawn. It owns
## a number, refuses the impossible transitions, and announces the rest.
##
## Signals outward: the component never looks up who to tell.

## Emitted on every change, for a bar or anything else that watches.
signal changed(current: float, maximum: float)

## Emitted with the damage actually taken, which is not what was asked for when
## the blow was more than the actor had left.
signal damaged(amount: float)

signal healed(amount: float)

## Emitted once, on the transition to zero. The component does nothing else in
## response -- whoever owns the actor decides what dying looks like.
signal died

@export var config: HealthConfig

var _pool: VitalPool


func _ready() -> void:
	if config == null:
		push_warning("HealthComponent has no config; falling back to defaults")
	_ensure_pool()


func current() -> float:
	_ensure_pool()
	return _pool.current


func maximum() -> float:
	_ensure_pool()
	return _pool.maximum


func fraction() -> float:
	_ensure_pool()
	return _pool.fraction()


func is_alive() -> bool:
	_ensure_pool()
	return not _pool.is_empty()


## Applies [param amount] and returns the damage actually taken.
##
## A dead actor takes nothing further, so [signal died] can only fire once and
## a corpse cannot be reported as damaged.
func take_damage(amount: float) -> float:
	_ensure_pool()
	if not is_alive():
		return 0.0

	var taken := _pool.drain(amount)
	if taken <= 0.0:
		return 0.0

	damaged.emit(taken)
	changed.emit(_pool.current, _pool.maximum)
	if _pool.is_empty():
		died.emit()
	return taken


## Restores [param amount] and returns how much was actually restored.
##
## Healing the dead does nothing. Resurrection is a deliberate act elsewhere,
## not a side effect of a bandage landing a frame too late.
func heal(amount: float) -> float:
	_ensure_pool()
	if not is_alive():
		return 0.0

	var given := _pool.restore(amount)
	if given <= 0.0:
		return 0.0

	healed.emit(given)
	changed.emit(_pool.current, _pool.maximum)
	return given


## Builds the pool on first use rather than only in [method _ready], so a test
## or a tool can ask about health without mounting the actor in a scene tree.
func _ensure_pool() -> void:
	if _pool != null:
		return
	if config == null:
		config = HealthConfig.new()
	_pool = VitalPool.new(config.maximum)
