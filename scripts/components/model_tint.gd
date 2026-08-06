class_name ModelTint
extends Node
## Colours a whole imported model without touching its materials.
##
## Set as an **overlay**, not an override. An override replaces the model's
## materials outright and turns a textured robot into a flat silhouette;
## an overlay draws on top, so the thing stays recognisably the same character
## and reads as a different one at a glance. Which is exactly what "the
## merchants should be distinct from the other wanderers" needs.
##
## Walks the tree rather than being told which meshes to paint: an imported glb
## has whatever node structure the exporter felt like, and a scene that names
## its children breaks the next time the art is re-exported.

## Painted onto every mesh under here. Defaults to this component's owner.
@export var model: Node3D

## The overlay colour. Alpha is the strength -- opaque hides the model
## underneath, which defeats the point.
@export var tint: Color = Color(1.0, 0.78, 0.25, 0.42)

## Added on top of the surface rather than mixed with it, so the tint reads in
## shadow as well as in sunlight.
@export var emission: float = 0.18


func _ready() -> void:
	if model == null:
		model = owner as Node3D
	if model == null:
		model = get_parent() as Node3D
	apply()


## Paints every mesh under [member model].
##
## Public so a test can call it without a frame, and so anything that swaps a
## model at runtime can re-apply.
func apply() -> void:
	if model == null:
		return
	var overlay := build_material(tint, emission)
	for mesh: MeshInstance3D in _meshes(model):
		mesh.material_overlay = overlay


## How many meshes were painted, so a test can check it found any at all --
## a tint that silently painted nothing looks exactly like no tint.
func painted_count() -> int:
	return 0 if model == null else _meshes(model).size()


static func build_material(colour: Color, emission_strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = emission_strength > 0.0
	material.emission = colour
	material.emission_energy_multiplier = emission_strength
	return material


static func _meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var mesh := root as MeshInstance3D
	if mesh != null:
		found.append(mesh)
	for child: Node in root.get_children():
		found.append_array(_meshes(child))
	return found
