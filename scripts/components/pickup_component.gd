class_name PickupComponent
extends Node
## Marks a thing in the world as something you can pick up.
##
## Attach to an item's scene and point [member actor] at it. Joins a group
## rather than carrying an [Area3D], so finding one is a distance check over a
## short list instead of a physics query -- which means a test can put two
## mushrooms and a player in a bare tree and check which one gets picked,
## with no physics frame and no collision layers to get wrong.
##
## Fine at this scale. A world with thousands of loose items wants a spatial
## index, and that is the day this becomes an Area3D.

## Everything pickable is in this group. A group rather than a list held by the
## collector, so an item spawned by anything at all is findable without telling
## anyone it exists.
const GROUP: StringName = &"pickup"

## Emitted once it has been taken, before the actor is freed.
signal taken(definition: ItemDefinition, amount: int)

@export var definition: ItemDefinition

@export_range(1, 999, 1) var amount: int = 1

## The thing in the world. Defaults to this component's owner.
@export var actor: Node3D

## What a prompt says. Falls back to the item's own name.
@export var verb: String = "Pick up"


func _ready() -> void:
	if actor == null:
		actor = owner as Node3D
	if actor == null:
		actor = get_parent() as Node3D
	add_to_group(GROUP)


## Where it is, for a distance check.
func world_position() -> Vector3:
	return Vector3.ZERO if actor == null else actor.global_position


## Whether it is still there to be taken. A pickup mid-removal is not.
func is_available() -> bool:
	return (
		definition != null
		and definition.is_valid()
		and amount > 0
		and actor != null
		and is_instance_valid(actor)
		and not actor.is_queued_for_deletion()
	)


## Hands the item to [param inventory] and removes what was taken.
##
## Returns how many were collected. A bag with room for two of three leaves one
## behind rather than deleting it -- an item that vanishes because you were full
## is worse than one you could not pick up.
func collect_into(inventory: InventoryComponent) -> int:
	if inventory == null or not is_available():
		return 0
	var left := inventory.collect(definition, amount)
	var collected := amount - left
	if collected <= 0:
		return 0

	amount = left
	taken.emit(definition, collected)
	if amount <= 0:
		remove_from_group(GROUP)
		actor.queue_free()
	return collected


## What a prompt should read.
func prompt_text() -> String:
	if definition == null:
		return verb
	var name := definition.display_name
	return "%s %s" % [verb, name] if amount <= 1 else "%s %s x%d" % [verb, name, amount]
