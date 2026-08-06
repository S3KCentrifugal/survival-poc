extends TestCase
## Keeping the world topped up.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const WANDERER_SCENE: String = "res://characters/wanderer.tscn"
const STEP: float = 1.0 / 60.0


## A spawner with nothing else in the world, so counts are unambiguous.
func _spawner(count: int = 3, delay: float = 1.0) -> WandererSpawner:
	var tree := Engine.get_main_loop() as SceneTree
	var spawner := WandererSpawner.new()
	spawner.scene = load(WANDERER_SCENE)
	spawner.count = count
	spawner.respawn_delay = delay
	spawner.keep_away = 0.0
	spawner.area = Rect2(-20.0, -20.0, 40.0, 40.0)
	spawner.avoid = Rect2(0.0, 0.0, 0.0, 0.0)
	mount(spawner)
	return spawner


## Removes one and lets the tree actually free it, which is what a spawner
## notices. queue_free alone leaves it standing until the end of the frame.
func _kill_one(spawner: WandererSpawner) -> void:
	var actor := spawner.spawned_actors()[0]
	var health: HealthComponent = actor.get_node("Health")
	health.take_damage(health.maximum())


func test_it_starts_full() -> void:
	var spawner := _spawner(3)
	assert_eq(spawner.spawned_actors().size(), 3)
	assert_eq(spawner.missing(), 0)


func test_a_dead_wanderer_leaves_a_gap() -> void:
	var spawner := _spawner(3)
	_kill_one(spawner)
	assert_eq(spawner.missing(), 1, "the spawner did not notice the death")
	assert_eq(spawner.spawned_actors().size(), 2)


func test_the_gap_is_filled() -> void:
	var spawner := _spawner(3)
	_kill_one(spawner)
	spawner.replace_one()
	assert_eq(spawner.missing(), 0, "the world did not top itself up")
	assert_eq(spawner.spawned_actors().size(), 3)


## Somebody reappearing the moment you finished them reads as the punch not
## counting.
func test_the_replacement_waits_out_the_delay() -> void:
	var spawner := _spawner(3, 1.0)
	_kill_one(spawner)

	for _frame in 30:  # half a second
		spawner._process(STEP)
	assert_eq(spawner.missing(), 1, "it refilled instantly")

	for _frame in 60:
		spawner._process(STEP)
	assert_eq(spawner.missing(), 0, "it never refilled")


func test_it_refills_more_than_one() -> void:
	var spawner := _spawner(3, 0.0)
	for _death in 3:
		_kill_one(spawner)
	assert_eq(spawner.missing(), 3)

	for _frame in 60:
		spawner._process(STEP)
	assert_eq(spawner.missing(), 0, "the world stayed empty")


func test_it_never_overfills() -> void:
	var spawner := _spawner(3, 0.0)
	for _frame in 300:
		spawner._process(STEP)
	assert_eq(spawner.spawned_actors().size(), 3, "the world kept growing")


func test_respawning_can_be_switched_off() -> void:
	var spawner := _spawner(3, 0.0)
	spawner.respawn = false
	_kill_one(spawner)
	for _frame in 300:
		spawner._process(STEP)
	assert_eq(spawner.missing(), 1, "it refilled with respawning off")


func test_it_says_when_the_world_is_full_again() -> void:
	var spawner := _spawner(2, 0.0)
	var refills := [0]
	spawner.refilled.connect(func() -> void: refills[0] += 1)
	_kill_one(spawner)
	spawner.replace_one()
	assert_eq(refills[0], 1)


## A wanderer materialising in front of you is worse than a world with one
## fewer in it for a moment.
func test_nobody_spawns_on_top_of_the_player() -> void:
	var player := Node3D.new()
	mount(player)
	player.global_position = Vector3(5.0, 0.0, 5.0)

	var spawner := _spawner(6, 0.0)
	spawner.keep_away = 12.0
	spawner.keep_away_from = player
	for actor: Node3D in spawner.spawned_actors():
		actor.get_node("Health").take_damage(1000.0)
	for _frame in 120:
		spawner._process(STEP)

	for actor: Node3D in spawner.spawned_actors():
		var apart := Vector2(
			actor.global_position.x - player.global_position.x,
			actor.global_position.z - player.global_position.z
		).length()
		assert_true(apart >= 11.0, "a wanderer spawned %.1f m from the player" % apart)


func test_replacements_are_not_all_in_the_same_place() -> void:
	# The generator carries on between spawns rather than restarting, or every
	# refill lands where the first batch did.
	var spawner := _spawner(2, 0.0)
	var first := spawner.spawned_actors()[0].global_position
	_kill_one(spawner)
	spawner.replace_one()

	var same := 0
	for actor: Node3D in spawner.spawned_actors():
		if actor.global_position.distance_to(first) < 0.01:
			same += 1
	assert_eq(same, 0, "a replacement landed exactly where the dead one had")


func test_the_main_scene_keeps_replacements_away_from_the_player() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)

	var spawner: WandererSpawner = world.get_node("Wanderers")
	assert_true(spawner.respawn, "the world would run out")
	assert_eq(spawner.keep_away_from, world.get_node("Player"))
	assert_true(spawner.keep_away > 0.0)
