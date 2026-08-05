class_name SceneRouter
extends RefCounted
## Swaps the whole world for another one.
##
## Godot's [method SceneTree.change_scene_to_file] is deferred and hands nothing
## back, so there is no moment at which the new scene exists and can be told
## something. Launching into multiplayer needs exactly that moment: build the
## world, *then* tell it to host or join. So the swap is done by hand and the
## new scene is returned.
##
## Freeing the old scene is deferred on purpose. A button handler runs inside
## the scene it is about to destroy, and freeing it from there pulls the ground
## out from under the caller.

const TITLE_SCENE: String = "res://scenes/title.tscn"
const GAME_SCENE: String = "res://scenes/main.tscn"


## Replaces the current scene with [param scene] and returns the new root.
static func swap(tree: SceneTree, scene: PackedScene) -> Node:
	if tree == null or scene == null:
		return null

	var previous := tree.current_scene
	var next := scene.instantiate()
	tree.root.add_child(next)
	tree.current_scene = next

	if previous != null and is_instance_valid(previous):
		previous.queue_free()
	return next


## Loads the game and starts whatever kind of session was asked for.
##
## Hosting and joining happen *after* the world exists, which is the whole
## reason this does the swap by hand.
static func to_game(
	tree: SceneTree,
	mode: GameSession.Mode = GameSession.Mode.SINGLE_PLAYER,
	address: String = "",
	port: int = NetworkService.DEFAULT_PORT
) -> Node:
	var world := swap(tree, load(GAME_SCENE))
	if world == null:
		return null

	# Single-player opens no socket. It is already a host with one local
	# player, so there is nothing to do.
	if mode == GameSession.Mode.SINGLE_PLAYER:
		return world

	var network := world.get_node_or_null("Network") as NetworkService
	if network == null:
		push_warning("The game scene has no network service; staying single-player")
		return world

	if mode == GameSession.Mode.HOST:
		network.host(port)
	else:
		network.join(address, port)
	return world


## Goes back to the title, closing any socket on the way out.
##
## Leaving a server is part of leaving the game: a player who returns to the
## title while still connected is a ghost standing in someone else's world.
static func to_title(tree: SceneTree) -> Node:
	if tree != null and tree.current_scene != null:
		var network := tree.current_scene.get_node_or_null("Network") as NetworkService
		if network != null:
			network.stop()
	# The game may have paused itself behind a menu, and a paused title screen
	# is one whose buttons do nothing.
	if tree != null:
		tree.paused = false
	return swap(tree, load(TITLE_SCENE))
