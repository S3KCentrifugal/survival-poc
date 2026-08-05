class_name PrototypeLevel
extends Node3D
## The prototype level: a two-room base you start inside, and a tower to walk to.
##
## The layout lives here as constants rather than in a resource. That is a
## deliberate limit of this feature: walls, openings and pads all have tested
## logic behind them, but *where the walls go* is still code. A level format is
## its own job, and inventing one to describe a single prototype building would
## be guessing at what the second building needs.
##
## Runs before [WorldRoot] places the player, because it is a child of the same
## scene and children are readied first. That ordering is what lets the player
## spawn on ground this has already levelled.

## Footprint of the base, in tile-local metres: 12 x 8, centred slightly north
## of the origin so the walk to the tower is not through the spawn point.
const BASE_AREA: Rect2 = Rect2(-6.0, -4.0, 12.0, 8.0)

## The internal wall runs north-south at x = 0, splitting the base into a start
## room to the west and a hall to the east.
const DIVIDER_X: float = 0.0

## Footprint of the outdoor structure.
const TOWER_AREA: Rect2 = Rect2(10.0, 8.0, 6.0, 6.0)

## How far past a footprint the ground is levelled, and over how many metres it
## eases back to the real terrain.
const PAD_MARGIN: float = 1.5
const PAD_BLEND: float = 5.0

## How far the finished floor stands above the levelled ground.
##
## Not zero: a slab exactly level with the terrain is two coplanar surfaces
## fighting over the same pixels. Small enough that the capsule rolls over the
## threshold instead of being stopped by it.
const FLOOR_LIP: float = 0.05

@export var terrain: Terrain

@export var structure_config: StructureConfig

## Baked once the ground is levelled and the walls are up. Optional -- without
## it the world simply has no navigation and anything that wanted a route walks
## in a straight line instead.
@export var navigation_region: NavigationRegion3D

var _ground_height: float = 0.0


func _ready() -> void:
	build()


## Levels the ground and puts the buildings on it.
##
## Public so a test can build the level without waiting on a scene.
func build() -> void:
	_ground_height = _level_the_ground()
	_build_base()
	_build_tower()
	bake_navigation()


## Bakes the navigation mesh over whatever has been built.
##
## Has to happen *after* the pads are flattened and the walls exist: a mesh
## baked over the original hillside would route companions through the walls
## and up slopes that are no longer there.
func bake_navigation() -> void:
	if navigation_region == null:
		return
	if navigation_region.navigation_mesh == null:
		push_warning("PrototypeLevel has a navigation region with no mesh to bake")
		return
	# Synchronous. Threaded baking finishes some frames later, and anything
	# spawned in between would ask an empty map for a route.
	navigation_region.bake_navigation_mesh(false)


## Height everything is built at. Zero until [method build] has run.
func ground_height() -> float:
	return _ground_height


## Whether [param point] is inside the start room -- the west half of the base.
##
## The spawn point is authored on [WorldRoot] in the scene, because that is
## where every other placement decision lives. This is how a test checks that
## the authored value still lands indoors after the layout moves.
func is_in_start_room(point: Vector2) -> bool:
	return BASE_AREA.has_point(point) and point.x < DIVIDER_X


## Flattens both footprints to a single height and hands the terrain back its
## modified field.
##
## One height for both pads on purpose. Levelling them independently leaves a
## step between the two, and the ground between them then has to be a ramp or a
## cliff — neither of which a prototype needs to be arguing about.
func _level_the_ground() -> float:
	if terrain == null:
		push_warning("PrototypeLevel has no terrain; buildings will sit at zero")
		return 0.0

	var field := terrain.field()
	if field == null:
		push_warning("PrototypeLevel ran before the terrain built itself")
		return 0.0

	var base_pad := BASE_AREA.grow(PAD_MARGIN)
	var height := field.average_in(base_pad)
	field.flatten(base_pad, height, PAD_BLEND)
	field.flatten(TOWER_AREA.grow(PAD_MARGIN), height, PAD_BLEND)
	terrain.present(field)
	return height


func _build_base() -> void:
	var base := _new_structure("Base")
	var north_west := Vector2(BASE_AREA.position.x, BASE_AREA.position.y)
	var north_east := Vector2(BASE_AREA.end.x, BASE_AREA.position.y)
	var south_east := Vector2(BASE_AREA.end.x, BASE_AREA.end.y)
	var south_west := Vector2(BASE_AREA.position.x, BASE_AREA.end.y)

	base.add_floor(BASE_AREA, _ground_height + FLOOR_LIP)
	base.add_wall(north_west, north_east, _ground_height)
	base.add_wall(north_east, south_east, _ground_height)
	# The way out, in the east half -- so leaving means crossing both rooms.
	base.add_wall(south_east, south_west, _ground_height, [_doorway(3.0)])
	base.add_wall(south_west, north_west, _ground_height)
	# The way between the two rooms.
	base.add_wall(
		Vector2(DIVIDER_X, BASE_AREA.position.y),
		Vector2(DIVIDER_X, BASE_AREA.end.y),
		_ground_height,
		[_doorway(BASE_AREA.size.y * 0.5)]
	)


func _build_tower() -> void:
	var tower := _new_structure("Tower")
	var north_west := Vector2(TOWER_AREA.position.x, TOWER_AREA.position.y)
	var north_east := Vector2(TOWER_AREA.end.x, TOWER_AREA.position.y)
	var south_east := Vector2(TOWER_AREA.end.x, TOWER_AREA.end.y)
	var south_west := Vector2(TOWER_AREA.position.x, TOWER_AREA.end.y)

	tower.add_floor(TOWER_AREA, _ground_height + FLOOR_LIP)
	# Entrance on the side facing the base, so it reads as somewhere to go.
	tower.add_wall(north_west, north_east, _ground_height, [_doorway(TOWER_AREA.size.x * 0.5)])
	tower.add_wall(north_east, south_east, _ground_height)
	tower.add_wall(south_east, south_west, _ground_height)
	tower.add_wall(south_west, north_west, _ground_height)


## A doorway centred [param centre] metres along a wall.
##
## Openings are measured from a wall's start, but every doorway here is placed
## by where its middle sits, which is how a person describes one.
func _doorway(centre: float) -> WallOpening:
	var config := _config()
	return WallOpening.new(
		centre - config.doorway_width * 0.5, config.doorway_width, config.doorway_height
	)


func _new_structure(structure_name: String) -> Structure:
	var structure := Structure.new()
	structure.name = structure_name
	structure.config = _config()
	add_child(structure)
	return structure


func _config() -> StructureConfig:
	if structure_config == null:
		push_warning("PrototypeLevel has no structure config; falling back to defaults")
		structure_config = StructureConfig.new()
	return structure_config
