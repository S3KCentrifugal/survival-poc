extends TestCase
## The wandering actor as assembled, and the spawner that places them.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const WANDERER_SCENE: String = "res://characters/wanderer.tscn"
const STEP: float = 1.0 / 60.0


func _mount_wanderer() -> CharacterBody3D:
	var actor: CharacterBody3D = load(WANDERER_SCENE).instantiate()
	mount(actor)
	return actor


func _mount_world() -> Node:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	return world


func test_the_scene_is_assembled() -> void:
	var actor := _mount_wanderer()
	assert_true(actor is CharacterBody3D, "a wanderer must collide")
	for child: String in ["CollisionShape3D", "Model", "Movement", "Wander", "Animation"]:
		assert_not_null(actor.get_node_or_null(child), "no %s" % child)


## The whole point of the input abstraction: the wanderer runs the player's
## movement code and movement cannot tell the difference.
func test_it_drives_the_same_movement_component_the_player_uses() -> void:
	var actor := _mount_wanderer()
	var movement: MovementComponent = actor.get_node("Movement")
	assert_not_null(movement.input_source, "nothing is telling it where to go")
	assert_true(movement.input_source is InputSource)
	assert_eq(movement.body, actor)


func test_it_ambles_rather_than_strides() -> void:
	var actor := _mount_wanderer()
	var movement: MovementComponent = actor.get_node("Movement")
	var player: MovementConfig = load("res://resources/movement/player_movement.tres")
	assert_true(
		movement.config.walk_speed < player.walk_speed,
		"a wanderer walking at %f is not slower than the player's %f"
		% [movement.config.walk_speed, player.walk_speed]
	)


func test_it_cannot_sprint_or_jump() -> void:
	# Nothing sets those intents, and the config should not invite it either.
	var actor := _mount_wanderer()
	var movement: MovementComponent = actor.get_node("Movement")
	assert_true(is_equal_approx(movement.config.sprint_multiplier, 1.0))
	assert_true(is_zero_approx(movement.config.jump_height))


func test_it_walks_when_told_to() -> void:
	var actor := _mount_wanderer()
	var wander: WanderComponent = actor.get_node("Wander")
	var movement: MovementComponent = actor.get_node("Movement")

	# Run it past the longest pause, then check the intent is non-zero at least
	# once -- physics is not running here, so position never changes.
	var walked := false
	for _frame in 600:
		wander.step(STEP)
		if movement.input_source.poll().is_moving():
			walked = true
			break
	assert_true(walked, "it never decided to go anywhere")


## Polling must not advance the clock. Two components sharing one source would
## otherwise run the wanderer twice per tick.
func test_polling_does_not_advance_it() -> void:
	var actor := _mount_wanderer()
	var wander: WanderComponent = actor.get_node("Wander")
	var source := wander.input_source()

	var before := wander.wander().timer()
	for _poll in 20:
		source.poll()
	assert_true(
		is_equal_approx(wander.wander().timer(), before), "polling moved the wanderer's clock"
	)


func test_setting_a_home_moves_where_it_strays_from() -> void:
	var actor := _mount_wanderer()
	var wander: WanderComponent = actor.get_node("Wander")
	wander.set_home(Vector2(25.0, -25.0), 99)
	assert_eq(wander.wander().home(), Vector2(25.0, -25.0))


func test_the_main_scene_spawns_some() -> void:
	var world := _mount_world()
	var spawner: WandererSpawner = world.get_node_or_null("Wanderers")
	assert_not_null(spawner, "the world has nobody in it")
	assert_eq(spawner.spawned_actors().size(), spawner.count)


func test_they_are_scattered_rather_than_stacked() -> void:
	var spawner: WandererSpawner = _mount_world().get_node("Wanderers")
	var actors := spawner.spawned_actors()
	for outer in actors.size():
		for inner in range(outer + 1, actors.size()):
			var apart := actors[outer].global_position.distance_to(actors[inner].global_position)
			assert_true(apart > 0.5, "two wanderers spawned %f apart" % apart)


## Nobody should be standing in the room the player wakes up in.
func test_nobody_spawns_inside_the_base() -> void:
	var spawner: WandererSpawner = _mount_world().get_node("Wanderers")
	for actor: Node3D in spawner.spawned_actors():
		var here := Vector2(actor.global_position.x, actor.global_position.z)
		assert_false(spawner.avoid.has_point(here), "a wanderer spawned at %v, inside the base" % here)


func test_each_one_wanders_on_its_own() -> void:
	# Sharing a seed makes them walk in step, which reads as choreography.
	var spawner: WandererSpawner = _mount_world().get_node("Wanderers")
	var homes: Array[Vector2] = []
	for actor: Node3D in spawner.spawned_actors():
		var wander: WanderComponent = actor.get_node("Wander")
		assert_false(homes.has(wander.wander().home()), "two wanderers share a home")
		homes.append(wander.wander().home())


## Spawned, not placed, so a tree path is not an identity for it.
func test_spawned_actors_get_an_identity_of_their_own() -> void:
	var spawner: WandererSpawner = _mount_world().get_node("Wanderers")
	var seen: Array[StringName] = []
	for actor: Node3D in spawner.spawned_actors():
		var save_id: SaveIdComponent = actor.get_node_or_null("SaveId")
		if save_id == null:
			continue
		assert_false(seen.has(save_id.save_key()), "two wanderers share a save id")
		seen.append(save_id.save_key())


func test_a_spawner_with_no_scene_says_so_rather_than_crashing() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var spawner := WandererSpawner.new()
	spawner.scene = null
	mount(spawner)
	assert_eq(spawner.spawned_actors().size(), 0)
