class_name RecipeIngredient
extends Resource
## One line of a recipe: a kind of item and how many of it.

@export var item: ItemDefinition

@export_range(1, 999, 1) var count: int = 1


func is_valid() -> bool:
	return item != null and item.is_valid() and count > 0


func _to_string() -> String:
	return "<none>" if item == null else "%s x%d" % [item.display_name, count]
