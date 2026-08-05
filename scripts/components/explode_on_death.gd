class_name ExplodeOnDeath
extends Node
## Blows the actor up when its health runs out, and removes it.
##
## The half of death that feature 21 deliberately left out. Still not a death
## *system* -- nothing respawns, drops loot or leaves a body -- but an actor
## that reaches zero health now visibly stops existing instead of standing
## there inert.

## Emitted just before the actor is removed, for anything that wants the last
## word: a score, a sound, a spawner that should top the world back up.
signal exploded(where: Vector3)

@export var health: HealthComponent

## What to spawn. Optional -- without one the actor still disappears, it just
## does so quietly.
@export var effect: PackedScene

## The thing that dies. Defaults to this component's owner, because the actor is
## the natural answer and making every scene say so is noise.
@export var actor: Node3D

## Where the burst appears, above the actor's feet.
@export_range(0.0, 5.0, 0.1) var effect_height: float = 0.9

## Seconds between death and removal. Zero removes on the same frame.
##
## Kept at zero by default: a corpse that lingers invites the question of what a
## corpse *is*, and that question belongs to a death system this game has not
## written.
@export_range(0.0, 10.0, 0.05) var remove_after: float = 0.0

## Set once and never cleared. Separate from [member _pending] because that one
## is cleared by the removal, and a guard that the removal switches off is a
## guard that lets the second explosion through.
var _exploded: bool = false

var _pending: bool = false
var _countdown: float = 0.0


func _ready() -> void:
	if actor == null:
		actor = owner as Node3D
	if actor == null:
		actor = get_parent() as Node3D
	if health == null:
		push_warning("ExplodeOnDeath has no health; nothing will ever set it off")
		return
	health.died.connect(explode)


func _process(delta: float) -> void:
	if not _pending:
		return
	_countdown -= delta
	if _countdown <= 0.0:
		_remove()


## Sets it off now, whatever the actor's health says.
##
## Public so a test, or a console command later, does not have to arrange a
## death to see an explosion.
func explode() -> void:
	if _exploded or actor == null:
		return
	_exploded = true
	_pending = true
	_countdown = remove_after

	var where := actor.global_position + Vector3.UP * effect_height
	# Spawned into the actor's *parent*, never the actor. A burst parented to
	# the thing being freed is freed with it and lasts zero frames.
	Explosion.burst(effect, actor.get_parent(), where)
	exploded.emit(where)

	if remove_after <= 0.0:
		_remove()


## Whether it has gone off and is waiting to be removed.
func is_exploding() -> bool:
	return _pending


## Whether it has already gone off, removal or not.
func has_exploded() -> bool:
	return _exploded


func _remove() -> void:
	if actor != null and is_instance_valid(actor):
		actor.queue_free()
	_pending = false
