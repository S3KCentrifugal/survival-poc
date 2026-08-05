class_name WorkbenchComponent
extends Node
## A place in the world where things are made.
##
## Holds the recipes and performs them against an [Inventory]. What a recipe
## *is* belongs to [Recipe]; where the bench stands belongs to the scene; this
## is the seam between them.
##
## Joins the interactable group so [Interactor] can find it, the same way
## [PickupComponent] joins the pickup group. Both are found by
## [Proximity.nearest], which is why neither needs an Area3D.

## Everything you can walk up to and use is in this group.
const GROUP: StringName = &"interactable"

## Emitted when someone uses the bench, for a UI to open on.
signal used(by: Node)

## Emitted after something is made.
signal crafted(recipe: Recipe, amount: int)

## Emitted when a craft was asked for and could not happen, so the UI can say
## why rather than doing nothing.
signal refused(recipe: Recipe, reason: String)

@export var recipes: Array[Recipe] = []

## The thing in the world. Defaults to this component's owner.
@export var actor: Node3D

@export var display_name: String = "Workbench"

@export var verb: String = "Use"


func _ready() -> void:
	if actor == null:
		actor = owner as Node3D
	if actor == null:
		actor = get_parent() as Node3D
	add_to_group(GROUP)


## Where it is, for a distance check.
func world_position() -> Vector3:
	return Vector3.ZERO if actor == null else actor.global_position


## Whether it can be used. A bench is not consumed, so this is only ever false
## while it is being removed.
func is_available() -> bool:
	return actor != null and is_instance_valid(actor) and not actor.is_queued_for_deletion()


## What a prompt should read.
func prompt_text() -> String:
	return "%s %s" % [verb, display_name]


## Called by whoever walked up and pressed the key.
func use(by: Node = null) -> void:
	used.emit(by)


## Makes [param recipe] from [param inventory]. Returns how many were made.
##
## The bench performs the craft rather than the UI, so a console command or a
## test can make soup without opening a panel.
func craft(recipe: Recipe, inventory: InventoryComponent) -> int:
	if recipe == null or inventory == null:
		return 0
	if not recipes.has(recipe):
		refused.emit(recipe, "This bench does not make that.")
		return 0

	var bag := inventory.inventory()
	if not recipe.has_ingredients(bag):
		refused.emit(recipe, "Not enough ingredients.")
		return 0
	if not recipe.has_room_for_result(bag):
		refused.emit(recipe, "No room for the result.")
		return 0

	var made := recipe.craft(bag)
	if made <= 0:
		refused.emit(recipe, "Nothing was made.")
		return 0
	# The bag changed underneath the component, so it has to be told: nothing
	# else knows the difference between crafting and a stack quietly moving.
	inventory.changed.emit()
	crafted.emit(recipe, made)
	return made


## Which recipes could be made right now, for a UI to grey out the rest.
func available_recipes(inventory: InventoryComponent) -> Array[Recipe]:
	var ready: Array[Recipe] = []
	if inventory == null:
		return ready
	var bag := inventory.inventory()
	for recipe: Recipe in recipes:
		if recipe != null and recipe.can_craft(bag):
			ready.append(recipe)
	return ready
