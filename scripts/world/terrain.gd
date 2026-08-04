class_name Terrain
extends StaticBody3D
## Presents a [Heightfield] as a visible mesh and a collision surface.
##
## Holds no generation logic of its own -- it asks [Heightfield] for the shape
## of the ground and turns it into nodes. Rebuild by assigning a new [member
## config] and calling [method rebuild].

signal rebuilt(field: Heightfield)

@export var config: TerrainConfig

@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D

var _field: Heightfield


func _ready() -> void:
	rebuild()


## Regenerates the mesh and collision from [member config].
func rebuild() -> void:
	if config == null:
		# A terrain with no config is a mistake, but a hard crash on a missing
		# resource is worse than a visible default.
		push_warning("Terrain has no config; falling back to defaults")
		config = TerrainConfig.new()

	_field = Heightfield.generate(config)
	_mesh_instance.mesh = build_mesh(_field)
	_collision_shape.shape = build_shape(_field)
	rebuilt.emit(_field)


## The field currently on display. Null until the first [method rebuild].
func field() -> Heightfield:
	return _field


## Ground height at a world position, for anything that needs to sit on the
## surface. Returns 0.0 before the terrain has been built.
func height_at_world(world_position: Vector3) -> float:
	if _field == null:
		return 0.0
	var local := to_local(world_position)
	return _field.height_at_local(local.x, local.z) + global_position.y


## Builds a triangle mesh spanning the field, centred on the tile origin.
static func build_mesh(field: Heightfield) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	var resolution := field.resolution
	var last := float(resolution - 1)
	for z in resolution:
		for x in resolution:
			surface.set_uv(Vector2(x / last, z / last))
			surface.add_vertex(field.vertex_position(x, z))

	for z in resolution - 1:
		for x in resolution - 1:
			var origin := z * resolution + x
			# Godot treats CLOCKWISE winding as front-facing. Wound the other
			# way the ground is back-face culled and the world looks empty.
			surface.add_index(origin)
			surface.add_index(origin + 1)
			surface.add_index(origin + resolution)
			surface.add_index(origin + 1)
			surface.add_index(origin + resolution + 1)
			surface.add_index(origin + resolution)

	surface.generate_normals()
	surface.generate_tangents()
	return surface.commit()


## Builds collision matching the mesh exactly.
##
## [HeightMapShape3D] is centred on its origin and spans
## [code](map_width - 1) x (map_depth - 1)[/code] units at one unit per sample,
## which is the same span the mesh uses -- so neither needs scaling.
static func build_shape(field: Heightfield) -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	shape.map_width = field.resolution
	shape.map_depth = field.resolution
	shape.map_data = field.heights()
	return shape
