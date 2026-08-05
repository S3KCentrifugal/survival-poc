class_name NetworkAuthority
extends RefCounted
## Whether this process is allowed to simulate a thing.
##
## The question every state-mutating system has to ask before it acts, and the
## cheapest possible thing to add now: in single-player it answers yes to
## everything, so today it changes nothing. The point is that the call sites
## exist while there are twenty-five of them rather than two hundred.
##
## Built on Godot's own per-node authority rather than a scheme of our own.
## With no peer connected, [method MultiplayerAPI.get_unique_id] is 1 and a
## node's default authority is 1 -- so [method Node.is_multiplayer_authority]
## is already true everywhere, with no configuration and no special case for
## single-player. That is the whole reason to use the built-in.

## Whether [param node] may be simulated here.
##
## True when there is no multiplayer at all, which covers single-player, tests,
## and nodes that have not entered the tree yet. A system that refuses to run
## because it could not find a network is worse than one that runs.
static func may_simulate(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return true
	if not _is_connected(node.multiplayer):
		return true
	return node.is_multiplayer_authority()


## Whether this process is the one that decides -- the server, or a
## single-player session, which is the same thing.
static func is_server(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return true
	var api := node.multiplayer
	if not _is_connected(api):
		return true
	return api.is_server()


## Whether anything is actually connected. False in single-player, which is how
## presentation can tell "nobody else is watching" from "I am the host".
static func is_networked(node: Node) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	return _is_connected(node.multiplayer)


## Whether anybody is actually on the other end.
##
## Not `multiplayer_peer != null`, and not `has_multiplayer_peer()` -- Godot
## installs an [OfflineMultiplayerPeer] by default, so both of those are **true**
## in single-player and a check written either way never fires. The offline peer
## reports id 1 and `is_server() == true`, which is exactly right for the
## authority questions above and exactly wrong for this one.
static func _is_connected(api: MultiplayerAPI) -> bool:
	if api == null or api.multiplayer_peer == null:
		return false
	return not (api.multiplayer_peer is OfflineMultiplayerPeer)
