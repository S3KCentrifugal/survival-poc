class_name HumanoidBody
extends Node
## Replaces an imported character's geometry with a person-shaped one.
##
## The player only. The wanderers, the companion and the merchants keep the
## robot, which is deliberate: the thing you control being shaped differently
## from the things you meet is information, not an inconsistency.
##
## Everything it needs already exists. [HumanoidRig] re-proportions the bones,
## [HumanoidMesh] builds a body over whatever proportions result, and the
## imported [AnimationPlayer] drives it unchanged -- rotations are relative to
## the rest pose, so lengthening a thigh gives the character a longer stride
## rather than a broken walk.

## The imported model. Defaults to the owner, then the parent, so the common
## case needs no wiring.
@export var model: Node3D

## Whether to re-proportion the skeleton as well as re-skin it.
##
## On, and it is the half that matters: a slimmer robot is still a robot with a
## head a quarter of its own height. Exported so the change can be turned off
## and looked at without it.
@export var reproportion: bool = true

var _skeleton: Skeleton3D
var _body: MeshInstance3D


func _ready() -> void:
	if model == null:
		model = owner as Node3D
	if model == null:
		model = get_parent() as Node3D
	apply()


## Builds the body. Public so a test needs no frame, and so anything that swaps
## a model at runtime can rebuild.
func apply() -> void:
	_skeleton = skeleton()
	if _skeleton == null:
		push_warning("HumanoidBody found no skeleton; the model is unchanged")
		return

	if reproportion:
		HumanoidRig.retarget(_skeleton)
		HumanoidRig.fit_height(_skeleton.get_parent() as Node3D, _skeleton)

	# Hidden rather than freed. The imported meshes are skinned to the original
	# rest pose, so with the rig re-proportioned they would deform badly -- but
	# they are also what every *other* character in the game is drawn with, and
	# freeing nodes out of an instanced scene is a way to find out that
	# something else was holding a path to them.
	for mesh: MeshInstance3D in StylisedSurface.meshes(model):
		if mesh != _body:
			mesh.visible = false

	if is_instance_valid(_body):
		_body.free()
	_body = _build()
	_skeleton.add_child(_body)


## The generated body, so a test can look at what was built.
func body() -> MeshInstance3D:
	return _body


func skeleton() -> Skeleton3D:
	if model == null:
		return null
	if model is Skeleton3D:
		return model as Skeleton3D
	var found := model.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null


func _build() -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = &"HumanoidBody"
	mesh.mesh = HumanoidMesh.build(_skeleton)
	# Bound to the rest pose the mesh was just built against, so the two cannot
	# disagree about where a bone is.
	mesh.skin = _skeleton.create_skin_from_rest_transforms()
	# Set explicitly, and it has to be. A MeshInstance3D built in the editor
	# gets `..` here for free; one built with `new()` gets an *empty* path, so
	# it is attached to no skeleton at all -- and a skinned mesh with no
	# skeleton renders in its bind pose, silently. The character stood in a
	# perfect T-pose in the middle of a field and nothing anywhere errored.
	mesh.skeleton = NodePath("..")
	# A surface *override* rather than a material on the mesh, so
	# StylisedSurface sees a ShaderMaterial already there and leaves it alone --
	# otherwise it would helpfully replace the one carrying the vertex colours.
	mesh.set_surface_override_material(0, _material())
	return mesh


## The shared stylised shader, told to read the palette out of the vertices.
##
## Band strength is zero because [HumanoidMesh] already banded the colours when
## it built them: banding a whole palette per pixel would land skin, tunic and
## boots on one brightness, which is the mistake foliage made first.
func _material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(StylisedSurface.SHADER_PATH)
	material.set_shader_parameter(&"albedo", Color.WHITE)
	material.set_shader_parameter(&"has_albedo_texture", false)
	material.set_shader_parameter(&"use_vertex_color", true)
	material.set_shader_parameter(&"band_strength", 0.0)
	material.set_shader_parameter(&"roughness", 0.85)
	material.set_shader_parameter(&"ramp_softness", ArtTokens.RAMP_SOFTNESS)
	material.set_shader_parameter(&"ramp_lift", ArtTokens.RAMP_SHADOW_LIFT)
	material.set_shader_parameter(&"rim_color", ArtTokens.RIM_COLOR)
	material.set_shader_parameter(&"rim_strength", ArtTokens.RIM_STRENGTH)
	material.set_shader_parameter(&"rim_power", ArtTokens.RIM_POWER)
	return material
