class_name TerrainConfig
extends Resource
## Tuning data for a terrain tile.
##
## Everything the generator needs and nothing it does not. Edit the .tres under
## resources/terrain/ rather than these defaults.

## Edge length of the square tile, in metres.
##
## Vertex spacing is fixed at one metre (see [Heightfield]), so this also
## determines the vertex count: [code](size_meters + 1)^2[/code].
@export_range(4, 1024, 1) var size_meters: int = 64:
	set(value):
		size_meters = maxi(4, value)

## Peak displacement above and below sea level, in metres.
@export_range(0.0, 100.0, 0.1) var height_scale: float = 6.0:
	set(value):
		height_scale = maxf(0.0, value)

@export var noise_seed: int = 1337

@export_range(1, 8, 1) var noise_octaves: int = 4:
	set(value):
		noise_octaves = clampi(value, 1, 8)

@export_group("Relief")
## Frequency of the mask deciding where the land is flat and where it is not.
##
## The most important number here. Its wavelength is roughly 1/frequency
## metres, so 0.0035 gives regions a few hundred metres across -- big enough
## that a plain is somewhere you can walk around in rather than a dip between
## two hills.
@export_range(0.0005, 0.05, 0.0005) var relief_frequency: float = 0.0035

## How much of the map is plain. Higher pushes the threshold up and flattens
## more of it; 0 leaves almost nothing flat.
@export_range(0.0, 0.95, 0.01) var plains_extent: float = 0.42

## How much small detail survives on the flat parts. Not zero: ground with no
## texture at all reads as a table, not a field.
@export_range(0.0, 1.0, 0.01) var plains_roughness: float = 0.06

## How much of the hill layer survives where the mask says "plain".
##
## Not zero, and this is the number that decides whether the terrain looks
## designed or generated. At zero the mask is a switch: hills stand up out of a
## dead-flat sheet like cones dropped on a table, because there is no landform
## at all between them. A floor gives the plains gentle undulation of the same
## shape as the hills, so the hills read as the high end of one landscape rather
## than as objects placed on another.
@export_range(0.0, 1.0, 0.01) var relief_floor: float = 0.22

@export_group("Hills")
## Broad landforms -- the shape read from a distance.
@export_range(0.001, 0.2, 0.001) var hill_frequency: float = 0.006

@export_range(0.0, 2.0, 0.01) var hill_weight: float = 0.75

## Exponent on the hill layer. Above 1 the hills sit low and broad with the
## occasional height, which is what ground does; at 1 they spend half their
## time above the midpoint, which reads as corrugation.
@export_range(0.2, 5.0, 0.05) var hill_sharpness: float = 1.9

@export_group("Ridges")
## Folded noise, giving creases and peaks where plain fractal noise gives
## blobs. Only applied where the relief mask is high.
@export_range(0.001, 0.2, 0.001) var ridge_frequency: float = 0.011

@export_range(0.0, 2.0, 0.01) var ridge_weight: float = 0.42

@export_group("Detail")
## Small, everywhere. Stops the surface reading as plastic.
@export_range(0.01, 0.5, 0.005) var detail_frequency: float = 0.06

@export_range(0.0, 1.0, 0.01) var detail_weight: float = 0.05


## Points along one edge. Derived, never stored -- the mesh and the collision
## heightmap must agree, and they can only do that if one of them owns this.
func resolution() -> int:
	return size_meters + 1


## Number of height samples in the field.
func sample_count() -> int:
	return resolution() * resolution()
