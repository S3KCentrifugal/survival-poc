class_name ReplicationService
extends Node
## Keeps every machine looking at the same world.
##
## The server owns the truth: it spawns a character for each player who
## connects, feeds their intent into a [RemoteInputSource], and broadcasts what
## everything is doing twenty times a second. A client owns nothing — it puts a
## puppet on screen for every entity in the snapshot and interpolates it.
##
## In single-player none of this runs. There is no socket, so there is nothing
## to broadcast and nobody to broadcast it to, and the game is exactly what it
## was before any of this existed.

## Emitted on a client when a puppet appears or leaves, for a nameplate or a
## sound later.
signal proxy_added(entity_id: int, actor: Node3D)
signal proxy_removed(entity_id: int)

## Snapshots a second. 20 is the usual choice: cheap enough for a hundred
## players, frequent enough that interpolation has something to work with.
@export_range(1.0, 60.0, 1.0) var snapshot_hz: float = 20.0

## How far behind the newest snapshot clients render, in seconds.
##
## Two snapshot intervals. One is not enough -- there has to be something on the
## far side to interpolate toward, or the buffer runs dry every frame.
@export_range(0.0, 1.0, 0.01) var interpolation_delay: float = 0.1

@export var session: GameSession
@export var network: NetworkService

## Where spawned actors are parented, on both sides.
@export var spawn_root: Node3D

## Dropped onto the ground, so nobody arrives inside a hill.
@export var terrain: Terrain

@export_group("Scenes")
@export var player_scene: PackedScene
@export var wanderer_scene: PackedScene
@export var companion_scene: PackedScene

## Where players arrive, on the ground plane.
@export var spawn_point: Vector2 = Vector2(-3.0, 0.0)

## Entity ids are handed out by the server and mean the same thing everywhere.
## Started above the peer id range so the two can never be confused in a log.
var _next_id: int = 1000

## peer id -> entity id, so a disconnect knows what to remove.
var _peer_entities: Dictionary[int, int] = {}

## peer id -> the source its intent is fed into.
var _peer_inputs: Dictionary[int, RemoteInputSource] = {}

## entity id -> actor, on whichever side is holding it.
var _entities: Dictionary[int, Node3D] = {}

var _tick: int = 0
var _since_snapshot: float = 0.0
var _clock: float = 0.0


func _ready() -> void:
	if network == null:
		return
	network.peer_joined.connect(_on_peer_joined)
	network.peer_left.connect(_on_peer_left)
	network.message.connect(_on_message)
	network.disconnected.connect(_clear_proxies)


func _process(delta: float) -> void:
	_clock += delta
	if session == null or not session.is_networked():
		return

	if session.is_server():
		_since_snapshot += delta
		var interval := 1.0 / maxf(snapshot_hz, 1.0)
		if _since_snapshot >= interval:
			_since_snapshot = 0.0
			broadcast_snapshot()
		return

	_advance_proxies()


## Sends the state of everything the server owns.
##
## Public so a test can force one rather than waiting a twentieth of a second.
func broadcast_snapshot() -> void:
	if network == null or not network.is_hosting():
		return
	_tick += 1
	number_entities()
	var entities: Array[Dictionary] = []
	for entity: NetworkEntity in get_tree().get_nodes_in_group(GROUP):
		if entity.is_proxy():
			continue
		entities.append(entity.capture())
	network.send(NetworkProtocol.encode_snapshot(_tick, entities), 0, false)


## Everything the network knows about, by id.
func entities() -> Dictionary[int, Node3D]:
	return _entities.duplicate()


func entity_count() -> int:
	return _entities.size()


## The source a peer's intent is fed into, so a test can look.
func input_for(peer_id: int) -> RemoteInputSource:
	return _peer_inputs.get(peer_id)


## Group every replicated actor joins. A group rather than a list, so an actor
## spawned by anything at all is replicated without telling this service.
const GROUP: StringName = &"network_entity"


func _on_peer_joined(peer_id: int) -> void:
	if network == null or not network.is_hosting():
		return
	if network.is_full():
		push_warning("Refusing peer %d: server is full" % peer_id)
		return

	network.send(NetworkProtocol.encode_welcome(peer_id, _tick), peer_id, true)
	var actor := _spawn(NetworkProtocol.EntityKind.PLAYER, _next_id, _spawn_position())
	if actor == null:
		return
	_next_id += 1

	# The fourth driver. Movement cannot tell this from a keyboard.
	var remote := RemoteInputSource.new()
	_peer_inputs[peer_id] = remote
	var movement := actor.get_node_or_null("Movement") as MovementComponent
	if movement != null:
		movement.input_source = remote
	var attack := actor.get_node_or_null("Attack") as AttackComponent
	if attack != null:
		attack.input_source = remote

	var entity := actor.get_node_or_null("Network") as NetworkEntity
	_peer_entities[peer_id] = entity.entity_id if entity != null else 0


func _on_peer_left(peer_id: int) -> void:
	var entity_id: int = _peer_entities.get(peer_id, 0)
	_peer_inputs.erase(peer_id)
	_peer_entities.erase(peer_id)
	if entity_id == 0:
		return
	_remove(entity_id)
	if network != null and network.is_hosting():
		network.send(NetworkProtocol.encode_despawn(entity_id), 0, true)


func _on_message(from: int, bytes: PackedByteArray) -> void:
	match NetworkProtocol.kind_of(bytes):
		NetworkProtocol.Kind.INPUT:
			var remote: RemoteInputSource = _peer_inputs.get(from)
			if remote != null:
				remote.accept(NetworkProtocol.decode_input(bytes))
		NetworkProtocol.Kind.SNAPSHOT:
			_apply_snapshot(NetworkProtocol.decode_snapshot(bytes))
		NetworkProtocol.Kind.DESPAWN:
			_remove(int(NetworkProtocol.decode_despawn(bytes).get("id", 0)))
		_:
			pass


## Puts a puppet on screen for everything in the snapshot.
func _apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or session == null or session.is_server():
		return
	for state: Dictionary in snapshot.get("entities", []):
		var entity_id := int(state.get("id", 0))
		var actor: Node3D = _entities.get(entity_id)
		if actor == null or not is_instance_valid(actor):
			# Never seen it. The kind rides on every snapshot precisely so a
			# late joiner needs no catch-up and a dropped spawn heals itself.
			actor = _spawn(
				int(state.get("kind", 0)) as NetworkProtocol.EntityKind,
				entity_id,
				state.get("position", Vector3.ZERO),
				true
			)
			if actor == null:
				continue
		var entity := actor.get_node_or_null("Network") as NetworkEntity
		if entity != null:
			entity.receive(state, _clock)


func _advance_proxies() -> void:
	for actor: Node3D in _entities.values():
		if not is_instance_valid(actor):
			continue
		var entity := actor.get_node_or_null("Network") as NetworkEntity
		if entity != null and entity.is_proxy():
			entity.advance_proxy(_clock)


func _spawn(
	kind: NetworkProtocol.EntityKind, entity_id: int, where: Vector3, as_proxy: bool = false
) -> Node3D:
	var scene := _scene_for(kind)
	if scene == null or spawn_root == null:
		return null

	var actor: Node3D = scene.instantiate()
	actor.name = "Net%d" % entity_id
	spawn_root.add_child(actor)
	actor.global_position = where

	var entity := actor.get_node_or_null("Network") as NetworkEntity
	if entity != null:
		entity.entity_id = entity_id
		if as_proxy:
			entity.become_proxy(interpolation_delay)

	_entities[entity_id] = actor
	if as_proxy:
		proxy_added.emit(entity_id, actor)
	return actor


## Gives every unnumbered entity an id.
##
## Everything placed in the scene rather than spawned by this service -- the
## host's own player, the companion, every wanderer -- arrives with no id. Left
## alone they all go out as entity 0, and a client folds the whole world into
## one character standing in eight places.
##
## Its own method rather than a branch inside the broadcast so it can be checked
## without opening a socket, which is exactly how the bug was found.
func number_entities() -> void:
	for entity: NetworkEntity in get_tree().get_nodes_in_group(GROUP):
		if not entity.is_proxy() and entity.entity_id == 0:
			_adopt_entity(entity)


## Gives a scene-placed entity an id and starts tracking it.
func _adopt_entity(entity: NetworkEntity) -> void:
	entity.entity_id = _next_id
	_next_id += 1
	var actor := entity.body as Node3D
	if actor == null:
		actor = entity.get_parent() as Node3D
	if actor != null:
		_entities[entity.entity_id] = actor


func _remove(entity_id: int) -> void:
	var actor: Node3D = _entities.get(entity_id)
	_entities.erase(entity_id)
	if actor != null and is_instance_valid(actor):
		actor.queue_free()
	proxy_removed.emit(entity_id)


## Everything a client was shown belonged to a server it is no longer talking
## to, so none of it should be left standing.
func _clear_proxies() -> void:
	for entity_id: int in _entities.keys():
		_remove(entity_id)
	_peer_entities.clear()
	_peer_inputs.clear()


func _scene_for(kind: NetworkProtocol.EntityKind) -> PackedScene:
	match kind:
		NetworkProtocol.EntityKind.WANDERER:
			return wanderer_scene
		NetworkProtocol.EntityKind.COMPANION:
			return companion_scene
		NetworkProtocol.EntityKind.PLAYER:
			return player_scene
		_:
			return null


func _spawn_position() -> Vector3:
	var where := Vector3(spawn_point.x, 0.0, spawn_point.y)
	if terrain != null:
		where.y = terrain.height_at_world(where) + 0.4
	return where
