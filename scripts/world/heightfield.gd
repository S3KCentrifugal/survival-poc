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


## Levels [param area] to [param height], easing back to the original ground
## over [param blend] metres beyond it.
##
## A building pad. Terrain noise moves several metres across a house-sized
## footprint, and a structure on unlevelled ground either floats at one corner
## or buries itself at another — and the step at its doorway is not something a
## character can walk up.
##
## The blend is what stops the pad reading as a plateau stamped into the
## hillside. Without it the edge is a cliff of exactly the relief that was
## removed, which is worse than the problem it solves.
##
## [param area] is in the tile's local space, where (0, 0) is the centre.
func flatten(area: Rect2, height: float, blend: float = 0.0) -> void:
	var half := size_meters * 0.5
	for z in resolution:
		for x in resolution:
			var local := Vector2(x - half, z - half)
			var t := _pad_falloff(local, area, blend)
			if t >= 1.0:
				continue
			var index := z * resolution + x
			_heights[index] = lerpf(height, _heights[index], t)


## How much of the original ground survives at [param point]: 0 inside the pad,
## 1 outside the blend, eased between.
func _pad_falloff(point: Vector2, area: Rect2, blend: float) -> float:
	var outside := Vector2(
		maxf(area.position.x - point.x, maxf(0.0, point.x - area.end.x)),
		maxf(area.position.y - point.y, maxf(0.0, point.y - area.end.y))
	)
	var distance := outside.length()
	if distance <= 0.0:
		return 0.0
	if blend <= 0.0 or distance >= blend:
		return 1.0
	return smoothstep(0.0, blend, distance)


## Mean height over [param area], in local coordinates. What a pad should be
## levelled to if it is to sit in the ground rather than on top of it.
func average_in(area: Rect2, step: float = 1.0) -> float:
	var total := 0.0
	var samples := 0
	var x := area.position.x
	while x <= area.end.x:
		var z := area.position.y
		while z <= area.end.y:
			total += height_at_local(x, z)
			samples += 1
			z += step
		x += step
	return 0.0 if samples == 0 else total / samples


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
