extends TestCase
## The companion as assembled, and the navigation it walks on.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const COMPANION_SCENE: String = "res://characters/companion.tscn"
const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount_world() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node = load(MAIN_SCENE).instantiate()
	tree.root.add_child(world)
	_mounted.append(world)
	return world


## A companion and something to follow, off on their own.
func _pair() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	var companion: CharacterBody3D = load(COMPANION_SCENE).instantiate()
	var leader := Node3D.new()
	tree.root.add_child(companion)
	tree.root.add_child(leader)
	_mounted.append(companion)
	_mounted.append(leader)

	var follow: FollowComponent = companion.get_node("Follow")
	follow.target = leader
	return [companion, leader, follow]


func test_the_scene_is_assembled() -> void:
	var companion: CharacterBody3D = load(COMPANION_SCENE).instantiate()
	_mounted.append(companion)
	for child: String in ["CollisionShape3D", "Model", "Agent", "Movement", "Follow", "Animation"]:
		assert_not_null(companion.get_node_or_null(child), "no %s" % child)


## The same claim as the wanderers: it runs the player's movement code.
func test_it_drives_the_same_movement_component_the_player_uses() -> void:
	var parts := _pair()
	var movement: MovementComponent = (parts[0] as Node).get_node("Movement")
	assert_not_null(movement.input_source, "nothing is telling it where to go")
	assert_true(movement.input_source is InputSource)


func test_the_main_scene_has_one_following_the_player() -> void:
	var world := _mount_world()
	var companion: CharacterBody3D = world.get_node_or_null("Companion")
	assert_not_null(companion, "there is no friend in the world")
	var follow: FollowComponent = companion.get_node("Follow")
	assert_eq(follow.target, world.get_node("Player"), "it is not following the player")


func test_it_spawns_beside_the_player_rather_than_inside_them() -> void:
	var world := _mount_world()
	var apart := (
		(world.get_node("Companion") as Node3D).global_position
		.distance_to((world.get_node("Player") as Node3D).global_position)
	)
	assert_true(apart > 0.8, "the companion spawned %.2f m from the player" % apart)
	assert_true(apart < 6.0, "the companion spawned %.2f m away, which is not beside" % apart)


func test_it_stands_still_while_you_are_next_to_it() -> void:
	var parts := _pair()
	var companion: CharacterBody3D = parts[0]
	var leader: Node3D = parts[1]
	var follow: FollowComponent = parts[2]

	companion.global_position = Vector3.ZERO
	leader.global_position = Vector3(1.0, 0.0, 0.0)
	for _frame in 120:
		follow.step(STEP)
	assert_false(follow.input_source().poll().is_moving(), "it shuffled about beside you")


func test_it_sets_off_after_you_walk_away() -> void:
	var parts := _pair()
	var companion: CharacterBody3D = parts[0]
	var leader: Node3D = parts[1]
	var follow: FollowComponent = parts[2]

	companion.global_position = Vector3.ZERO
	leader.global_position = Vector3(20.0, 0.0, 0.0)

	assert_false(follow.input_source().poll().is_moving(), "it set off on the same frame")
	for _frame in 120:
		follow.step(STEP)
	assert_true(follow.input_source().poll().is_moving(), "it never set off")


func test_it_walks_toward_you() -> void:
	var parts := _pair()
	var companion: CharacterBody3D = parts[0]
	var leader: Node3D = parts[1]
	var follow: FollowComponent = parts[2]

	companion.global_position = Vector3.ZERO
	leader.global_position = Vector3(20.0, 0.0, 0.0)
	for _frame in 120:
		follow.step(STEP)

	var wanted := follow.input_source().poll().move
	assert_true(wanted.x > 0.7, "walking %v when you are due east" % wanted)


func test_it_sprints_to_close_a_big_gap() -> void:
	var parts := _pair()
	var companion: CharacterBody3D = parts[0]
	var leader: Node3D = parts[1]
	var follow: FollowComponent = parts[2]

	companion.global_position = Vector3.ZERO
	leader.global_position = Vector3(30.0, 0.0, 0.0)
	for _frame in 120:
		follow.step(STEP)
	assert_true(follow.input_source().poll().sprint, "it strolled after you from thirty metres")


func test_it_stops_sprinting_once_it_is_close() -> void:
	var parts := _pair()
	var companion: CharacterBody3D = parts[0]
	var leader: Node3D = parts[1]
	var follow: FollowComponent = parts[2]

	companion.global_position = Vector3.ZERO
	leader.global_position = Vector3(5.0, 0.0, 0.0)
	for _frame in 120:
		follow.step(STEP)
	assert_false(follow.input_source().poll().sprint)


func test_a_reeling_companion_stands_still() -> void:
	var parts := _pair()
	var companion: CharacterBody3D = parts[0]
	var leader: Node3D = parts[1]
	var follow: FollowComponent = parts[2]

	companion.global_position = Vector3.ZERO
	leader.global_position = Vector3(20.0, 0.0, 0.0)
	for _frame in 120:
		follow.step(STEP)

	(companion.get_node("Health") as HealthComponent).take_damage(10.0)
	follow.step(STEP)
	assert_false(follow.input_source().poll().is_moving(), "it kept walking through a punch")


func test_a_companion_with_nobody_to_follow_stands_still() -> void:
	var companion: CharacterBody3D = load(COMPANION_SCENE).instantiate()
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(companion)
	_mounted.append(companion)

	var follow: FollowComponent = companion.get_node("Follow")
	assert_null(follow.target)
	for _frame in 60:
		follow.step(STEP)
	assert_false(follow.input_source().poll().is_moving())


## "The companion walks into walls" and "the companion has no navmesh" look
## identical from the outside, so it has to be possible to ask.
func test_the_world_has_navigation_baked_over_it() -> void:
	var world := _mount_world()
	var region: NavigationRegion3D = world.get_node_or_null("Navigation")
	assert_not_null(region, "the world has no navigation region")
	assert_not_null(region.navigation_mesh, "the region has no mesh")
	assert_true(
		region.navigation_mesh.get_polygon_count() > 0,
		"the navigation mesh baked empty -- nothing would ever find a route"
	)


func test_the_level_bakes_after_it_builds() -> void:
	# A mesh baked over the original hillside would route through the walls and
	# up slopes that are no longer there.
	var world := _mount_world()
	var level: PrototypeLevel = world.get_node("Level")
	assert_eq(level.navigation_region, world.get_node("Navigation"))


func test_the_companion_actually_consults_a_route() -> void:
	var world := _mount_world()
	var follow: FollowComponent = world.get_node("Companion/Follow")
	assert_true(follow.is_pathfinding(), "it is walking in a straight line, not pathfinding")


func test_it_falls_back_to_a_straight_line_with_no_navigation() -> void:
	# Better than refusing to move because a bake failed.
	var parts := _pair()
	var companion: CharacterBody3D = parts[0]
	var leader: Node3D = parts[1]
	var follow: FollowComponent = parts[2]
	follow.agent = null

	companion.global_position = Vector3.ZERO
	leader.global_position = Vector3(0.0, 0.0, -12.0)
	for _frame in 120:
		follow.step(STEP)
	assert_false(follow.is_pathfinding())
	assert_true(follow.input_source().poll().move.y < -0.7, "it did not head for you")
