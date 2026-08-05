class_name PickupCollector
extends Node
## Picks things up when the player asks.
##
## Two jobs, kept apart: deciding *what* is in reach, which is a static function
## over a list of candidates, and deciding *when* to take it, which is the same
## rising-edge pattern jumping and punching already use. Neither needs a physics
## frame, so both can be tested with numbers.

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

## Where intent comes from. Assigned by whoever assembles the actor, exactly as
## movement's is -- so a scripted source, or eventually a remote one, picks
## things up the same way a keyboard does.
var input_source: InputSource

## Whether the key was held last tick. Holding F must not empty a patch.
var _interact_held: bool = false

var _target: PickupComponent


func _process(_delta: float) -> void:
	step()


## One tick: find what is in reach, and take it if asked.
##
## Public so a test can drive it without waiting on a frame.
func step() -> void:
	_set_target(find_target())
	if input_source == null:
		return

	var state := input_source.poll()
	var pressed := state.interact and not _interact_held
	_interact_held = state.interact
	if pressed:
		collect()


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
