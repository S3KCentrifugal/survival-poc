class_name SaveIdComponent
extends Node
## Gives an object a name a save file can address it by.
##
## Nothing here writes a save. This is the half that has to be right *first*:
## an object whose identity changes between sessions cannot be reloaded into,
## and an object that shares an identity with another silently overwrites it.
##
## Attach to anything that should survive a reload -- the player, a placed
## container, a built structure -- and leave it off everything else. Objects
## without one are simply not addressable, which is the correct answer for
## scenery.
##
## Where an id comes from, in order:
##
## 1. [member id], authored in the scene. Use this for anything a human or a
##    system will refer to by name. The player is [code]player[/code].
## 2. Otherwise the node's tree path, taken once when it enters the tree. Stable
##    for a scene-placed object as long as nobody renames or reparents it, which
##    is the same condition every other path-based reference in Godot lives
##    under.
## 3. For anything spawned at runtime, neither of those is stable: assign
##    [method random_id] when you spawn it, and save the id along with the
##    object. A path is not an identity for something that did not exist when
##    the level was authored.

## Every component with an id, so a save pass can find them without anything
## having to keep a list. A group is a tag, not a lookup upwards -- this
## component still knows nothing about who reads it.
const GROUP: StringName = &"save_id"

## Prefix on generated ids, so a glance at a save file tells you which objects
## were placed and which were spawned.
const SPAWNED_PREFIX: String = "spawn:"

## The save name. Leave empty to derive one from the node's path.
@export var id: StringName = &""


func _ready() -> void:
	if id.is_empty():
		id = derive_id()
	add_to_group(GROUP)


func save_key() -> StringName:
	if id.is_empty():
		id = derive_id()
	return id


## An id from where this node sits in the tree.
##
## Readable on purpose. A hash would be shorter, but the first thing anyone does
## with an unfamiliar save file is look for something they recognise.
func derive_id() -> StringName:
	if not is_inside_tree():
		return random_id()
	return StringName(String(get_path()))


## A fresh id with no relation to anything.
##
## Sixty-four bits, which is enough that a world's worth of spawned objects will
## not collide. Godot seeds its generator at startup, so two runs do not hand
## out the same sequence.
static func random_id() -> StringName:
	return StringName("%s%08x%08x" % [SPAWNED_PREFIX, randi(), randi()])
