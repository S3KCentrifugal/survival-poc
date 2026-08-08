class_name HumanoidMesh
extends RefCounted
## Builds a person-shaped body over an existing skeleton.
##
## Same argument as [FoliageMesh]: there is no artist, so the geometry is
## generated. The difference is that this is **skinned** -- every vertex is
## weighted to a bone of the rig the animations were authored against, so the
## character walks, runs, jumps and swings with the clips that already exist.
## Nothing about the animation had to be replaced to change what the player
## looks like.
##
## Built in the skeleton's own space, from [method Skeleton3D.get_bone_global_rest],
## so it fits whatever [HumanoidRig] has just done to the proportions. Change the
## rig and the body follows; there is no second copy of the measurements.
##
## Weighted rigidly -- one bone per vertex, no blending across a joint. A
## stylised low-poly figure has visible facets anyway, and rigid weights make a
## joint read as a joint rather than as a rubber hose.

## Sides on a limb. Six is enough to read as round at the size a character is
## seen, and every extra side is paid for on every instance of the mesh.
const SIDES: int = 6


## Colours, in the character value band.
##
## Three of them, because a figure needs to read as head / body / legs at a
## glance -- the same notan argument `ART.md` rule 3 makes about the character
## against the world, applied inside the character.
class Palette:
	extends RefCounted

	## A light tunic over darker legs, and it is a legibility decision rather
	## than a taste one. `FrameLook` samples a disc at chest height, which is
	## also the part of a character a player looks at -- so the torso is the one
	## surface that has to carry rule 3. A mid-tone shirt measured 1.9:1 against
	## grass; the same figure in a pale one clears the rule.
	var skin: Color = Color(0.86, 0.67, 0.52)
	var hair: Color = Color(0.36, 0.23, 0.14)
	var tunic: Color = Color(0.78, 0.84, 0.92)
	var trousers: Color = Color(0.17, 0.19, 0.27)
	var boots: Color = Color(0.22, 0.16, 0.12)
	var belt: Color = Color(0.40, 0.27, 0.15)

	## Every colour above, for working out one band scale for the whole figure.
	func all() -> Array[Color]:
		return [skin, hair, tunic, trousers, boots, belt]


## One limb: a tapered tube from [param bone] toward [param toward], weighted
## entirely to [param bone].
class Segment:
	extends RefCounted

	var bone: StringName
	var toward: StringName
	var start_radius: float
	var end_radius: float
	var colour: Color
	## Used when there is no bone to point at -- a hand, a head, a toe. Both
	## are distances along the bone's own +Y, so one bone can carry several
	## shapes stacked up it: a head is a jaw and a cranium, not a cone.
	var from_length: float
	var length: float

	func _init(
		p_bone: StringName,
		p_toward: StringName,
		p_start: float,
		p_end: float,
		p_colour: Color,
		p_length: float = 0.0,
		p_from_length: float = 0.0
	) -> void:
		bone = p_bone
		toward = p_toward
		start_radius = p_start
		end_radius = p_end
		colour = p_colour
		length = p_length
		from_length = p_from_length


## The body, as a list of tapered tubes.
##
## Radii are in skeleton units and were arrived at by rendering the thing --
## `player-close` exists for exactly this.
##
## Slimmer than the robot, which is barrel-chested and reads as armour, but not
## as slim as the first attempt. A spindly figure looks underfed and it also
## *measures* worse: `ART.md` rule 3 is about mass, so a character with less of
## it genuinely is harder to pick out of the grass. The legibility rule and the
## drawing are arguing about the same number here, which is the useful case.
static func segments(palette: Palette) -> Array[Segment]:
	return [
		Segment.new(&"spine", &"spine.001", 0.21, 0.20, palette.belt),
		Segment.new(&"spine.001", &"spine.002", 0.20, 0.22, palette.tunic),
		Segment.new(&"spine.002", &"spine.003", 0.22, 0.25, palette.tunic),
		Segment.new(&"spine.003", &"spine.004", 0.25, 0.13, palette.tunic),
		Segment.new(&"spine.004", &"Head", 0.085, 0.085, palette.skin),
		# The head is the one part not taken from a bone pair: the Head bone
		# spans a quarter of the original figure, and a head that size is the
		# single most toy-like thing about it. Two stacked shapes rather than
		# one, because a single tapered tube is a lampshade.
		Segment.new(&"Head", &"", 0.10, 0.175, palette.skin, 0.15),
		Segment.new(&"Head", &"", 0.175, 0.06, palette.hair, 0.31, 0.15),
		Segment.new(&"shoulder.L", &"upper_arm.L", 0.125, 0.10, palette.tunic),
		Segment.new(&"upper_arm.L", &"forearm.L", 0.095, 0.075, palette.tunic),
		Segment.new(&"forearm.L", &"hand.L", 0.075, 0.055, palette.skin),
		Segment.new(&"hand.L", &"", 0.065, 0.045, palette.skin, 0.11),
		Segment.new(&"shoulder.R", &"upper_arm.R", 0.125, 0.10, palette.tunic),
		Segment.new(&"upper_arm.R", &"forearm.R", 0.095, 0.075, palette.tunic),
		Segment.new(&"forearm.R", &"hand.R", 0.075, 0.055, palette.skin),
		Segment.new(&"hand.R", &"", 0.065, 0.045, palette.skin, 0.11),
		Segment.new(&"thigh.L", &"shin.L", 0.135, 0.095, palette.trousers),
		Segment.new(&"shin.L", &"foot.L", 0.095, 0.070, palette.trousers),
		Segment.new(&"foot.L", &"toe.L", 0.085, 0.06, palette.boots),
		Segment.new(&"thigh.R", &"shin.R", 0.135, 0.095, palette.trousers),
		Segment.new(&"shin.R", &"foot.R", 0.095, 0.070, palette.trousers),
		Segment.new(&"foot.R", &"toe.R", 0.085, 0.06, palette.boots),
	]


## Builds the body for [param skeleton] as it currently rests.
static func build(skeleton: Skeleton3D, palette: Palette = Palette.new()) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# One scale for the whole palette, not one per colour. Banding each colour
	# separately lands skin, tunic and boots on the same brightness -- it
	# throws away the value structure *inside* the character while fixing the
	# one outside it. Third time in this project: the foliage gradient, the
	# blade tips, and now a person.
	var scale := _band_scale(palette)

	for segment: Segment in segments(palette):
		var bone := skeleton.find_bone(segment.bone)
		if bone < 0:
			continue
		var from := skeleton.get_bone_global_rest(bone)
		var to := _end_of(skeleton, segment, from)
		if _start_of(segment, from).distance_to(to) < 0.001:
			continue
		# Linearised on the way in, which is the other half of the same lesson.
		var colour := _scaled(segment.colour.srgb_to_linear(), scale)
		_tube(
			surface,
			bone,
			_start_of(segment, from),
			to,
			segment.start_radius,
			segment.end_radius,
			colour
		)

	surface.generate_normals()
	# No generate_tangents(): the body has no UVs, because it has no texture --
	# it carries its palette in the vertex colours. Asking for tangents without
	# UVs is an error in the log and nothing in the mesh.
	return surface.commit()


## Where a segment ends: the bone it points at, or its own length along itself.
static func _end_of(skeleton: Skeleton3D, segment: Segment, from: Transform3D) -> Vector3:
	if not String(segment.toward).is_empty():
		var target := skeleton.find_bone(segment.toward)
		if target >= 0:
			return skeleton.get_bone_global_rest(target).origin
	# A bone points along its own +Y, which is the convention this rig uses and
	# the reason a hand can be given a length without knowing which way it faces.
	return from.origin + from.basis.y.normalized() * segment.length


## Where a segment starts, which is its bone unless it is stacked up one.
static func _start_of(segment: Segment, from: Transform3D) -> Vector3:
	return from.origin + from.basis.y.normalized() * segment.from_length


## A tapered tube from [param start] to [param end], every vertex weighted
## wholly to [param bone].
static func _tube(
	surface: SurfaceTool,
	bone: int,
	start: Vector3,
	end: Vector3,
	start_radius: float,
	end_radius: float,
	colour: Color
) -> void:
	var along := (end - start).normalized()
	# Any perpendicular will do; picking the world axis the limb is least
	# aligned with keeps the cross product well conditioned, which a limb
	# pointing straight up would otherwise not be.
	var seed_axis := Vector3.RIGHT if absf(along.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var across := along.cross(seed_axis).normalized()
	var other := along.cross(across).normalized()

	var bones := PackedInt32Array([bone, 0, 0, 0])
	var weights := PackedFloat32Array([1.0, 0.0, 0.0, 0.0])

	for side in SIDES:
		var a := TAU * side / SIDES
		var b := TAU * (side + 1) / SIDES
		var a_out := across * cos(a) + other * sin(a)
		var b_out := across * cos(b) + other * sin(b)

		var corners: Array[Vector3] = [
			start + a_out * start_radius,
			start + b_out * start_radius,
			end + b_out * end_radius,
			end + a_out * end_radius,
		]
		for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
			for corner: int in triangle:
				surface.set_bones(bones)
				surface.set_weights(weights)
				surface.set_color(colour)
				surface.add_vertex(corners[corner])

		# Caps, so a limb is a solid rather than an open pipe you can see into
		# from the shoulder.
		_cap(surface, bones, weights, colour, start, a_out, b_out, start_radius, -along)
		_cap(surface, bones, weights, colour, end, b_out, a_out, end_radius, along)


static func _cap(
	surface: SurfaceTool,
	bones: PackedInt32Array,
	weights: PackedFloat32Array,
	colour: Color,
	centre: Vector3,
	first: Vector3,
	second: Vector3,
	radius: float,
	_facing: Vector3
) -> void:
	if radius < 0.001:
		return
	for point: Vector3 in [centre, centre + first * radius, centre + second * radius]:
		surface.set_bones(bones)
		surface.set_weights(weights)
		surface.set_color(colour)
		surface.add_vertex(point)


## The single multiplier that moves the whole palette into the character band.
##
## Derived from the average of every colour the figure uses, so the figure as a
## mass sits where `ART.md` rule 3 wants it while skin still reads lighter than
## boots.
static func _band_scale(palette: Palette) -> float:
	var total: float = 0.0
	var brightest: float = 0.0
	var colours := palette.all()
	for colour: Color in colours:
		var linear := colour.srgb_to_linear()
		total += SurfacePalette.linear_luminance(linear)
		brightest = maxf(brightest, maxf(linear.r, maxf(linear.g, linear.b)))

	var wanted := SurfacePalette.band_scale(
		total / maxf(float(colours.size()), 1.0),
		SurfacePalette.value_of(SurfacePalette.Band.CHARACTER),
		SurfacePalette.strength_of(SurfacePalette.Band.CHARACTER)
	)
	# Capped so the brightest channel stops just short of white rather than
	# clipping past it. The band wants a 3.3x lift out of a palette of skin and
	# cloth, and past the ceiling the lift stops changing the value and starts
	# deleting the hue -- everything arrives as white.
	#
	# Tuned twice. The first cap was low enough to cancel the band entirely, at
	# which point the character rendered at its authored albedo, sat at the same
	# value as the grass, and measured 1.7:1 against a 3:1 rule. A light
	# character is not an accident of this palette; it is what rule 3 costs.
	var ceiling := 0.95 / maxf(brightest, 0.0001)
	return minf(wanted, ceiling)


static func _scaled(linear: Color, scale: float) -> Color:
	return Color(
		clampf(linear.r * scale, 0.0, 1.0),
		clampf(linear.g * scale, 0.0, 1.0),
		clampf(linear.b * scale, 0.0, 1.0),
		1.0
	)
