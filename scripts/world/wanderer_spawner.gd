class_name WandererSpawner
extends Node3D
## Puts a handful of wandering actors in the world.
##
## Placement only. What they do once they are there belongs to
## [WanderComponent]; this decides how many, where, and gives each one a home
## and a seed of its own.

## Emitted for each actor as it lands, for anything that wants to count them.
signal spawned(actor: Node3D)

## Emitted when the world has been topped back up to [member count].
signal refilled

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

@export_group("Respawning")
## Whether the world tops itself back up. Off makes the population finite,
## which is a legitimate design and not this one.
@export var respawn: bool = true

## Seconds between one actor dying and the next arriving. Not instant: someone
## reappearing the moment you finished them reads as the punch not counting.
@export_range(0.0, 300.0, 0.5) var respawn_delay: float = 8.0

## Never spawns this close to the watched node. A wanderer materialising in
## front of you is worse than a world with one fewer in it for a moment.
@export_range(0.0, 100.0, 0.5) var keep_away: float = 14.0

## Usually the player. Optional -- without it, spawns can land anywhere.
@export var keep_away_from: Node3D

## Metres above the ground each actor is dropped from, so it settles onto the
## surface rather than starting inside it.
const DROP_HEIGHT: float = 0.4

var _spawned: Array[Node3D] = []

## Counts down between replacements. Fourth caller of this class now.
var _delay: Cooldown

## Kept going between spawns so replacements do not repeat the first arrangement.
var _rng: RandomNumberGenerator

## Whether a wait is already running for the current gap. Without it the delay
## only ever applied *between* replacements, so the first death was refilled on
## the spot -- a fresh cooldown is ready, not waiting.
var _waiting: bool = false


func _ready() -> void:
	spawn_all()


func _process(delta: float) -> void:
	if not respawn:
		return
	_ensure_ready()
	_delay.advance(delta)

	if missing() <= 0:
		_waiting = false
		return

	if not _waiting:
		# A gap has just appeared. Start counting from now, not from whenever
		# the last replacement happened.
		_waiting = true
		_delay.duration = respawn_delay
		_delay.clear()
		_delay.use()
		return

	if _delay.is_ready():
		_replace_one()
		_waiting = false


## Places [member count] actors. Public so a test can build them without a
## frame, and so a future respawn has something to call.
func spawn_all() -> void:
	if scene == null:
		push_warning("WandererSpawner has no scene; nobody will be spawned")
		return

	_ensure_ready()
	for index in count:
		var where := _find_spot(_rng)
		_spawn_one(where, index, _rng.randi())


## Actors still standing. Freed ones drop out on their own, which is what makes
## "how many are missing" answerable without anything reporting its own death.
func spawned_actors() -> Array[Node3D]:
	_prune()
	return _spawned.duplicate()


## How many short of [member count] the world is.
func missing() -> int:
	_prune()
	return maxi(count - _spawned.size(), 0)


## Puts one back now, ignoring the delay. Public so a test does not have to
## wait eight seconds, and so a console command could top the world up.
func replace_one() -> void:
	_replace_one()


func _replace_one() -> void:
	_ensure_ready()
	if scene == null or missing() <= 0:
		return
	var where := _find_spot(_rng)
	_spawn_one(where, _spawned.size(), _rng.randi())
	if missing() == 0:
		refilled.emit()


func _prune() -> void:
	var alive: Array[Node3D] = []
	for actor: Node3D in _spawned:
		if is_instance_valid(actor) and not actor.is_queued_for_deletion():
			alive.append(actor)
	_spawned = alive


func _ensure_ready() -> void:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = seed_value
	if _delay == null:
		_delay = Cooldown.new(respawn_delay)


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
		if avoid.has_point(point):
			continue
		if _too_close_to_watcher(point):
			continue
		return point
	push_warning("WandererSpawner could not find a spot away from the player")
	return Vector2(area.end.x, area.end.y)


## Whether [param point] is inside the exclusion around the watched node.
func _too_close_to_watcher(point: Vector2) -> bool:
	if keep_away_from == null or keep_away <= 0.0:
		return false
	if not is_instance_valid(keep_away_from) or not keep_away_from.is_inside_tree():
		return false
	var watcher := keep_away_from.global_position
	return point.distance_to(Vector2(watcher.x, watcher.z)) < keep_away


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
