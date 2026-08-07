class_name StylisedSurface
extends Node
## Draws every mesh under a node with the shared stylised shader.
##
## Exists because the characters are an imported `.glb`. Their materials are
## whatever the exporter wrote, they are shared by every scene that instances the
## model, and hand-authoring a replacement for each one is both tedious and
## something the next re-export would silently undo. This converts them at load:
## same albedo, same texture, drawn through `shaders/stylised.gdshader`.
##
## Set as a **surface override**, not by editing the material. An imported
## material is a cached resource shared by every instance of the model -- writing
## to it would restyle every character in the game from one component, and would
## survive into the next scene that loaded the mesh. That trap has caught this
## project four times; see CLAUDE.md.
##
## Leaves [member MeshInstance3D.material_overlay] alone, which is where
## [ModelTint] paints, so a merchant is still gold.

const SHADER_PATH: String = "res://shaders/stylised.gdshader"

## Everything under here is converted. Defaults to the owner, then the parent,
## so the common case needs no wiring.
@export var model: Node3D

## Which band these surfaces belong to. The decision that makes a character
## legible against grass; see [SurfacePalette].
@export var band: SurfacePalette.Band = SurfacePalette.Band.CHARACTER


func _ready() -> void:
	if model == null:
		model = owner as Node3D
	if model == null:
		model = get_parent() as Node3D
	apply()


## Converts every surface under [member model].
##
## Public so a test can call it without waiting for a frame, and so anything
## that swaps a model at runtime can re-apply.
func apply() -> void:
	if model == null:
		return
	for mesh: MeshInstance3D in meshes(model):
		var mesh_data := mesh.mesh
		if mesh_data == null:
			continue
		for surface in mesh_data.get_surface_count():
			mesh.set_surface_override_material(surface, _material_for(mesh, surface))


## How many surfaces were converted.
##
## A component that silently converted nothing looks exactly like one that was
## never attached, which is composition's standing cost -- see CLAUDE.md.
func converted_count() -> int:
	if model == null:
		return 0
	var total := 0
	for mesh: MeshInstance3D in meshes(model):
		if mesh.mesh != null:
			total += mesh.mesh.get_surface_count()
	return total


## Every [MeshInstance3D] under [param root], including it.
##
## Walks the tree rather than being told which meshes to convert: an imported
## `.glb` has whatever node structure the exporter felt like, and a scene that
## names its children breaks the next time the art is re-exported.
static func meshes(root: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	var mesh := root as MeshInstance3D
	if mesh != null:
		found.append(mesh)
	for child: Node in root.get_children():
		found.append_array(meshes(child))
	return found


## Builds the stylised material that replaces one surface.
##
## Public and static so the conversion can be checked in the headless suite:
## everything about it except "does it look right" is a property of the material
## it produces.
static func stylised_from(source: BaseMaterial3D, band: SurfacePalette.Band) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(SHADER_PATH)

	var standard := source as StandardMaterial3D
	material.set_shader_parameter(
		&"albedo", standard.albedo_color if standard != null else Color.WHITE
	)
	var texture: Texture2D = standard.albedo_texture if standard != null else null
	material.set_shader_parameter(&"has_albedo_texture", texture != null)
	if texture != null:
		material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"roughness", standard.roughness if standard != null else 0.85)

	material.set_shader_parameter(&"band_value", SurfacePalette.value_of(band))
	material.set_shader_parameter(&"band_strength", SurfacePalette.strength_of(band))

	material.set_shader_parameter(&"ramp_softness", ArtTokens.RAMP_SOFTNESS)
	material.set_shader_parameter(&"ramp_lift", ArtTokens.RAMP_SHADOW_LIFT)

	material.set_shader_parameter(&"rim_color", ArtTokens.RIM_COLOR)
	material.set_shader_parameter(&"rim_strength", ArtTokens.RIM_STRENGTH)
	material.set_shader_parameter(&"rim_power", ArtTokens.RIM_POWER)
	return material


## The material a surface is currently drawn with, whatever it came from.
##
## The override first, then the mesh's own -- which is the order the renderer
## resolves them in, and getting it backwards would read the imported material
## after this component had already replaced it.
func _material_for(mesh: MeshInstance3D, surface: int) -> ShaderMaterial:
	var existing := mesh.get_surface_override_material(surface)
	if existing is ShaderMaterial:
		return existing as ShaderMaterial
	var source := existing as BaseMaterial3D
	if source == null and mesh.mesh != null:
		source = mesh.mesh.surface_get_material(surface) as BaseMaterial3D
	return stylised_from(source, band)
