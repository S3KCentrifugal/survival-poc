extends TestCase
## Blowing up, and the HUD that watches the player's vitals.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const WANDERER_SCENE: String = "res://characters/wanderer.tscn"
const EXPLOSION_SCENE: String = "res://effects/explosion.tscn"
const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount_wanderer() -> CharacterBody3D:
	var tree := Engine.get_main_loop() as SceneTree
	var holder := Node3D.new()
	tree.root.add_child(holder)
	_mounted.append(holder)

	var actor: CharacterBody3D = load(WANDERER_SCENE).instantiate()
	holder.add_child(actor)
	return actor


func test_the_effect_scene_loads() -> void:
	var scene: PackedScene = load(EXPLOSION_SCENE)
	assert_not_null(scene, "%s is missing or malformed" % EXPLOSION_SCENE)
	var effect: Node = scene.instantiate()
	assert_true(effect is Explosion)
	effect.free()


func test_a_wanderer_is_wired_to_blow_up() -> void:
	var actor := _mount_wanderer()
	var explode: ExplodeOnDeath = actor.get_node_or_null("Explode")
	assert_not_null(explode, "a wanderer at zero health would just stand there")
	assert_eq(explode.health, actor.get_node("Health"))
	assert_not_null(explode.effect, "it would disappear with no explosion")


func test_running_out_of_health_sets_it_off() -> void:
	var actor := _mount_wanderer()
	var explode: ExplodeOnDeath = actor.get_node("Explode")
	var health: HealthComponent = actor.get_node("Health")
	var bursts := [Vector3.ZERO]
	var count := [0]
	explode.exploded.connect(
		func(where: Vector3) -> void:
			bursts[0] = where
			count[0] += 1
	)

	health.take_damage(health.maximum())
	assert_eq(count[0], 1, "it did not explode")
	assert_true(bursts[0].y > actor.global_position.y, "the burst was at its feet")


func test_the_actor_is_removed() -> void:
	var actor := _mount_wanderer()
	var health: HealthComponent = actor.get_node("Health")
	health.take_damage(health.maximum())
	assert_true(actor.is_queued_for_deletion(), "the corpse was left standing")


## A burst parented to the thing being freed is freed with it and lasts zero
## frames. It has to go into the actor's parent.
func test_the_explosion_outlives_the_actor() -> void:
	var actor := _mount_wanderer()
	var parent := actor.get_parent()
	var health: HealthComponent = actor.get_node("Health")
	health.take_damage(health.maximum())

	var found := false
	for child: Node in parent.get_children():
		if child is Explosion and not child.is_queued_for_deletion():
			found = true
	assert_true(found, "no surviving explosion was left in the world")


func test_it_only_explodes_once() -> void:
	var actor := _mount_wanderer()
	var explode: ExplodeOnDeath = actor.get_node("Explode")
	var count := [0]
	explode.exploded.connect(func(_where: Vector3) -> void: count[0] += 1)

	explode.explode()
	explode.explode()
	assert_eq(count[0], 1, "exploded %d times" % count[0])


func test_it_can_be_set_off_directly() -> void:
	# So a test, or a console command later, does not have to arrange a death.
	var actor := _mount_wanderer()
	var explode: ExplodeOnDeath = actor.get_node("Explode")
	explode.explode()
	assert_true(explode.is_exploding() or actor.is_queued_for_deletion())


func test_an_explosion_cleans_itself_up() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var effect: Explosion = load(EXPLOSION_SCENE).instantiate()
	tree.root.add_child(effect)
	_mounted.append(effect)

	for _frame in 10:
		effect._process(0.5)
	assert_true(effect.is_queued_for_deletion(), "the effect would pile up forever")


func test_the_flash_fades() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var effect: Explosion = load(EXPLOSION_SCENE).instantiate()
	tree.root.add_child(effect)
	_mounted.append(effect)

	var before: float = effect.flash.light_energy
	effect._process(0.1)
	assert_true(effect.flash.light_energy < before, "the light stayed on")


func test_bursting_with_no_scene_does_not_crash() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	assert_null(Explosion.burst(null, tree.root, Vector3.ZERO))


func test_it_takes_a_few_punches_to_blow_one_up() -> void:
	# The number matters: one-shot wanderers make the cooldown pointless, and
	# twenty makes punching tedious.
	var actor := _mount_wanderer()
	var health: HealthComponent = actor.get_node("Health")
	var attack: AttackConfig = load("res://resources/attack/player_attack.tres")

	var punches := 0
	while health.is_alive() and punches < 100:
		health.take_damage(attack.damage)
		punches += 1
	assert_true(punches >= 3, "a wanderer died in %d punches" % punches)
	assert_true(punches <= 15, "a wanderer took %d punches to kill" % punches)
