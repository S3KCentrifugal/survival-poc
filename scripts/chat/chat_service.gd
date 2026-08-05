class_name ChatService
extends Node
## Carries what people say between the box and the network.
##
## Sits between [ChatLog], which holds the lines and the rules about them, and
## [NetworkService], which moves bytes. The box below knows about neither.
##
## In single-player it still works: there is no socket, so a message goes
## straight into the log. That is not a special case bolted on -- it is the same
## path with the send skipped, which is the same shape as the rest of this
## project's networking.

## Emitted whenever a line is added, from anywhere. The box redraws on this.
signal line_added(entry: ChatLog.Entry)

@export var session: GameSession

@export var network: NetworkService

## What this player is called. A placeholder until there are accounts; the
## server rewrites it for remote messages anyway, because a name the sender
## chooses is a name the sender can lie about.
@export var player_name: String = "You"

## How many lines are kept.
@export_range(10, 500, 10) var history: int = 100

var _log: ChatLog


func _ready() -> void:
	_log = ChatLog.new(history)
	if network != null:
		network.message.connect(_on_message)
		network.peer_joined.connect(_on_peer_joined)
		network.peer_left.connect(_on_peer_left)
		network.disconnected.connect(_on_disconnected)


## The log itself, for the box to draw and a test to read.
func chat_log() -> ChatLog:
	return _log


## Says something. Returns whether anything was said.
##
## Shown locally *and* sent. Waiting for the server to echo it back would make
## your own messages appear a round trip late, which reads as the chat being
## broken on a bad connection -- exactly when you most want to be sure it sent.
func say(text: String) -> bool:
	var entry := _log.add(player_name, text)
	if entry == null:
		return false
	line_added.emit(entry)

	if _is_networked():
		network.send(NetworkProtocol.encode_chat(_local_id(), entry.text), 0, true)
	return true


## Adds a line from the game rather than from a person.
func announce(text: String) -> void:
	var entry := _log.add_system(text)
	if entry != null:
		line_added.emit(entry)


func _on_message(from: int, bytes: PackedByteArray) -> void:
	if NetworkProtocol.kind_of(bytes) != NetworkProtocol.Kind.CHAT:
		return
	var decoded := NetworkProtocol.decode_chat(bytes)
	if decoded.is_empty():
		return

	# The name comes from the peer id the packet actually arrived on, never
	# from anything inside it. A sender who picks their own display name picks
	# everyone else's too.
	var entry := _log.add(_name_for(from), decoded.get("text", ""))
	if entry == null:
		return
	line_added.emit(entry)

	# The server is the only one that has everyone, so it repeats what it hears
	# to the rest. Sending it back to the author as well would double their own
	# message on their screen, so they are excluded.
	if network != null and network.is_hosting():
		for peer: int in network.peers():
			if peer != from:
				network.send(NetworkProtocol.encode_chat(from, entry.text), peer, true)


func _on_peer_joined(peer_id: int) -> void:
	announce("%s joined." % _name_for(peer_id))


func _on_peer_left(peer_id: int) -> void:
	announce("%s left." % _name_for(peer_id))


func _on_disconnected() -> void:
	announce("Disconnected from the server.")


## A display name for a peer. Its id until there are accounts, which is honest
## about there being no names yet rather than inventing one.
func _name_for(peer_id: int) -> String:
	return "Player %d" % peer_id


## Whether there is anyone to send to. Hosting alone still counts -- a host
## with no players yet is a server, and the moment someone joins the path must
## already be the right one.
func _is_networked() -> bool:
	return network != null and (network.is_hosting() or network.is_connected_to_server())


func _local_id() -> int:
	return multiplayer.get_unique_id() if _is_networked() else 0
