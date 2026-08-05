class_name WandererSpawner
extends Node3D
## Puts a handful of wandering actors in the world.
##
## Placement only. What they do once they are there belongs to
## [WanderComponent]; this decides how many, where, and gives each one a home
## and a seed of its own.

## Emitted for each actor as it lands, for anything that wants to count them.
signal spawned(actor: Node3D)

@export var scene: PackedScene

## Dropped onto the surface, so they start on the ground rather than falling
## from wherever the level happens to be built.
@export var terrain: Terrain

@export_range(0, 50, 1) var count: int = 6

## Where they are scattered, in tile-local metres.
@export var area: Rect2 = Rect2(-14.0, -14.0, 28.0, 28.0)

## Kept clear, so nobody spawns inside the building the player wakes up in.
@export var avoid: Rect2 = Rect2(-8.0, -6.0, 16.0, 12.0)

## Changes the whole arrangement. Fixed rather than random so a world looks the
## same twice, which is the difference between a bug you can chase and one you
## cannot.
@export var seed_value: int = 20260804

## Metres above the ground each actor is dropped from, so it settles onto the
## surface rather than starting inside it.
const DROP_HEIGHT: float = 0.4

var _spawned: Array[Node3D] = []


func _ready() -> void:
	spawn_all()


## Places [member count] actors. Public so a test can build them without a
## frame, and so a future respawn has something to call.
func spawn_all() -> void:
	if scene == null:
		push_warning("WandererSpawner has no scene; nobody will be spawned")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in count:
		var where := _find_spot(rng)
		_spawn_one(where, index, rng.randi())


func spawned_actors() -> Array[Node3D]:
	return _spawned.duplicate()


## A point inside [member area] and outside [member avoid].
##
## Gives up after a fixed number of tries rather than looping forever: an
## `avoid` that swallows the whole `area` is a configuration mistake, and
## hanging the game is a bad way to report one.
func _find_spot(rng: RandomNumberGenerator) -> Vector2:
	for _attempt in 24:
		var point := Vector2(
			rng.randf_range(area.position.x, area.end.x),
			rng.randf_range(area.position.y, area.end.y)
		)
		if not avoid.has_point(point):
			return point
	push_warning("WandererSpawner could not find a spot outside its avoid area")
	return Vector2(area.end.x, area.end.y)


func _spawn_one(where: Vector2, index: int, actor_seed: int) -> void:
	var actor: Node3D = scene.instantiate()
	actor.name = "Wanderer%d" % (index + 1)
	add_child(actor)

	var position := Vector3(where.x, 0.0, where.y)
	if terrain != null:
		position.y = terrain.height_at_world(position) + DROP_HEIGHT
	actor.global_position = position

	var wander := actor.get_node_or_null("Wander") as WanderComponent
	if wander != null:
		# Home is where it landed, and each gets its own seed -- otherwise every
		# wanderer in the world walks the same path at the same moment.
		wander.set_home(where, actor_seed)

	# Spawned, not placed, so a tree path is not an identity for it. See the
	# rule in devblog 011.
	var save_id := actor.get_node_or_null("SaveId") as SaveIdComponent
	if save_id != null:
		save_id.id = SaveIdComponent.random_id()

	_spawned.append(actor)
	spawned.emit(actor)
