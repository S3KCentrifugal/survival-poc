class_name Heightfield
extends RefCounted
## A grid of terrain heights, and the sampling maths over it.
##
## Pure data -- no nodes, no rendering -- so terrain generation can be tested
## headlessly and reused by anything that needs to know the ground height
## (movement, spawning, AI) without touching the scene.
##
## Vertex spacing is fixed at one metre. [HeightMapShape3D] samples exactly one
## unit apart and offers no spacing property, so any other spacing would force a
## scaled collision shape, which also scales the heights and desynchronises
## collision from the visual mesh. Fixing the spacing keeps them identical by
## construction.

const VERTEX_SPACING: float = 1.0

## Points along one edge.
var resolution: int

## Edge length in metres. Equals [code]resolution - 1[/code] at unit spacing.
var size_meters: int

var _heights: PackedFloat32Array


func _init(p_size_meters: int, p_heights: PackedFloat32Array) -> void:
	size_meters = p_size_meters
	resolution = p_size_meters + 1
	_heights = p_heights


## Builds a field from [param config]. Deterministic for a given seed.
static func generate(config: TerrainConfig) -> Heightfield:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = config.noise_seed
	noise.frequency = config.noise_frequency
	noise.fractal_octaves = config.noise_octaves

	var resolution := config.resolution()
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)

	for z in resolution:
		for x in resolution:
			heights[z * resolution + x] = noise.get_noise_2d(x, z) * config.height_scale

	return Heightfield.new(config.size_meters, heights)


## A perfectly flat field, for tests and for a terrain that wants no relief.
static func flat(p_size_meters: int, height: float = 0.0) -> Heightfield:
	var resolution := p_size_meters + 1
	var heights := PackedFloat32Array()
	heights.resize(resolution * resolution)
	heights.fill(height)
	return Heightfield.new(p_size_meters, heights)


## Raw samples, row-major by z. Matches [member HeightMapShape3D.map_data].
func heights() -> PackedFloat32Array:
	return _heights


## Height at a grid point. Coordinates outside the field clamp to the edge
## rather than erroring -- callers sample near boundaries constantly.
func height_at_index(x: int, z: int) -> float:
	var cx := clampi(x, 0, resolution - 1)
	var cz := clampi(z, 0, resolution - 1)
	return _heights[cz * resolution + cx]


## Height at a position in the tile's local space, where (0, 0) is the centre.
##
## Bilinearly interpolated, so this is continuous across the surface rather
## than stepping between vertices.
func height_at_local(local_x: float, local_z: float) -> float:
	var half := size_meters * 0.5
	var gx := clampf(local_x + half, 0.0, float(size_meters))
	var gz := clampf(local_z + half, 0.0, float(size_meters))

	var x0 := int(floorf(gx))
	var z0 := int(floorf(gz))
	var tx := gx - x0
	var tz := gz - z0

	var top := lerpf(height_at_index(x0, z0), height_at_index(x0 + 1, z0), tx)
	var bottom := lerpf(height_at_index(x0, z0 + 1), height_at_index(x0 + 1, z0 + 1), tx)
	return lerpf(top, bottom, tz)


## Local-space position of a grid point, with the tile centred on its origin.
func vertex_position(x: int, z: int) -> Vector3:
	var half := size_meters * 0.5
	return Vector3(x - half, height_at_index(x, z), z - half)


func lowest() -> float:
	var value := INF
	for height: float in _heights:
		value = minf(value, height)
	return value


func highest() -> float:
	var value := -INF
	for height: float in _heights:
		value = maxf(value, height)
	return value
