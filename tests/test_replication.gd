extends TestCase
## Smoothing 20 Hz into motion, and the pieces that carry state across.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const PLAYER_SCENE: String = "res://characters/player.tscn"

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


func _buffer(delay: float = 0.1) -> SnapshotInterpolator:
	var interpolator := SnapshotInterpolator.new(delay)
	interpolator.add(0.0, Vector3.ZERO, 0.0)
	interpolator.add(0.05, Vector3(1.0, 0.0, 0.0), 0.0)
	interpolator.add(0.10, Vector3(2.0, 0.0, 0.0), 0.0)
	interpolator.add(0.15, Vector3(3.0, 0.0, 0.0), 0.0)
	return interpolator


func test_an_empty_buffer_says_nothing() -> void:
	assert_true(SnapshotInterpolator.new(0.1).sample(1.0).is_empty())


## The whole point: a position between two snapshots rather than on one.
func test_it_interpolates_between_snapshots() -> void:
	var interpolator := _buffer(0.1)
	# Rendering 0.1s in the past, so 0.125 shows the world at 0.025 -- half way
	# between the snapshots at 0.0 and 0.05.
	var state := interpolator.sample(0.125)
	assert_true(
		absf(state["position"].x - 0.5) < 0.001, "showed %v, expected half way" % state["position"]
	)


func test_it_walks_forward_smoothly() -> void:
	var interpolator := _buffer(0.1)
	var previous := -INF
	for step in 20:
		var state := interpolator.sample(0.1 + step * 0.005)
		assert_true(state["position"].x >= previous, "the position went backwards")
		previous = state["position"].x


## A character that stops still is better than one that vanishes.
func test_running_past_the_newest_snapshot_holds_the_last_state() -> void:
	var interpolator := _buffer(0.1)
	var state := interpolator.sample(10.0)
	assert_true(is_equal_approx(state["position"].x, 3.0), "showed %v" % state["position"])


func test_before_the_oldest_snapshot_it_shows_the_oldest() -> void:
	var interpolator := _buffer(0.1)
	assert_true(is_equal_approx(interpolator.sample(0.0)["position"].x, 0.0))


## Over an unreliable channel packets overtake each other, and an out-of-order
## one would otherwise drag the character backwards.
func test_a_late_packet_is_dropped_rather_than_rewinding() -> void:
	var interpolator := _buffer(0.1)
	interpolator.add(0.07, Vector3(99.0, 0.0, 0.0), 0.0)
	assert_true(
		is_equal_approx(interpolator.sample(10.0)["position"].x, 3.0),
		"a stale packet overwrote a newer one"
	)


func test_yaw_takes_the_short_way_round() -> void:
	var interpolator := SnapshotInterpolator.new(0.0)
	interpolator.add(0.0, Vector3.ZERO, -3.0)
	interpolator.add(1.0, Vector3.ZERO, 3.0)
	# Half way across the wrap is past pi, not back through zero.
	var yaw: float = interpolator.sample(0.5)["yaw"]
	assert_true(absf(yaw) > 3.0, "interpolated the long way round, landing at %f" % yaw)


func test_old_snapshots_are_forgotten() -> void:
	var interpolator := SnapshotInterpolator.new(0.1)
	interpolator.history = 0.2
	for step in 100:
		interpolator.add(step * 0.05, Vector3(step, 0.0, 0.0), 0.0)
	assert_true(interpolator.size() < 12, "the buffer grew to %d" % interpolator.size())


## A connection that goes quiet must still have two states to work between.
func test_it_never_forgets_everything() -> void:
	var interpolator := SnapshotInterpolator.new(0.1)
	interpolator.history = 0.01
	interpolator.add(0.0, Vector3.ZERO, 0.0)
	interpolator.add(100.0, Vector3.ONE, 0.0)
	assert_true(interpolator.size() >= 2)


func test_a_player_carries_a_network_entity() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	var entity: NetworkEntity = player.get_node_or_null("Network")
	assert_not_null(entity, "a player could never be replicated")
	assert_eq(entity.kind, NetworkProtocol.EntityKind.PLAYER)
	assert_eq(entity.body, player)
	assert_false(entity.is_proxy(), "it must start as the real thing")


func test_capturing_reads_the_actor_into_plain_numbers() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	player.global_position = Vector3(5.0, 1.0, -2.0)
	player.global_rotation.y = 1.0

	var entity: NetworkEntity = player.get_node("Network")
	entity.entity_id = 42
	var state := entity.capture()
	assert_eq(state["id"], 42)
	assert_true((state["position"] as Vector3).is_equal_approx(Vector3(5.0, 1.0, -2.0)))
	assert_true(is_equal_approx(state["yaw"], 1.0))
	assert_true(is_equal_approx(state["health"], 1.0))


## A puppet that also simulates fights its own replicated position.
func test_a_proxy_stops_simulating_itself() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	var entity: NetworkEntity = player.get_node("Network")
	var movement: MovementComponent = player.get_node("Movement")

	entity.become_proxy(0.1)
	assert_true(entity.is_proxy())
	assert_false(movement.is_physics_processing(), "a puppet was still deciding where to go")
	assert_false(player.is_physics_processing(), "a puppet was still falling under gravity")


func test_a_proxy_moves_to_where_it_is_told() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	var entity: NetworkEntity = player.get_node("Network")
	entity.become_proxy(0.05)

	entity.receive({"position": Vector3(0.0, 0.0, 0.0), "yaw": 0.0}, 0.0)
	entity.receive({"position": Vector3(10.0, 0.0, 0.0), "yaw": 0.0}, 0.1)
	entity.advance_proxy(0.1)
	assert_true(player.global_position.x > 0.0, "the puppet never moved")
	assert_true(player.global_position.x < 10.0, "the puppet snapped instead of easing")


## Replaying damage on a client would fire flinches and damage numbers for blows
## that were never struck here.
func test_a_replicated_health_change_is_silent() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	var health: HealthComponent = player.get_node("Health")
	var hits := [0]
	health.damaged.connect(func(_amount: float) -> void: hits[0] += 1)

	health.set_health_fraction(0.5)
	assert_true(is_equal_approx(health.current(), 50.0))
	assert_eq(hits[0], 0, "a replicated change fired a damage reaction")


func test_the_main_scene_can_replicate() -> void:
	var world := _mount(load(MAIN_SCENE).instantiate())
	var replication: ReplicationService = world.get_node_or_null("Replication")
	assert_not_null(replication, "the world cannot replicate anything")
	assert_eq(replication.network, world.get_node("Network"))
	assert_not_null(replication.player_scene, "it could never spawn a joining player")


## In single-player there is no socket, so nothing broadcasts and nothing spawns.
func test_single_player_replicates_nothing() -> void:
	var world := _mount(load(MAIN_SCENE).instantiate())
	var replication: ReplicationService = world.get_node("Replication")
	replication._process(1.0)
	assert_eq(replication.entity_count(), 0, "single-player spawned network entities")


## Everything placed in the scene reaches the broadcast with no id. Left alone
## they all go out as entity 0, and a client folds the whole world into one
## character standing in eight places.
func test_scene_placed_entities_are_given_ids_before_they_are_sent() -> void:
	var world := _mount(load(MAIN_SCENE).instantiate())
	var replication: ReplicationService = world.get_node("Replication")

	var without_ids := 0
	for entity: NetworkEntity in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(
		ReplicationService.GROUP
	):
		if entity.entity_id == 0:
			without_ids += 1
	assert_true(without_ids > 1, "the scene should contain several unnumbered entities")

	replication.number_entities()

	var seen: Array[int] = []
	for entity: NetworkEntity in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(
		ReplicationService.GROUP
	):
		assert_ne(entity.entity_id, 0, "an entity would have been broadcast as id 0")
		assert_false(seen.has(entity.entity_id), "two entities share id %d" % entity.entity_id)
		seen.append(entity.entity_id)
