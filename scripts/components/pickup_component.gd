class_name PickupComponent
extends Node
## What happens when you pick something up.
##
## Being *reachable* is [InteractableComponent]'s job, sitting beside this one:
## where it is, whether it is still there, what the prompt says. This is only
## the transfer. Splitting them is what let three near-identical components --
## this, the workbench and the merchant -- stop each carrying their own copy of
## the same three methods.

## Emitted once it has been taken, before the actor is freed.
signal taken(definition: ItemDefinition, amount: int)

@export var definition: ItemDefinition

## How many are in the pile.
##
## A setter, so the prompt follows. A dropped stack has its amount written
## *after* the scene is instantiated -- exactly the shape of the capacity bug in
## feature 31, where a property read once in _ready did nothing for half its
## callers.
@export_range(1, 999, 1) var amount: int = 1:
	set(value):
		amount = maxi(value, 0)
		_refresh_prompt()

## The thing in the world. Defaults to this component's owner.
@export var actor: Node3D

## Where being-in-reach lives. The prompt text is kept in step with what is
## actually left in the pile from here.
@export var interactable: InteractableComponent


func _ready() -> void:
	if actor == null:
		actor = owner as Node3D
	if actor == null:
		actor = get_parent() as Node3D
	if interactable != null:
		interactable.interacted.connect(_on_interacted)
		_refresh_prompt()


## Whether there is anything left to take.
func is_available() -> bool:
	return definition != null and definition.is_valid() and amount > 0


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
		if interactable != null:
			# Stops offering itself now rather than at the end of the frame,
			# which is when queue_free actually takes effect.
			interactable.retire()
		actor.queue_free()
	else:
		_refresh_prompt()
	return collected


## Whoever it belongs to, told by the router.
func _on_interacted(by: Node) -> void:
	collect_into(_inventory_of(by))


## The bag on the thing that reached for this.
##
## Looked up rather than exported, because a pickup is reached for by whoever
## happens to walk past -- it cannot know in advance whose bag it goes into, and
## in multiplayer that is the whole point.
func _inventory_of(by: Node) -> InventoryComponent:
	if by == null:
		return null
	for child: Node in by.get_children():
		var inventory := child as InventoryComponent
		if inventory != null:
			return inventory
	return null


## Keeps the prompt saying how many are left.
func _refresh_prompt() -> void:
	if interactable == null or definition == null:
		return
	interactable.display_name = (
		definition.display_name if amount <= 1 else "%s x%d" % [definition.display_name, amount]
	)
