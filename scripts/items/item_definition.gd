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

## Shown in an inventory cell. Any size: the cell scales it to fit and keeps
## its aspect, so a 64-pixel icon and a 512-pixel one both look right.
@export var icon: Texture2D

## Used when there is no [member icon], and as the tint behind one. A coloured
## swatch is honest about art that does not exist yet where a missing-texture
## square is not.
@export var colour: Color = Color(0.8, 0.8, 0.8)

## What this becomes when it is dropped on the ground.
##
## A **path** rather than an exported [PackedScene], and that is not a style
## choice. The mushroom scene holds this resource -- its pickup has to know
## what it is -- so an exported scene here would be a cycle: the item loads the
## scene, which loads the item. Godot resolves some of those and chokes on
## others, and a load order that works by luck is not one to build on. The path
## is resolved on first use, by which point both files are loaded.
##
## Empty means the item can be carried but never put down, which is a
## legitimate thing for an item to be -- and something a UI must be able to ask
## about rather than discover by dropping it into nowhere.
@export_file("*.tscn") var world_scene_path: String = ""

## Deliberately **not** cached in a member. The scene holds this resource, so a
## strong reference from here back to the scene is a cycle between two
## RefCounteds, and GDScript never collects one -- it shows up as "resources
## still in use at exit" and nothing else. ResourceLoader keeps its own cache,
## so load() is a dictionary lookup for as long as anything else holds the
## scene, which the mushroom patch does for the life of the world.

@export_multiline var description: String = ""


## Whether the count is worth showing. A thing you can only hold one of does
## not need "1" written under it.
func stacks() -> bool:
	return max_stack > 1


## Whether it can be put back on the ground.
func can_drop() -> bool:
	return not world_scene_path.is_empty() and ResourceLoader.exists(world_scene_path)


## The scene this becomes on the ground, or null.
func world_scene() -> PackedScene:
	return load(world_scene_path) if can_drop() else null


## Whether this is a usable definition. An item with no id cannot be saved,
## networked or looked up, so it is not one.
func is_valid() -> bool:
	return not id.is_empty() and max_stack > 0
