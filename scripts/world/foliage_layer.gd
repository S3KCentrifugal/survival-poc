class_name FoliageLayer
extends Resource
## One kind of thing that grows: how much of it, where, and how it is drawn.
##
## Grass, shrubs and trees are the same system with different numbers, so they
## are one resource and three `.tres` files rather than three components. The
## interesting difference between them is not code, it is density and whether
## they cast a shadow.

enum Kind {
	## Crossed blades. Thousands of them, and the reason the whole thing is
	## chunked.
	GRASS,
	## A rounded clump. Fewer, larger, and something to break a horizon with.
	SHRUB,
	## Trunk and canopy. Few enough to cast shadows.
	TREE,
}

@export var layer_name: StringName = &""

@export var kind: Kind = Kind.GRASS

@export_group("Where")
## Instances per square metre.
##
## The number that decides whether this phase fits its budget. Grass at 2 per
## square metre over a 55 m radius is about 19,000 clumps, and a clump is a
## dozen triangles -- so this multiplies out into the primitive count faster
## than anything else in the project.
@export_range(0.0, 20.0, 0.05) var density: float = 1.6

## How far from the world origin anything is scattered.
##
## Bounded rather than covering the whole 256 m tile: nothing beyond the fog is
## worth submitting, and the terrain is far larger than the part anyone plays in.
@export_range(4.0, 256.0, 1.0) var radius: float = 55.0

## Edge of one chunk, in metres.
##
## The whole reason instances are grouped at all. A single [MultiMesh] has one
## bounding box, so it is either entirely drawn or entirely culled; chunks give
## the renderer something to cull *with*, and are what keeps a shot looking away
## from the meadow from paying for it.
@export_range(4.0, 64.0, 1.0) var chunk_size: float = 16.0

## Steepest ground this will grow on, in degrees from flat.
##
## Grass on a cliff face is the tell that foliage was scattered by position
## rather than by surface.
@export_range(0.0, 90.0, 1.0) var max_slope_degrees: float = 34.0

@export_group("Look")
@export var base_color: Color = Color(0.10, 0.26, 0.09)

## The colour of the tips, blended up the blade. Lighter and yellower, because
## that is what the sun does to the top of a field and it is most of what makes
## grass read as grass rather than as green spikes.
@export var tip_color: Color = Color(0.36, 0.52, 0.16)

@export_range(0.05, 12.0, 0.05) var height_min: float = 0.28
@export_range(0.05, 12.0, 0.05) var height_max: float = 0.55

## How far the top sways, in metres.
@export_range(0.0, 2.0, 0.01) var sway: float = 0.09

@export_range(0.0, 4.0, 0.05) var sway_speed: float = 0.9

@export_group("Cost")
## Metres beyond which instances stop being drawn. 0 draws them at any distance.
##
## Godot fades them out over the last stretch, so this is not a popping edge.
@export_range(0.0, 512.0, 1.0) var visibility_range: float = 78.0

## Whether this casts into the shadow map.
##
## Off for grass, and it is not a close call. The shadow pass already draws
## three to four times the primitives the camera does, and grass is the densest
## thing in the world -- letting it cast would be the single most expensive
## decision in the project, in exchange for shadows too small to see.
@export var casts_shadow: bool = false


## Everything wrong with this layer, in English, or an empty array.
##
## A test asserts this is empty for every committed layer. A density of zero
## does not error, it just produces an empty field that looks exactly like a
## component nobody attached.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if String(layer_name).strip_edges().is_empty():
		found.append("has no name, so nothing can say which layer went wrong")
	if density <= 0.0:
		found.append("has zero density, so it grows nothing at all")
	if height_min <= 0.0 or height_max < height_min:
		found.append("has a height range of %f to %f" % [height_min, height_max])
	if chunk_size > radius * 2.0:
		found.append("has one chunk for the whole field, so nothing can be culled")
	return found


## Roughly how many instances this layer will place.
##
## For a test and for the budget: the count is the thing that decides whether a
## density is affordable, and working it out afterwards from a rendered frame is
## the expensive way to find out.
func expected_instances() -> int:
	return int(PI * radius * radius * density)
