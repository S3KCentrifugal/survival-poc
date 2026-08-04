class_name Structure
extends StaticBody3D
## A building: walls and floors made of boxes, with collision to match.
##
## One [StaticBody3D] for the whole thing rather than a body per wall. The
## physics server treats a single body with many shapes as one object, which is
## both cheaper and what a building actually is.
##
## Holds no layout of its own. Whoever owns it calls [method add_wall] and
## [method add_floor]; that keeps a building's shape in one readable place
## instead of spread across a scene file full of transforms.

@export var config: StructureConfig

## Boxes built so far, for tests and for anything that wants to know the shape
## of the building without walking the scene tree.
var _segments: Array[WallSegment] = []


func _ready() -> void:
	if config == null:
		push_warning("Structure has no config; falling back to defaults")
		config = StructureConfig.new()


## Adds a wall from [param from] to [param to] on the ground plane, standing on
## [param base_y], with [param openings] cut out of it.
func add_wall(
	from: Vector2, to: Vector2, base_y: float, openings: Array[WallOpening] = []
) -> void:
	_ensure_config()
	var built := WallBuilder.segments(
		from, to, openings, config.wall_height, config.wall_thickness, base_y
	)
	for segment: WallSegment in built:
		_add_box(segment, config.wall_material)
	_segments.append_array(built)


## Adds a floor slab covering [param area], with its walking surface at
## [param top_y].
func add_floor(area: Rect2, top_y: float) -> void:
	_ensure_config()
	var thickness := config.floor_thickness
	var segment := WallSegment.new(
		Vector3(area.get_center().x, top_y - thickness * 0.5, area.get_center().y),
		Vector3(area.size.x, thickness, area.size.y),
		0.0
	)
	_add_box(segment, config.floor_material)
	_segments.append_array([segment] as Array[WallSegment])


## Every box in the structure.
func segments() -> Array[WallSegment]:
	return _segments.duplicate()


## Whether anything solid occupies [param point]. Used by tests to prove a
## doorway is actually a hole rather than a differently-coloured wall.
func is_solid_at(point: Vector3) -> bool:
	for segment: WallSegment in _segments:
		var local := segment.transform().affine_inverse() * point
		var half := segment.size * 0.5
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return true
	return false


func _add_box(segment: WallSegment, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = segment.size

	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.transform = segment.transform()
	if material != null:
		visual.material_override = material
	add_child(visual)

	var shape := BoxShape3D.new()
	shape.size = segment.size

	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.transform = segment.transform()
	add_child(collider)


func _ensure_config() -> void:
	if config == null:
		config = StructureConfig.new()
