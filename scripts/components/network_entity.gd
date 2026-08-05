class_name NetworkEntity
extends Node
## Makes an actor something the network can talk about.
##
## Two jobs, one on each side of the wire. On the server it reads the actor's
## state into the plain numbers a snapshot carries. On a client it is a
## **proxy**: the actor is a puppet whose position arrives from elsewhere, so
## everything that would simulate it locally is switched off and the replicated
## state is interpolated onto it instead.
##
## Deliberately the only thing that knows an actor can be either.

## What to spawn on a client that has never seen this entity before.
@export var kind: NetworkProtocol.EntityKind = NetworkProtocol.EntityKind.PLAYER

## The body whose transform is replicated. Assign in the scene.
@export var body: CharacterBody3D

@export var health: HealthComponent
@export var movement: MovementComponent
@export var animation: AnimationComponent

## Components switched off on a proxy: anything that would decide where this
## actor goes. A puppet that also simulates fights its own replicated position.
@export var simulated: Array[Node] = []

## Assigned by the server; the same number on every machine.
var entity_id: int = 0

func _ready() -> void:
	add_to_group(ReplicationService.GROUP)


var _proxy: bool = false
var _interpolator: SnapshotInterpolator


## Whether this is a puppet driven from elsewhere rather than the real thing.
func is_proxy() -> bool:
	return _proxy


## Turns the actor into a puppet.
##
## One-way on purpose. A thing that has been a proxy has no simulation state
## worth resuming, so promoting one back would be inventing history.
func become_proxy(interpolation_delay: float = 0.1) -> void:
	_proxy = true
	_interpolator = SnapshotInterpolator.new(interpolation_delay)
	for node: Node in simulated:
		if node != null:
			node.set_process(false)
			node.set_physics_process(false)
	if body != null:
		# Physics would fight the replicated position, and a puppet has no
		# business falling under its own gravity.
		body.set_physics_process(false)
		body.velocity = Vector3.ZERO


## The actor's state, as the numbers a snapshot carries.
func capture() -> Dictionary:
	var position := Vector3.ZERO
	var yaw := 0.0
	if body != null:
		position = body.global_position
		yaw = body.global_rotation.y
	return {
		"id": entity_id,
		"kind": int(kind),
		"position": position,
		"yaw": yaw,
		"flags": _flags(),
		"health": 1.0 if health == null else health.fraction(),
	}


## Records a state that arrived, to be interpolated toward.
func receive(state: Dictionary, at_time: float) -> void:
	if not _proxy or _interpolator == null:
		return
	_interpolator.add(at_time, state.get("position", Vector3.ZERO), float(state.get("yaw", 0.0)))
	if health != null:
		var fraction := float(state.get("health", 1.0))
		health.set_health_fraction(fraction)


## Moves the puppet to where it should be at [param now].
func advance_proxy(now: float) -> void:
	if not _proxy or _interpolator == null or body == null:
		return
	var state := _interpolator.sample(now)
	if state.is_empty():
		return
	body.global_position = state["position"]
	body.global_rotation.y = state["yaw"]


func interpolator() -> SnapshotInterpolator:
	return _interpolator


func _flags() -> int:
	var flags := 0
	if body != null and body.is_on_floor():
		flags |= NetworkProtocol.FLAG_ON_FLOOR
	if movement != null and movement.is_sprinting():
		flags |= NetworkProtocol.FLAG_SPRINTING
	if animation != null:
		var state := animation.state_name()
		if state == &"punch":
			flags |= NetworkProtocol.FLAG_ATTACKING
		elif state == &"hurt":
			flags |= NetworkProtocol.FLAG_HURT
	if health != null and not health.is_alive():
		flags |= NetworkProtocol.FLAG_DEAD
	return flags
