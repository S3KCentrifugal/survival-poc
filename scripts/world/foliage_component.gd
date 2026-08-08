class_name FoliageComponent
extends Node3D
## Grows the world's foliage: one [MultiMeshInstance3D] per chunk per layer.
##
## Owns none of the decisions. [FoliageScatter] says where things go and
## [FoliageMesh] says what they look like; this turns those into nodes and sets
## the two properties that decide what the field costs -- whether it casts a
## shadow, and how far away it stops being drawn.
##
## [b]Chunked because a MultiMesh has one bounding box.[/b] Twenty thousand
## clumps in a single instance are either all drawn or all culled, so a camera
## looking away from the meadow pays for it in full. Split into 16-metre chunks,
## the renderer has something to cull with, and the two close shots in the
## project draw a tenth of what the vista does.

@export var terrain: Terrain

@export var layers: Array[FoliageLayer] = []

## Rectangles nothing grows in, in the terrain's local space. The building
## footprint, and anywhere else the world has already claimed.
@export var avoid: Array[Rect2] = []

@export var seed_value: int = 20260807

const SHADER_PATH: String = "res://shaders/foliage.gdshader"

var _instances: int = 0
var _chunks: int = 0


func _ready() -> void:
	if terrain == null:
		push_warning("FoliageComponent has no terrain; nothing will grow")
		return
	grow()


## Builds every layer. Clears first, so it can be called again after the terrain
## is regenerated.
##
## Public because a tool that reseeds the world needs it, and because a test
## should not have to fake a frame to check what grew.
func grow() -> void:
	for child: Node in get_children():
		child.queue_free()
	_instances = 0
	_chunks = 0
	if terrain == null or terrain.field() == null:
		return

	for layer: FoliageLayer in layers:
		if layer == null or not layer.problems().is_empty():
			continue
		_grow_layer(layer)


## How many instances were placed, across every layer.
##
## A field that silently grew nothing looks exactly like a component nobody
## attached -- composition's standing cost, and the reason this is public.
func instance_count() -> int:
	return _instances


## How many chunks carry anything. The number that decides what can be culled.
func chunk_count() -> int:
	return _chunks


func _grow_layer(layer: FoliageLayer) -> void:
	var field := terrain.field()
	var mesh := FoliageMesh.for_layer(layer)
	mesh.surface_set_material(0, _material_for(layer))

	for area: Rect2 in FoliageScatter.chunks(layer):
		var placed := FoliageScatter.place(layer, area, seed_value, field, avoid)
		if placed.is_empty():
			# No empty nodes. An empty MultiMesh is still a bounding box the
			# renderer has to consider, and a scene full of them is a scene
			# whose chunk count says nothing about what is on screen.
			continue
		add_child(_chunk_node(layer, mesh, placed))
		_chunks += 1
		_instances += placed.size()


func _chunk_node(
	layer: FoliageLayer, mesh: ArrayMesh, placed: Array[Transform3D]
) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = placed.size()
	for index in placed.size():
		multi.set_instance_transform(index, placed[index])

	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	# Placed in the terrain's space, because that is the space the scatter works
	# in and the space the heights came from.
	node.global_transform = terrain.global_transform

	node.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if layer.casts_shadow
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)
	if layer.visibility_range > 0.0:
		node.visibility_range_end = layer.visibility_range
		node.visibility_range_end_margin = layer.visibility_range * 0.25
		# Anything that casts a shadow fades hard, because a dithered fade is
		# an alpha effect and alpha is what silently stops a material casting
		# shadows at all -- see CLAUDE.md. Grass, which casts nothing, can fade
		# smoothly and does.
		node.visibility_range_fade_mode = (
			GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
			if layer.casts_shadow
			else GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		)
	return node


## The material a layer is drawn with. Every number comes from the layer or from
## [ArtTokens]; none of them lives in the shader's defaults.
func _material_for(layer: FoliageLayer) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)
	material.set_shader_parameter(&"ramp_softness", ArtTokens.RAMP_SOFTNESS)
	material.set_shader_parameter(&"ramp_lift", ArtTokens.RAMP_SHADOW_LIFT)
	material.set_shader_parameter(&"sway", layer.sway)
	material.set_shader_parameter(&"sway_speed", layer.sway_speed)
	return material
