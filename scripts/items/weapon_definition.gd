class_name WeaponDefinition
extends Resource
## What an item does when it is held rather than carried.
##
## Separate from [ItemDefinition] on purpose. Most items are never held -- a
## mushroom, a bowl of soup, a coin -- and giving every one of them a damage
## bonus and a grip transform would put weapon data on the whole inventory. This
## points *at* an item by id instead, so a thing becomes a weapon by having one
## of these written about it.

## The item this describes, by [member ItemDefinition.id].
@export var item_id: StringName = &""

@export_group("In the hand")
## Geometry to put in the grip. Mesh only: a held weapon with a pickup on it is
## a weapon you can interact with while holding it.
@export var held_scene: PackedScene

## Where it sits in the hand, relative to the grip bone.
@export var grip_position: Vector3 = Vector3.ZERO

## Degrees, applied in Y-X-Z order. Degrees rather than a [Transform3D] because
## a hand-written basis in this project has come out transposed before, and
## because three numbers can be nudged by somebody looking at a screenshot.
@export var grip_rotation: Vector3 = Vector3.ZERO

## Compensates for the armature scale a held thing inherits from the skeleton.
@export_range(0.1, 8.0, 0.05) var grip_scale: float = 1.0

@export_group("In a fight")
@export_range(0.0, 500.0, 1.0) var damage_bonus: float = 0.0

@export_range(0.0, 500.0, 1.0) var heavy_damage_bonus: float = 0.0

## Extra reach, in metres. A sword is longer than an arm, and a weapon that
## hits no further than a fist is a weapon nobody would carry.
@export_range(0.0, 4.0, 0.05) var reach_bonus: float = 0.0


## How the held geometry is oriented in the grip.
##
## Built from Euler degrees rather than authored as a basis -- see
## [member grip_rotation].
func grip_transform() -> Transform3D:
	var basis := Basis.from_euler(
		Vector3(
			deg_to_rad(grip_rotation.x),
			deg_to_rad(grip_rotation.y),
			deg_to_rad(grip_rotation.z)
		)
	)
	return Transform3D(basis.scaled(Vector3.ONE * grip_scale), grip_position)


## Everything wrong with this weapon, in English, or an empty array.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if String(item_id).strip_edges().is_empty():
		found.append("names no item, so nothing can ever equip it")
	if held_scene == null:
		found.append("has nothing to put in the hand")
	if damage_bonus <= 0.0 and heavy_damage_bonus <= 0.0 and reach_bonus <= 0.0:
		found.append("changes nothing about a fight, so it is decoration")
	return found
