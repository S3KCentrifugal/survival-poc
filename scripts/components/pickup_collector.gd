class_name PickupCollector
extends Node
## Picks things up when the player asks.
##
## Deciding *what* is in reach is a static function over a list of candidates,
## so it needs no physics frame and can be tested with numbers.
##
## Deciding *when* to take it used to be here too, on the interact key. It moved
## to [InteractionRouter] when merchants arrived on the same key: two components
## each watching F means standing between a mushroom and a merchant does both.
## Everything public here still works -- the router calls [method collect], and
## so can a console or a test.

## Emitted when what is in reach changes, including to nothing. A prompt reads
## this rather than polling.
signal target_changed(pickup: PickupComponent)

## Emitted on a successful pickup.
signal collected(definition: ItemDefinition, amount: int)

## Emitted when something was in reach and would not fit.
signal bag_full(definition: ItemDefinition)

## The actor doing the reaching, so distance is measured from a body rather
## than from wherever this node happens to sit.
@export var body: Node3D

@export var inventory: InventoryComponent

## How far the player can reach, in metres.
##
## Generous on purpose. A radius tight enough to feel precise is one you have to
## shuffle around to satisfy, and picking a mushroom is not meant to be a skill
## check.
@export_range(0.5, 8.0, 0.1) var reach: float = 2.2

var _target: PickupComponent


func _process(_delta: float) -> void:
	step()


## One tick: work out what is in reach, for the prompt.
##
## No longer reads the key -- [InteractionRouter] owns that. Public so a test
## can drive it without waiting on a frame.
func step() -> void:
	_set_target(find_target())


## Picks up whatever is in reach. Returns how many were taken.
##
## Public and separate from the input edge, so the dev console or a test can
## pick something up without pretending to press a key.
func collect() -> int:
	# Looks first. Anything else makes this work only after a step() that
	# happened to run this frame, which is a rule nobody would guess.
	_set_target(find_target())
	if _target == null or not _target.is_available():
		return 0
	var definition := _target.definition
	var taken := _target.collect_into(inventory)
	if taken > 0:
		collected.emit(definition, taken)
	else:
		bag_full.emit(definition)
	# It may have been emptied and freed, so the target is re-found rather than
	# assumed still valid.
	_set_target(find_target())
	return taken


## What is in reach right now, or null.
func find_target() -> PickupComponent:
	if body == null or not is_inside_tree():
		return null
	return Proximity.nearest(
		body.global_position, get_tree().get_nodes_in_group(PickupComponent.GROUP), reach
	) as PickupComponent


## What the player is about to pick up, for a prompt.
func target() -> PickupComponent:
	return _target


## The closest available pickup within [param reach] of [param from], or null.
##
## Kept as a named entry point after the search itself moved to [Proximity] --
## the workbench wanted the same search, and two of them is how one of them ends
## up with a different reach.
static func nearest(from: Vector3, candidates: Array, reach: float) -> PickupComponent:
	return Proximity.nearest(from, candidates, reach) as PickupComponent


func _set_target(pickup: PickupComponent) -> void:
	if pickup == _target:
		return
	_target = pickup
	target_changed.emit(pickup)
