class_name WallSegment
extends RefCounted
## One solid box of wall.
##
## What [WallBuilder] produces and [Structure] turns into a mesh and a collision
## shape. Deliberately a plain box: a prototype building is boxes, and a box has
## no winding, no normals and no UV seams to get wrong.

## Centre of the box, in the structure's local space.
var center: Vector3

## Extents: x runs along the wall, y is height, z is thickness.
var size: Vector3

## Rotation about Y that points the box's local X down the wall.
var yaw: float


func _init(p_center: Vector3, p_size: Vector3, p_yaw: float) -> void:
	center = p_center
	size = p_size
	yaw = p_yaw


## Placement for a mesh or a collision shape.
##
## Built from [Basis] and a rotation rather than written out as a literal --
## a hand-authored basis is transposed as often as not.
func transform() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), center)


## Highest point of the box.
func top() -> float:
	return center.y + size.y * 0.5


## Lowest point of the box.
func bottom() -> float:
	return center.y - size.y * 0.5


func _to_string() -> String:
	return "<WallSegment at %v size %v>" % [center, size]
