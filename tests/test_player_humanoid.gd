extends TestCase
## The player's body: a person built over the robot's rig.

const PLAYER: String = "res://characters/player.tscn"
const AI: Array[String] = [
	"res://characters/companion.tscn",
	"res://characters/wanderer.tscn",
	"res://characters/merchant.tscn",
]


func _skeleton_of(actor: Node) -> Skeleton3D:
	return actor.find_children("*", "Skeleton3D", true, false)[0]


func _humanoid(actor: Node) -> HumanoidBody:
	for node: Node in actor.find_children("*", "Node", true, false):
		if node is HumanoidBody:
			return node as HumanoidBody
	return null


func _raw_skeleton() -> Skeleton3D:
	var model: Node = mount(
		load("res://assets/characters/godot_robot/3DGodotRobot.glb").instantiate()
	)
	return _skeleton_of(model)


# --- The rig ------------------------------------------------------------------

func test_the_imported_rig_is_the_humanoid_one_the_animations_need() -> void:
	# Everything below assumes Rigify names. If a re-export renames a bone, the
	# body is built out of nothing and the failure should say so here rather
	# than as an invisible character.
	var skeleton := _raw_skeleton()
	for bone: StringName in [&"spine", &"Head", &"hand.R", &"thigh.L", &"foot.R"]:
		assert_true(skeleton.find_bone(bone) >= 0, "the rig has no %s" % bone)


## The original is two and a half heads tall with legs under a third of it,
## which is a toy. A person is about seven and a half heads with legs near half.
func test_retargeting_moves_the_proportions_toward_a_person() -> void:
	var skeleton := _raw_skeleton()
	var before := HumanoidRig.proportions(skeleton)
	HumanoidRig.retarget(skeleton)
	var after := HumanoidRig.proportions(skeleton)

	assert_true(
		after[&"leg"] > before[&"leg"],
		"legs went from %.2f to %.2f of the figure" % [before[&"leg"], after[&"leg"]]
	)
	assert_true(after[&"leg"] > 0.40, "legs are %.2f of the figure" % after[&"leg"])
	assert_true(after[&"head"] < before[&"head"], "the head did not come down")


## Longer legs put the feet through the floor, and a character sunk to the shin
## reads as the ground being wrong rather than the rig.
func test_the_retargeted_figure_stands_on_the_ground() -> void:
	var skeleton := _raw_skeleton()
	HumanoidRig.retarget(skeleton)
	var lowest := INF
	for bone in skeleton.get_bone_count():
		lowest = minf(lowest, skeleton.get_bone_global_rest(bone).origin.y)
	assert_true(absf(lowest) < 0.01, "the lowest bone sits at %f" % lowest)


func test_the_figure_is_fitted_to_the_collision_capsule() -> void:
	# The original stood 1.41 m inside an 1.8 m capsule, so the character was
	# visibly shorter than the thing that bumped into walls.
	var actor: Node = mount(load(PLAYER).instantiate())
	var skeleton := _skeleton_of(actor)
	var armature := skeleton.get_parent() as Node3D
	var height := HumanoidRig.height_of(skeleton) * armature.scale.y
	assert_true(
		absf(height - HumanoidRig.TARGET_HEIGHT) < 0.05,
		"the player stands %.2f m tall" % height
	)


# --- The body -----------------------------------------------------------------

func test_the_body_is_skinned_to_the_rig() -> void:
	var skeleton := _raw_skeleton()
	HumanoidRig.retarget(skeleton)
	var mesh := HumanoidMesh.build(skeleton)
	var arrays := mesh.surface_get_arrays(0)
	assert_true((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() > 300)
	assert_true((mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES) != 0, "no bone weights")
	assert_true((mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_COLOR) != 0, "no vertex colours")


func test_it_is_one_surface() -> void:
	# A MeshInstance3D issues a draw call per surface, and this is drawn every
	# frame the player is on screen.
	assert_eq(HumanoidMesh.build(_raw_skeleton()).get_surface_count(), 1)


## Every vertex is weighted wholly to one bone, so a joint reads as a joint.
func test_every_vertex_belongs_to_exactly_one_bone() -> void:
	var arrays := HumanoidMesh.build(_raw_skeleton()).surface_get_arrays(0)
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for index in range(0, weights.size(), 4):
		assert_eq(weights[index], 1.0)
		assert_eq(weights[index + 1], 0.0)


## The palette keeps its own value structure. Banding each colour separately
## lands skin, tunic and boots on one brightness -- the mistake the foliage
## gradient made first, and the blade tips after it.
func test_the_palette_keeps_its_range() -> void:
	var arrays := HumanoidMesh.build(_raw_skeleton()).surface_get_arrays(0)
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var darkest := 1.0
	var lightest := 0.0
	for colour: Color in colours:
		var level := SurfacePalette.linear_luminance(colour)
		darkest = minf(darkest, level)
		lightest = maxf(lightest, level)
	assert_true(lightest > darkest * 3.0, "the figure is one flat colour (%f to %f)" % [darkest, lightest])


# --- On the player -------------------------------------------------------------

func test_the_player_is_a_person() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var humanoid := _humanoid(actor)
	assert_not_null(humanoid, "the player has no HumanoidBody")
	assert_not_null(humanoid.body(), "the body was never built")


## A skinned mesh with no skeleton path renders in its bind pose and nothing
## errors. The character stood in a perfect T-pose in a field, animating
## correctly on a rig it was not attached to.
func test_the_body_is_actually_attached_to_the_skeleton() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var body := _humanoid(actor).body()
	assert_false(body.skeleton.is_empty(), "the body is attached to no skeleton")
	assert_true(body.get_node_or_null(body.skeleton) is Skeleton3D)
	assert_not_null(body.skin, "the body has no skin")


func test_the_robot_geometry_is_put_away() -> void:
	# Hidden rather than freed: it is skinned to the original rest pose, so with
	# the rig re-proportioned it would deform badly -- and it is also what every
	# other character in the game is drawn with.
	var actor: Node = mount(load(PLAYER).instantiate())
	var humanoid := _humanoid(actor)
	for mesh: MeshInstance3D in StylisedSurface.meshes(humanoid.model):
		if mesh != humanoid.body():
			assert_false(mesh.visible, "%s is still drawn over the person" % mesh.name)


## Asked for explicitly: the player becomes a person and everything else stays a
## robot. A world where the thing you control looks like the things you meet is
## a world with less information in it.
func test_the_ai_characters_are_left_as_robots() -> void:
	for path: String in AI:
		var actor: Node = mount(load(path).instantiate())
		assert_null(_humanoid(actor), "%s was turned into a person too" % path)
		var drawn := 0
		for mesh: MeshInstance3D in StylisedSurface.meshes(actor):
			drawn += 1 if mesh.visible else 0
		assert_true(drawn > 0, "%s has no visible geometry left" % path)


func test_the_player_still_animates_with_the_imported_clips() -> void:
	# The whole reason for retargeting rather than replacing: rotations are
	# relative to the rest pose, so moving a bone keeps every clip working.
	var actor: Node = mount(load(PLAYER).instantiate())
	var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
	for clip: String in ["Idle", "Run", "Attack1"]:
		assert_true(player.has_animation(clip), "the rig lost its %s clip" % clip)
