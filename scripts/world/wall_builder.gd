class_name WallBuilder
extends RefCounted
## Turns a wall with holes in it into a list of solid boxes.
##
## The whole reason this is a class and not four lines inside a node: a doorway
## is a *subtraction*, and subtraction is where the off-by-one lives. A gap half
## a metre out is a door you cannot walk through or a wall with daylight under
## it, and neither is obvious from a screenshot taken from thirty metres up.
##
## Pure static functions on plain numbers, so every one of those cases can be
## stated as an assertion instead of discovered by walking into it.

## Boxes that make up the wall from [param from] to [param to], with
## [param openings] cut out of it.
##
## Coordinates are on the ground plane, as (x, z). [param base_y] is the floor
## the wall stands on, so the boxes sit *on* it rather than being centred in it.
static func segments(
	from: Vector2,
	to: Vector2,
	openings: Array[WallOpening],
	height: float,
	thickness: float,
	base_y: float = 0.0
) -> Array[WallSegment]:
	var built: Array[WallSegment] = []
	var run := to - from
	var length := run.length()
	if length <= 0.0 or height <= 0.0:
		return built

	var direction := run / length
	# A box's local X is its width, and rotating by yaw about Y sends local +X
	# to (cos, 0, -sin) -- hence the negated z.
	var yaw := atan2(-direction.y, direction.x)

	var ordered := _usable_openings(openings, length)

	# Solid stretches are the gaps between the gaps.
	var cursor := 0.0
	for opening: WallOpening in ordered:
		_append_span(built, from, direction, yaw, cursor, opening.offset, height, thickness, base_y)
		cursor = maxf(cursor, opening.far_edge())
	_append_span(built, from, direction, yaw, cursor, length, height, thickness, base_y)

	# And a lintel over anything that does not reach the top.
	for opening: WallOpening in ordered:
		if opening.height >= height:
			continue
		var span := minf(opening.far_edge(), length) - opening.offset
		var middle := opening.offset + span * 0.5
		var lintel := height - opening.height
		var point := from + direction * middle
		built.append(
			WallSegment.new(
				Vector3(point.x, base_y + opening.height + lintel * 0.5, point.y),
				Vector3(span, lintel, thickness),
				yaw
			)
		)

	return built


## Openings that actually cut this wall, clipped to it and in order.
##
## Anything off the end of the wall, inverted, or zero-width is dropped rather
## than trusted -- a negative-width gap would otherwise produce a solid span
## longer than the wall it belongs to.
static func _usable_openings(openings: Array[WallOpening], length: float) -> Array[WallOpening]:
	var usable: Array[WallOpening] = []
	for opening: WallOpening in openings:
		if opening == null or opening.width <= 0.0 or opening.height <= 0.0:
			continue
		if opening.far_edge() <= 0.0 or opening.offset >= length:
			continue
		var near := maxf(opening.offset, 0.0)
		var far := minf(opening.far_edge(), length)
		usable.append(WallOpening.new(near, far - near, opening.height))

	usable.sort_custom(func(a: WallOpening, b: WallOpening) -> bool: return a.offset < b.offset)
	return usable


## Adds one solid stretch, if it has any length at all.
##
## Zero-length spans are skipped rather than emitted: a doorway flush with the
## end of a wall would otherwise produce a box of no width, which is invisible,
## collides with nothing, and shows up in every count for the rest of time.
static func _append_span(
	into: Array[WallSegment],
	from: Vector2,
	direction: Vector2,
	yaw: float,
	start: float,
	end: float,
	height: float,
	thickness: float,
	base_y: float
) -> void:
	var span := end - start
	if span <= 0.001:
		return
	var point := from + direction * (start + span * 0.5)
	into.append(
		WallSegment.new(
			Vector3(point.x, base_y + height * 0.5, point.y),
			Vector3(span, height, thickness),
			yaw
		)
	)
