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
@export_range(4, 512, 1) var size_meters: int = 64:
	set(value):
		size_meters = maxi(4, value)

## Peak displacement above and below sea level, in metres.
@export_range(0.0, 100.0, 0.1) var height_scale: float = 6.0:
	set(value):
		height_scale = maxf(0.0, value)

@export var noise_seed: int = 1337

## Lower values give broader, smoother landforms.
@export_range(0.001, 0.2, 0.001) var noise_frequency: float = 0.015:
	set(value):
		noise_frequency = clampf(value, 0.001, 1.0)

@export_range(1, 8, 1) var noise_octaves: int = 4:
	set(value):
		noise_octaves = clampi(value, 1, 8)


## Points along one edge. Derived, never stored -- the mesh and the collision
## heightmap must agree, and they can only do that if one of them owns this.
func resolution() -> int:
	return size_meters + 1


## Number of height samples in the field.
func sample_count() -> int:
	return resolution() * resolution()
