class_name HumanoidRig
extends RefCounted
## Re-proportions the imported skeleton into something person-shaped.
##
## The CC0 robot is rigged as a proper humanoid -- spine chain, shoulders,
## arms, legs, twenty-five bones with Rigify names -- and every animation the
## game uses is authored against it. What it is not is human-proportioned: its
## head bone spans **26%** of the figure where a person's is about 13%, and its
## legs are **29%** where a person's are nearly half.
##
## So the bones are moved rather than replaced. Rest translations set limb
## lengths; animation tracks are rotations *relative to* those rests, so
## lengthening a thigh keeps every clip working and simply gives the character
## a longer stride. Retargeting, done the cheap way, and it is the only route
## available when there is no artist to model a new character.
##
## Only the player is re-proportioned. The wanderers, the companion and the
## merchants keep the robot exactly as it is -- partly because that is what was
## asked for, and partly because a world where the thing you control is shaped
## differently from the things you meet is a world that reads correctly.

## How much longer the legs get. The single biggest change: short legs under a
## long torso is most of what makes the original read as a toy.
const LEG_SCALE: float = 1.62

## And a slightly shorter torso to meet them, so the waist lands near the middle
## of the figure rather than two-thirds up it.
const SPINE_SCALE: float = 0.86

## Arms follow the legs a little, and the shoulders come in. The robot is built
## barrel-chested, which reads as armour rather than as a body.
const ARM_SCALE: float = 1.10
const SHOULDER_SCALE: float = 0.78

## Where the top of the head ends up, in metres, once the armature is scaled.
##
## The player's collision capsule is 1.8 m and the original model stood 1.41 m
## inside it -- so the character was visibly shorter than the thing that bumped
## into walls. This makes the two agree.
const TARGET_HEIGHT: float = 1.78

## Bones whose rest translation is scaled, and by how much.
const SCALED_BONES: Dictionary[StringName, float] = {
	&"spine.001": SPINE_SCALE,
	&"spine.002": SPINE_SCALE,
	&"spine.003": SPINE_SCALE,
	&"spine.004": SPINE_SCALE,
	&"shoulder.L": SHOULDER_SCALE,
	&"shoulder.R": SHOULDER_SCALE,
	&"upper_arm.L": ARM_SCALE,
	&"upper_arm.R": ARM_SCALE,
	&"forearm.L": ARM_SCALE,
	&"forearm.R": ARM_SCALE,
	&"shin.L": LEG_SCALE,
	&"shin.R": LEG_SCALE,
	&"foot.L": LEG_SCALE,
	&"foot.R": LEG_SCALE,
}


## Re-proportions [param skeleton] in place, then stands it on the ground.
##
## Safe to call once, on an instance. Bone rests are node state rather than a
## shared resource, so this does not reach into every other character that
## loaded the same `.glb` -- which the material cache would have done, and which
## is the trap this project has hit four times.
static func retarget(skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	for bone_name: StringName in SCALED_BONES:
		scale_bone(skeleton, bone_name, SCALED_BONES[bone_name])
	stand_on_ground(skeleton)


## Multiplies one bone's rest offset from its parent, which is what changes the
## length of the limb it starts.
static func scale_bone(skeleton: Skeleton3D, bone_name: StringName, factor: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone < 0:
		return
	var rest := skeleton.get_bone_rest(bone)
	skeleton.set_bone_rest(bone, Transform3D(rest.basis, rest.origin * factor))


## Lifts the root bone so the lowest part of the figure sits at zero.
##
## Longer legs put the feet through the floor, and a character sunk to the shin
## does not read as a bug in the rig -- it reads as the ground being at the
## wrong height, which is where somebody would then go looking.
static func stand_on_ground(skeleton: Skeleton3D) -> void:
	var root := skeleton.find_bone(&"spine")
	if root < 0:
		return
	var lowest := INF
	for bone in skeleton.get_bone_count():
		lowest = minf(lowest, skeleton.get_bone_global_rest(bone).origin.y)
	var rest := skeleton.get_bone_rest(root)
	skeleton.set_bone_rest(root, Transform3D(rest.basis, rest.origin + Vector3.UP * -lowest))


## How tall the figure is, in skeleton units, from the ground to the top of the
## head bone.
static func height_of(skeleton: Skeleton3D) -> float:
	var top := skeleton.find_bone(&"HeadTop")
	if top < 0:
		return 0.0
	return skeleton.get_bone_global_rest(top).origin.y


## Scales [param armature] so the figure stands [constant TARGET_HEIGHT] tall.
##
## Applied to the armature rather than to the skeleton, because a scaled
## [Skeleton3D] scales its own bone poses and the animations with them.
static func fit_height(armature: Node3D, skeleton: Skeleton3D) -> void:
	if armature == null:
		return
	var height := height_of(skeleton)
	if height <= 0.001:
		return
	armature.scale = Vector3.ONE * (TARGET_HEIGHT / height)


## What fraction of the figure each part takes up, for a test to hold the
## proportions to something rather than to whatever the numbers happen to give.
##
## Named after the thing a life-drawing class would measure: a person is about
## seven and a half heads tall, their legs are nearly half of them, and getting
## either badly wrong is what makes a figure read as a toy.
static func proportions(skeleton: Skeleton3D) -> Dictionary[StringName, float]:
	var height := height_of(skeleton)
	if height <= 0.001:
		return {}
	var at := func(bone_name: StringName) -> float:
		var bone := skeleton.find_bone(bone_name)
		return skeleton.get_bone_global_rest(bone).origin.y if bone >= 0 else 0.0
	return {
		&"head": (at.call(&"HeadTop") - at.call(&"Head")) / height,
		&"leg": (at.call(&"thigh.L") - at.call(&"foot.L")) / height,
		&"torso": (at.call(&"spine.004") - at.call(&"spine")) / height,
	}
