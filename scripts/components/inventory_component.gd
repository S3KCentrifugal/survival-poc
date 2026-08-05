class_name InventoryComponent
extends Node
## What an actor is carrying.
##
## A thin node over [Inventory]: it owns one, sizes it from the scene, and
## tells the world when it changes. Every rule about stacking lives in the
## [RefCounted] and can be tested without any of this.
##
## On an actor rather than in a global store, so a chest, a corpse and a second
## player are the same component in a different place.

## Emitted after anything changes what is held. Carries nothing: a bag is small
## enough to redraw whole, and a diff is a thing to get wrong.
signal changed

## Emitted when something is taken in, for a sound or a pickup line.
signal collected(definition: ItemDefinition, amount: int)

## Emitted when a pickup would not fit, so the world can say so rather than
## silently swallowing it.
signal rejected(definition: ItemDefinition, amount: int)

## How many slots. Applied whenever it is set, not just at startup: a property
## that only takes effect if you happen to write it before _ready is a property
## that does nothing for half its callers.
##
## Shrinking discards whatever was in the lost slots, so it is not something to
## do to a bag someone is carrying.
@export_range(1, 100, 1) var capacity: int = 20:
	set(value):
		capacity = maxi(value, 1)
		if _inventory != null:
			_inventory.resize(capacity)

var _inventory: Inventory


func _ready() -> void:
	_ensure_inventory()


## The bag itself, for a UI to draw or a test to inspect.
func inventory() -> Inventory:
	_ensure_inventory()
	return _inventory


## Takes items in. Returns how many did not fit, which is zero on success.
func collect(definition: ItemDefinition, amount: int = 1) -> int:
	_ensure_inventory()
	var left := _inventory.add(definition, amount)
	var taken := amount - left
	if taken > 0:
		collected.emit(definition, taken)
		changed.emit()
	if left > 0:
		rejected.emit(definition, left)
	return left


## Takes items out. Returns how many actually came.
func drop(id: StringName, amount: int = 1) -> int:
	_ensure_inventory()
	var taken := _inventory.remove(id, amount)
	if taken > 0:
		changed.emit()
	return taken


func count_of(id: StringName) -> int:
	_ensure_inventory()
	return _inventory.count_of(id)


func _ensure_inventory() -> void:
	if _inventory == null:
		_inventory = Inventory.new(capacity)
