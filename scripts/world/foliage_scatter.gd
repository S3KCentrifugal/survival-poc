class_name FoliageScatter
extends RefCounted
## Where things grow, worked out from the ground rather than from a list.
##
## Pure: it takes a [Heightfield] and a [FoliageLayer] and returns transforms.
## No nodes, no meshes, no renderer -- so the rules that actually matter (does
## it refuse a cliff, does it stay out of the building, is it the same field
## twice) are headless tests with numbers in them, and the component that draws
## the result has no decisions left in it.
##
## Everything is scattered per **chunk**, and each chunk is seeded from its own
## coordinates. That is what makes the field identical however it is built:
## chunk (3, -2) contains the same grass whether it was the first chunk filled
## or the fortieth, so nothing depends on iteration order and a chunk can be
## rebuilt on its own later without disturbing its neighbours.


## The chunk grid covering [param layer]'s radius, as local-space rectangles.
##
## Rounded outward to whole chunks, so the edge of the field is a chunk boundary
## rather than a ragged line -- the corners fall outside the radius and are
## rejected per-instance, which is cheaper than clipping the grid.
static func chunks(layer: FoliageLayer) -> Array[Rect2]:
	var found: Array[Rect2] = []
	if layer == null or layer.chunk_size <= 0.0:
		return found
	var reach := int(ceil(layer.radius / layer.chunk_size))
	for z in range(-reach, reach):
		for x in range(-reach, reach):
			found.append(
				Rect2(
					x * layer.chunk_size,
					z * layer.chunk_size,
					layer.chunk_size,
					layer.chunk_size
				)
			)
	return found


## Places one chunk's worth of instances, in the terrain's local space.
##
## [param exclusions] are rectangles nothing may grow in -- the building
## footprint, and anywhere else the world has already claimed. Rectangles rather
## than a callback: a [Callable] does not keep its object alive, and a scatter
## that silently stopped excluding anything would put a tree through a wall with
## no error to say so.
static func place(
	layer: FoliageLayer,
	area: Rect2,
	world_seed: int,
	field: Heightfield,
	exclusions: Array[Rect2] = []
) -> Array[Transform3D]:
	var placed: Array[Transform3D] = []
	if layer == null or field == null or layer.density <= 0.0:
		return placed

	var rng := RandomNumberGenerator.new()
	rng.seed = chunk_seed(world_seed, area.position)

	var wanted := int(round(area.get_area() * layer.density))
	for _index in wanted:
		var point := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y)
		)
		if not accepts(layer, point, field, exclusions):
			continue
		placed.append(_transform_at(layer, point, field, rng))
	return placed


## Whether anything may grow at [param point], in the terrain's local space.
##
## Separate and public because this is the half with the rules in it, and every
## one of them is a thing that looks like a bug when it is wrong: foliage on a
## cliff, foliage through a wall, foliage past the horizon.
static func accepts(
	layer: FoliageLayer, point: Vector2, field: Heightfield, exclusions: Array[Rect2]
) -> bool:
	if point.length() > layer.radius:
		return false
	if field.slope_at_local(point.x, point.y) > layer.max_slope_degrees:
		return false
	for keep_out: Rect2 in exclusions:
		if keep_out.has_point(point):
			return false
	return true


## The seed for the chunk whose corner is [param corner].
##
## Derived from the coordinates rather than counted, so a chunk is the same
## whichever order the chunks were built in -- and so one can be rebuilt alone.
## Kept positive because [member RandomNumberGenerator.seed] is unsigned and a
## negative coordinate would otherwise fold two chunks onto one seed.
static func chunk_seed(world_seed: int, corner: Vector2) -> int:
	var x := int(round(corner.x))
	var z := int(round(corner.y))
	return absi(world_seed * 73856093 + x * 19349663 + z * 83492791)


## Where one instance sits, how big it is and which way it faces.
##
## Rotated about the vertical only, never tilted to the ground normal. A blade
## of grass grows up whatever it is standing on; tilting it into the hillside is
## what makes scattered foliage read as stickers rather than as plants.
static func _transform_at(
	layer: FoliageLayer, point: Vector2, field: Heightfield, rng: RandomNumberGenerator
) -> Transform3D:
	var height := rng.randf_range(layer.height_min, layer.height_max)
	var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
		Vector3(height, height, height)
	)
	return Transform3D(
		basis, Vector3(point.x, field.height_at_local(point.x, point.y), point.y)
	)
