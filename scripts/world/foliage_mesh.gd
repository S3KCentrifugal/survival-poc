class_name FoliageMesh
extends RefCounted
## Builds the things that grow, because nobody is going to model them.
##
## The project's asset policy is procedural or CC0 with provenance, and there is
## no artist -- so grass, shrubs and trees are generated. That is a real
## constraint and it shapes the result: these are a dozen triangles each,
## coloured by a root-to-tip gradient in the vertex colours, and everything that
## makes them look like plants happens in the shader.
##
## Every mesh is built one unit tall and one unit wide, and scaled per instance
## by [FoliageScatter]. So a layer's height range is the only place a size is
## decided.
##
## [b]UV.y carries the sway weight[/b], 0 at the root and 1 at the tip. There is
## no texture, so the channel is free, and the alternative -- deriving it from
## the vertex's own height -- breaks the moment a mesh has anything at its top
## that should not move, like a trunk.

## Vertical divisions in a canopy or trunk. Low on purpose: a stylised tree is a
## silhouette, and a smoother one costs primitives in the phase that has the
## least room for them.
const RINGS: int = 5
const SIDES: int = 6


## A clump of crossed blades, for grass and shrubs.
##
## Crossed quads rather than individual blades: three quads through the middle
## of a clump read as a tuft from any angle for a twelfth of the triangles that
## modelling the blades would take, which is the whole trick.
##
## Normals point straight **up**, not out of the quad. Grass lit by its own
## facing flickers as the wind turns it and reads as a field of tiny mirrors;
## grass lit as though it were the ground it grows from sits into the terrain,
## which is both cheaper and what the reference look does.
static func blades(
	quads: int, width: float, base_color: Color, tip_color: Color, lean: float = 0.16
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for index in quads:
		var angle := PI * index / maxf(float(quads), 1.0)
		var across := Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
		# Each quad leans a little, so a clump is not a perfectly symmetrical
		# star when seen from directly above.
		var tip_offset := Vector3(cos(angle + PI * 0.5), 0.0, sin(angle + PI * 0.5)) * lean

		var root_left := -across
		var root_right := across
		var tip_left := -across * 0.25 + Vector3.UP + tip_offset
		var tip_right := across * 0.25 + Vector3.UP + tip_offset

		_quad(surface, root_left, root_right, tip_right, tip_left, base_color, tip_color)

	surface.generate_tangents()
	return surface.commit()


## A trunk with a canopy on top.
##
## Two solids in one surface rather than two surfaces: a [MultiMesh] issues a
## draw call per surface, so a two-surface tree doubles the draw calls of every
## chunk it appears in for no benefit the eye can find.
static func tree(
	trunk_color: Color, base_color: Color, tip_color: Color, trunk_height: float = 0.42
) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	# The trunk does not sway, so its UV.y stays at 0 all the way up.
	_ring_stack(
		surface,
		Vector3.ZERO,
		trunk_height,
		func(t: float) -> float: return lerpf(0.055, 0.035, t),
		trunk_color,
		trunk_color,
		func(_t: float) -> float: return 0.0
	)

	# A canopy that is widest a third of the way up and comes to a rounded point,
	# which is the shape that reads as a tree at the distance these are seen from.
	var canopy_base := Vector3.UP * trunk_height * 0.82
	_ring_stack(
		surface,
		canopy_base,
		1.0 - trunk_height * 0.82,
		func(t: float) -> float: return sin(clampf(t, 0.0, 1.0) * PI * 0.92 + 0.22) * 0.34,
		base_color,
		tip_color,
		func(t: float) -> float: return t * 0.8
	)

	surface.generate_tangents()
	return surface.commit()


## A stack of rings from [param origin] upward, radius given by [param radius_at]
## and sway weight by [param sway_at], both taking 0-to-1 up the stack.
static func _ring_stack(
	surface: SurfaceTool,
	origin: Vector3,
	height: float,
	radius_at: Callable,
	low_color: Color,
	high_color: Color,
	sway_at: Callable
) -> void:
	for level in RINGS:
		var low := float(level) / RINGS
		var high := float(level + 1) / RINGS
		var low_radius: float = radius_at.call(low)
		var high_radius: float = radius_at.call(high)
		var low_point := origin + Vector3.UP * height * low
		var high_point := origin + Vector3.UP * height * high

		for side in SIDES:
			var a := TAU * side / SIDES
			var b := TAU * (side + 1) / SIDES
			var a_out := Vector3(cos(a), 0.0, sin(a))
			var b_out := Vector3(cos(b), 0.0, sin(b))

			_face(
				surface,
				low_point + a_out * low_radius,
				low_point + b_out * low_radius,
				high_point + b_out * high_radius,
				high_point + a_out * high_radius,
				a_out,
				b_out,
				low_color.lerp(high_color, low),
				low_color.lerp(high_color, high),
				sway_at.call(low),
				sway_at.call(high)
			)


## A quad standing on its lower edge, normals up, sway rising to the top.
static func _quad(
	surface: SurfaceTool,
	root_left: Vector3,
	root_right: Vector3,
	tip_right: Vector3,
	tip_left: Vector3,
	base_color: Color,
	tip_color: Color
) -> void:
	var corners: Array[Vector3] = [root_left, root_right, tip_right, tip_left]
	var colours: Array[Color] = [base_color, base_color, tip_color, tip_color]
	var sways: Array[float] = [0.0, 0.0, 1.0, 1.0]
	# Two triangles, wound clockwise -- which is what Godot treats as
	# front-facing. The foliage shader disables culling anyway, but a mesh whose
	# winding is wrong is a mesh that cannot be reused anywhere that does not.
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		for corner: int in triangle:
			surface.set_normal(Vector3.UP)
			surface.set_color(colours[corner])
			surface.set_uv(Vector2(0.5, sways[corner]))
			surface.add_vertex(corners[corner])


## One side of a ring stack, normals pointing outward.
static func _face(
	surface: SurfaceTool,
	low_a: Vector3,
	low_b: Vector3,
	high_b: Vector3,
	high_a: Vector3,
	a_out: Vector3,
	b_out: Vector3,
	low_color: Color,
	high_color: Color,
	low_sway: float,
	high_sway: float
) -> void:
	var corners: Array[Vector3] = [low_a, low_b, high_b, high_a]
	var normals: Array[Vector3] = [a_out, b_out, b_out, a_out]
	var colours: Array[Color] = [low_color, low_color, high_color, high_color]
	var sways: Array[float] = [low_sway, low_sway, high_sway, high_sway]
	for triangle: Array in [[0, 1, 2], [0, 2, 3]]:
		for corner: int in triangle:
			surface.set_normal(normals[corner])
			surface.set_color(colours[corner])
			surface.set_uv(Vector2(0.5, sways[corner]))
			surface.add_vertex(corners[corner])


## The mesh a layer is drawn with.
##
## Colours are converted to **linear** on the way in. A vertex colour is handed
## to the shader exactly as stored and `ALBEDO` is linear, so a palette authored
## the way a colour picker shows it -- which is sRGB -- renders about twice as
## bright as it reads on the page. The first field of grass came out pale mint
## sitting on top of a dark meadow, which looks like a lighting problem and is a
## colour-space one.
static func for_layer(layer: FoliageLayer) -> ArrayMesh:
	var base := layer.base_color.srgb_to_linear()
	var tip := layer.tip_color.srgb_to_linear()

	# Banded here, once, rather than per pixel in the shader. Banding each end
	# of the gradient separately lands both on the same brightness, so the blade
	# loses the root-to-tip shading that is the only thing making it look like a
	# plant -- see SurfacePalette.band_scale.
	var scale := SurfacePalette.band_scale(
		SurfacePalette.linear_luminance(base.lerp(tip, 0.5)),
		SurfacePalette.value_of(SurfacePalette.Band.GROUND),
		SurfacePalette.strength_of(SurfacePalette.Band.GROUND)
	)
	base = _scaled(base, scale)
	tip = _scaled(tip, scale)
	match layer.kind:
		FoliageLayer.Kind.TREE:
			return tree(Color(0.20, 0.14, 0.09).srgb_to_linear(), base, tip)
		FoliageLayer.Kind.SHRUB:
			return blades(5, 0.85, base, tip, 0.24)
		_:
			return blades(3, 0.46, base, tip)


static func _scaled(linear: Color, scale: float) -> Color:
	return Color(
		clampf(linear.r * scale, 0.0, 1.0),
		clampf(linear.g * scale, 0.0, 1.0),
		clampf(linear.b * scale, 0.0, 1.0),
		linear.a
	)
