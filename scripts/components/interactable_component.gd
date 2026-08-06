class_name InteractableComponent
extends Node
## Something you can walk up to and press a key at.
##
## Attach beside whatever actually happens -- a [PickupComponent], a
## [WorkbenchComponent], a [MerchantComponent] -- and it answers the three
## questions everyone asks of a thing in reach: where is it, is it still there,
## and what would the prompt say. It does not know what any of them *do*, and
## does not want to.
##
## This replaces three copies of exactly these three methods, one per component,
## each with its own group and its own searcher. That is what composition is
## supposed to prevent: the behaviours stay separate, and the thing they have in
## common becomes a sibling rather than a base class.

## Everything interactable is in this group. One group, so one search finds
## every kind -- which is also what stops two of them each claiming the same
## key press.
const GROUP: StringName = &"interactable"

## Emitted when someone interacts. Whoever does the work listens; this only
## reports that it was asked for.
signal interacted(by: Node)

## What kind of thing this is, so a dispatcher can route without casting to
## three types in turn.
enum Kind { PICKUP, STATION, MERCHANT }

@export var kind: Kind = Kind.STATION

## The thing in the world. Defaults to this component's owner, because the actor
## is the natural answer and making every scene say so is noise.
@export var actor: Node3D

## What the prompt calls it. Blank falls back to whatever the behaviour beside
## this one is called.
@export var display_name: String = ""

@export var verb: String = "Use"

## How close you have to be. On the interactable rather than the reacher,
## because a merchant is bigger than a mushroom and the difference belongs to
## the thing, not to the person walking up to it.
@export_range(0.3, 8.0, 0.1) var reach: float = 2.2

## Set false while something is being removed, so a dying actor stops offering
## itself before it is gone.
var available: bool = true


func _ready() -> void:
	if actor == null:
		actor = owner as Node3D
	if actor == null:
		actor = get_parent() as Node3D
	add_to_group(GROUP)


## Where it is, for a distance check.
func world_position() -> Vector3:
	return Vector3.ZERO if actor == null else actor.global_position


## Whether it is still there to be interacted with. Anything mid-removal is not.
func is_available() -> bool:
	return (
		available
		and actor != null
		and is_instance_valid(actor)
		and not actor.is_queued_for_deletion()
	)


## What a prompt should read.
func prompt_text() -> String:
	return verb if display_name.is_empty() else "%s %s" % [verb, display_name]


## Called by whoever walked up and pressed the key.
func interact(by: Node = null) -> void:
	interacted.emit(by)


## Stops offering itself, without waiting for the actor to be freed.
##
## A pickup emptied by a bag that only had room for two of three is still
## standing there and should still be offered; one that has been taken
## completely should not, and `queue_free` does not take effect until the end of
## the frame.
func retire() -> void:
	available = false
	remove_from_group(GROUP)
