extends TestCase
## The session and the authority rule every mutating system asks.
##
## All of it runs single-player, because that is the point: the checks are in
## place and answer "yes, you decide" until a socket exists.

const MAIN_SCENE: String = "res://scenes/main.tscn"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount(node: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(node)
	_mounted.append(node)
	return node


func _mount_world() -> Node:
	return _mount(load(MAIN_SCENE).instantiate())


## The default, and what ./run.sh gives you.
func test_the_game_runs_single_player_by_default() -> void:
	var world := _mount_world()
	var session: GameSession = world.get_node_or_null("Session")
	assert_not_null(session, "the world has no session")
	assert_eq(session.mode, GameSession.Mode.SINGLE_PLAYER)
	assert_true(session.is_single_player())


## Single-player is a host with one local player, not a separate mode. Two code
## paths diverge, and every multiplayer bug then only reproduces in multiplayer.
func test_single_player_is_a_server() -> void:
	var session := GameSession.new()
	_mount(session)
	assert_true(session.is_server(), "single-player must be authoritative")
	assert_false(session.is_networked(), "single-player must not think anyone is listening")


func test_a_host_is_a_server_and_is_networked() -> void:
	var session := GameSession.new()
	_mount(session)
	session.set_mode(GameSession.Mode.HOST)
	assert_true(session.is_server())
	assert_true(session.is_networked())


func test_a_client_is_not_a_server() -> void:
	var session := GameSession.new()
	_mount(session)
	session.set_mode(GameSession.Mode.CLIENT)
	assert_false(session.is_server(), "a client must never decide what happens")
	assert_true(session.is_networked())


func test_changing_mode_is_announced_once() -> void:
	var session := GameSession.new()
	_mount(session)
	var changes := [0]
	session.mode_changed.connect(func(_mode: int) -> void: changes[0] += 1)

	session.set_mode(GameSession.Mode.HOST)
	session.set_mode(GameSession.Mode.HOST)
	assert_eq(changes[0], 1, "announced %d times for one change" % changes[0])


func test_every_mode_has_a_name() -> void:
	for mode: int in range(3):
		assert_false(GameSession.mode_name(mode as GameSession.Mode).is_empty())


func test_the_target_is_recorded_where_the_design_can_see_it() -> void:
	assert_eq(GameSession.TARGET_PLAYERS, 100)


## With no peer connected, Godot's own authority answers true everywhere. That
## is why the built-in is used rather than a scheme of our own.
func test_everything_may_be_simulated_in_single_player() -> void:
	var world := _mount_world()
	for path: String in [
		"Player/Attack", "Companion/Follow", "Wanderers", "Player/Health"
	]:
		var node := world.get_node_or_null(path)
		assert_not_null(node, "no node at %s" % path)
		assert_true(NetworkAuthority.may_simulate(node), "%s refused to simulate" % path)
		assert_true(NetworkAuthority.is_server(node), "%s did not think it was the server" % path)


## A system that refuses to run because it could not find a network is worse
## than one that runs.
func test_a_node_outside_the_tree_may_still_simulate() -> void:
	var loose := Node.new()
	_mounted.append(loose)
	assert_true(NetworkAuthority.may_simulate(loose))
	assert_true(NetworkAuthority.is_server(loose))


func test_nothing_is_networked_in_single_player() -> void:
	var world := _mount_world()
	assert_false(NetworkAuthority.is_networked(world.get_node("Player/Attack")))


func test_a_null_node_is_answered_rather_than_crashing() -> void:
	assert_true(NetworkAuthority.may_simulate(null))
	assert_true(NetworkAuthority.is_server(null))
	assert_false(NetworkAuthority.is_networked(null))


## The seam is only worth anything if the mutating systems actually ask.
func test_the_systems_that_change_the_world_ask_first() -> void:
	var asked: Array[String] = []
	for path: String in [
		"res://scripts/components/attack_component.gd",
		"res://scripts/components/wander_component.gd",
		"res://scripts/components/follow_component.gd",
		"res://scripts/components/explode_on_death.gd",
		"res://scripts/world/wanderer_spawner.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		if source.contains("NetworkAuthority."):
			asked.append(path)
	assert_eq(
		asked.size(),
		5,
		"only %d of 5 state-mutating systems ask about authority: %s" % [asked.size(), asked]
	)


## Behaviour must be unchanged in single-player -- that is what makes adding the
## checks now free.
func test_the_world_still_behaves_as_it_did() -> void:
	var world := _mount_world()
	var spawner: WandererSpawner = world.get_node("Wanderers")
	assert_eq(spawner.spawned_actors().size(), spawner.count, "the spawner stopped spawning")

	var health: HealthComponent = world.get_node("Player/Health")
	health.take_damage(10.0)
	assert_true(is_equal_approx(health.current(), 90.0), "damage stopped working")
