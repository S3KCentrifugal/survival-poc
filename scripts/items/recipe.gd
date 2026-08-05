class_name Recipe
extends Resource
## Turns some items into another item.
##
## A list of ingredients rather than a single one, even though the only recipe
## today takes one thing. The list costs a few lines now; discovering that soup
## also wants water after the signature is load-bearing costs a refactor.
##
## Knows how to check and perform itself against an [Inventory], which is a
## [RefCounted] -- so crafting is testable with no bench, no player and no
## scene.

@export var id: StringName = &""

@export var display_name: String = "Recipe"

@export var ingredients: Array[RecipeIngredient] = []

@export var output: ItemDefinition

@export_range(1, 999, 1) var output_count: int = 1


func is_valid() -> bool:
	if id.is_empty() or output == null or not output.is_valid() or ingredients.is_empty():
		return false
	for ingredient: RecipeIngredient in ingredients:
		if ingredient == null or not ingredient.is_valid():
			return false
	return true


## Whether [param inventory] holds everything this needs.
func has_ingredients(inventory: Inventory) -> bool:
	if inventory == null or not is_valid():
		return false
	for ingredient: RecipeIngredient in ingredients:
		if not inventory.has(ingredient.item.id, ingredient.count):
			return false
	return true


## Whether the result would fit once the ingredients are gone.
##
## Checked *after* the ingredients are notionally removed, because they usually
## free the room the result needs -- refusing to make soup in a full bag when
## the soup replaces the mushrooms would be a rule nobody could work out.
func has_room_for_result(inventory: Inventory) -> bool:
	if inventory == null or not is_valid():
		return false
	# Counting rather than simulating: a slot is freed by an ingredient only if
	# that ingredient empties it, and asking the bag is cheaper than copying it.
	if inventory.has_room_for(output, output_count):
		return true
	for ingredient: RecipeIngredient in ingredients:
		if inventory.count_of(ingredient.item.id) == ingredient.count:
			return true
	return false


func can_craft(inventory: Inventory) -> bool:
	return has_ingredients(inventory) and has_room_for_result(inventory)


## Consumes the ingredients and adds the result. Returns how many were made.
##
## All or nothing. A craft that took the mushrooms and then found no room for
## the soup would be the worst bug this system could have, so the ingredients
## are only removed once the whole thing is known to work.
func craft(inventory: Inventory) -> int:
	if not can_craft(inventory):
		return 0
	for ingredient: RecipeIngredient in ingredients:
		inventory.remove(ingredient.item.id, ingredient.count)
	var left := inventory.add(output, output_count)
	return output_count - left


## What the recipe reads as, for a button.
func summary() -> String:
	var parts: Array[String] = []
	for ingredient: RecipeIngredient in ingredients:
		parts.append(str(ingredient))
	return "%s  ->  %s x%d" % [", ".join(parts), output.display_name, output_count]
