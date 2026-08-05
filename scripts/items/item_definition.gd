class_name ItemDefinition
extends Resource
## One kind of thing that can be held.
##
## A [Resource] rather than an enum or a dictionary, because "what items exist"
## is content, not code -- adding a berry should be a new .tres, not an edit to
## a script that also decides how stacking works.

## Stable identity, used by saves, the network and anything that has to name
## this item without holding the resource. Never change one after it ships: an
## id is what a save file remembers.
@export var id: StringName = &""

@export var display_name: String = "Item"

## How many fit in one slot. One means the item does not stack.
@export_range(1, 999, 1) var max_stack: int = 20

## Stands in for an icon. There is no item art yet, and a coloured swatch is
## honest about that where a missing-texture square is not.
@export var colour: Color = Color(0.8, 0.8, 0.8)

@export_multiline var description: String = ""


## Whether this is a usable definition. An item with no id cannot be saved,
## networked or looked up, so it is not one.
func is_valid() -> bool:
	return not id.is_empty() and max_stack > 0
