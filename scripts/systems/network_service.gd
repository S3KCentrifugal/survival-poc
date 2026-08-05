class_name NetworkService
extends Node
## Opens the socket, and moves [NetworkProtocol] bytes across it.
##
## Carries raw bytes with [method SceneMultiplayer.send_bytes], never `@rpc` or
## `MultiplayerSynchronizer`. Those encode Godot's `Variant` type system, which
## a Rust server would have to reimplement before it could read a single packet.
## What goes through here is [NetworkProtocol] -- plain integers and floats in a
## documented layout.
##
## Reading the ENet peer directly does *not* work: assigning a peer to
## `multiplayer.multiplayer_peer` hands it to [SceneMultiplayer], which drains
## every packet before anything else can see it. `send_bytes` is the supported
## side channel that sits alongside RPC traffic, and keeping the peer attached
## is what makes [method Node.is_multiplayer_authority] -- and therefore
## [NetworkAuthority] -- work at all.
##
## **This is the one file a Rust server changes.** Godot wraps `send_bytes`
## payloads in a small framing byte of its own; a Rust implementation either
## matches it or replaces this file's transport entirely. Everything above the
## transport speaks [NetworkProtocol] and does not care.
##
## Knows nothing about the game. It carries bytes and reports who arrived and
## who left; deciding what a message *means* belongs to whoever is listening.

signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

## A packet arrived. [param from] is 1 for the server.
signal message(from: int, bytes: PackedByteArray)

signal hosting_started(port: int)
signal joined_server
signal connection_failed
signal disconnected

## What a server is built to hold. The architecture is sized against this
## number; see MULTIPLAYER.md.
const MAX_PLAYERS: int = GameSession.TARGET_PLAYERS

const DEFAULT_PORT: int = 27015

@export var session: GameSession

var _peer: ENetMultiplayerPeer


## Opens a listening socket for up to [constant MAX_PLAYERS] clients.
func host(port: int = DEFAULT_PORT, max_players: int = MAX_PLAYERS) -> Error:
	stop()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, clampi(max_players, 1, MAX_PLAYERS))
	if error != OK:
		push_warning("Could not host on port %d: %s" % [port, error_string(error)])
		return error

	_adopt(peer)
	if session != null:
		session.set_mode(GameSession.Mode.HOST)
	hosting_started.emit(port)
	return OK


func join(address: String, port: int = DEFAULT_PORT) -> Error:
	stop()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port)
	if error != OK:
		push_warning("Could not reach %s:%d: %s" % [address, port, error_string(error)])
		return error

	_adopt(peer)
	if session != null:
		session.set_mode(GameSession.Mode.CLIENT)
	return OK


## Closes the socket and goes back to single-player.
##
## Back to *single-player*, not to some fourth disconnected state: a host with
## one local player is what the game already is, so there is nothing to
## unwind.
func stop() -> void:
	if _peer != null:
		_peer.close()
		_peer = null
	multiplayer.multiplayer_peer = null
	if session != null and session.mode != GameSession.Mode.SINGLE_PLAYER:
		session.set_mode(GameSession.Mode.SINGLE_PLAYER)
		disconnected.emit()


## Sends [param bytes] to one peer, or to everybody with [param to] of 0.
func send(bytes: PackedByteArray, to: int = 0, reliable: bool = false) -> void:
	if _peer == null or bytes.is_empty():
		return
	var api := multiplayer as SceneMultiplayer
	if api == null:
		return
	api.send_bytes(
		bytes,
		to,
		(
			MultiplayerPeer.TRANSFER_MODE_RELIABLE
			if reliable
			else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE
		)
	)


## Everyone currently connected. Empty in single-player.
func peers() -> PackedInt32Array:
	if _peer == null:
		return PackedInt32Array()
	return multiplayer.get_peers()


## How many players are on this server, counting the host.
func player_count() -> int:
	if _peer == null:
		return 1
	return peers().size() + 1


func is_hosting() -> bool:
	return _peer != null and multiplayer.is_server()


func is_connected_to_server() -> bool:
	return _peer != null and not multiplayer.is_server()


## Whether the server is full. Asked before accepting, not after.
func is_full() -> bool:
	return player_count() >= MAX_PLAYERS


func _adopt(peer: ENetMultiplayerPeer) -> void:
	_peer = peer
	multiplayer.multiplayer_peer = peer
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		return
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(func() -> void: joined_server.emit())
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(stop)
	var api := multiplayer as SceneMultiplayer
	if api != null:
		api.peer_packet.connect(func(from: int, bytes: PackedByteArray) -> void:
			message.emit(from, bytes))


func _on_peer_connected(peer_id: int) -> void:
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	peer_left.emit(peer_id)


func _on_connection_failed() -> void:
	stop()
	connection_failed.emit()
