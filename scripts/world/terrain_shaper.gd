class_name TerrainShaper
extends RefCounted
## Turns a position into a ground height.
##
## One layer of noise gives one kind of landscape: bumps, evenly, forever. Real
## ground is not like that -- it has flat stretches you can build on, rolling
## hills, and the occasional thing worth calling a hill. So this is four noise
## fields doing four jobs:
##
## - **Relief** decides *where* the land is interesting. Very low frequency, and
##   it weights everything else -- but never to zero, or the hills read as
##   objects dropped on a flat sheet rather than as the high end of one
##   landscape. This is the layer that makes the difference.
## - **Hills** are the broad landforms: the shape you read from a distance.
## - **Ridges** are folded noise (`1 - |n|`), which produces creases and peaks
##   where plain fractal noise produces blobs. Weighted by the relief mask, so
##   ridges only appear where the land is already high and rough.
## - **Detail** is small, everywhere, and stops the surface reading as plastic.
##
## Pure and node-free: given a config it is a function from (x, z) to a height,
## which is what lets "are there flat regions" and "are the tall parts rarer
## than the low ones" be tests rather than opinions.

var _config: TerrainConfig

var _relief: FastNoiseLite
var _hills: FastNoiseLite
var _ridges: FastNoiseLite
var _detail: FastNoiseLite


func _init(config: TerrainConfig) -> void:
	_config = config if config != null else TerrainConfig.new()
	# Each layer gets its own seed offset. Sharing one seed across four fields
	# lines their features up, and land where every feature agrees looks
	# stamped.
	_relief = _make(_config.relief_frequency, 2, _config.noise_seed + 101)
	_hills = _make(_config.hill_frequency, _config.noise_octaves, _config.noise_seed)
	_ridges = _make(_config.ridge_frequency, _config.noise_octaves, _config.noise_seed + 977)
	_detail = _make(_config.detail_frequency, 3, _config.noise_seed + 4231)


## Height at a point, in metres above sea level.
func height_at(x: float, z: float) -> float:
	var relief := relief_at(x, z)

	# Raised to a power so the hills sit low and broad with occasional height,
	# rather than spending half their time above the midpoint. Real ground is
	# mostly not a hilltop.
	var hills := _signed(_hills.get_noise_2d(x, z))
	hills = pow(hills, _config.hill_sharpness)

	var ridged := _ridged(_ridges.get_noise_2d(x, z))
	var detail := _signed(_detail.get_noise_2d(x, z))

	var shape := (
		hills * _config.hill_weight
		+ ridged * _config.ridge_weight * relief
		+ detail * _config.detail_weight
	)
	# Detail survives the relief mask at a fraction of strength, so a plain is
	# flat to walk on without being a mirror.
	var masked := lerpf(detail * _config.plains_roughness, shape, relief)
	return masked * _config.height_scale


## How interesting the land is here: 0 is a plain, 1 is as rough as this
## terrain gets.
##
## Public because it is the layer worth checking -- a map with no low values has
## nowhere to build, and one with no high values is a field.
func relief_at(x: float, z: float) -> float:
	var raw := _signed(_relief.get_noise_2d(x, z))
	# Widened around the threshold so the map commits: mostly-plain or
	# mostly-hill, rather than the whole tile hovering at half.
	var mask := smoothstep(_config.plains_extent, 1.0, raw)
	# Never all the way to zero. A mask that switches off entirely turns the
	# hills into objects sitting on a flat sheet; the floor keeps one landscape
	# with a high end and a low end.
	return lerpf(_config.relief_floor, 1.0, mask)


func _make(frequency: float, octaves: int, seed_value: int) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.seed = seed_value
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	return noise


## Noise from [-1, 1] to [0, 1].
static func _signed(value: float) -> float:
	return value * 0.5 + 0.5


## Folded noise: a crease where plain noise has a zero crossing. What turns a
## field of blobs into something with ridgelines.
static func _ridged(value: float) -> float:
	return 1.0 - absf(value)
