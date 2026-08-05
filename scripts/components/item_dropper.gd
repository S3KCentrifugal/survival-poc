class_name ItemDropper
extends Node
## Puts carried items back on the ground.
##
## The other half of [PickupComponent]. Kept as its own component rather than
## folded into the inventory, because "what a bag holds" and "where a thing
## lands in the world" are different questions -- one is a list, the other needs
## a body, a terrain and a direction.

## Emitted after something lands, for a sound or a network event later.
signal dropped(definition: ItemDefinition, amount: int, where: Vector3)

## Who is dropping. Items land in front of this.
@export var body: Node3D

## Where dropped items are parented. Never the actor: an item parented to a
## character moves with them, which is not what putting something down means.
## Falls back to the body's parent.
@export var container: Node

## Dropped onto the surface, so nothing lands inside a hill or hovers over one.
@export var terrain: Terrain

## How far in front of the actor things land, in metres.
##
## Just outside the collision capsule, and comfortably inside a collector's
## reach -- an item you drop and then cannot pick back up is a hole in the
## floor.
@export_range(0.3, 3.0, 0.1) var distance: float = 1.0


## Puts [param amount] of an item on the ground and returns the node, or null
## if the item has no world form.
##
## The whole stack becomes **one** pickup carrying a count, not one node per
## item: twenty mushrooms dropped as twenty nodes is a pile you have to press F
## at twenty times.
func drop(definition: ItemDefinition, amount: int = 1) -> Node3D:
	if definition == null or amount <= 0 or not definition.can_drop():
		return null
	var scene := definition.world_scene()
	var parent := _parent()
	if scene == null or parent == null:
		return null

	var item: Node3D = scene.instantiate()
	parent.add_child(item)
	item.global_position = landing_point()

	var pickup := _pickup_in(item)
	if pickup != null:
		pickup.definition = definition
		pickup.amount = amount

	# Something you put down is already there. Watching a dropped mushroom
	# sprout would read as it having been planted.
	var growth := item as MushroomGrowth
	if growth != null:
		growth.finish()

	dropped.emit(definition, amount, item.global_position)
	return item


## Where the next drop would land: in front of the actor, on the ground.
func landing_point() -> Vector3:
	if body == null:
		return Vector3.ZERO
	# A body faces its local -Z, so forward is -Z.
	var forward := -body.global_transform.basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		forward = Vector3.FORWARD
	var where := body.global_position + forward.normalized() * distance
	if terrain != null:
		where.y = terrain.height_at_world(where)
	return where


func _parent() -> Node:
	if container != null:
		return container
	return null if body == null else body.get_parent()


func _pickup_in(item: Node) -> PickupComponent:
	for child: Node in item.get_children():
		var pickup := child as PickupComponent
		if pickup != null:
			return pickup
	return null
