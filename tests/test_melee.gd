extends TestCase
## What a punch reaches, and what being punched does.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const WANDERER_SCENE: String = "res://characters/wanderer.tscn"
const STEP: float = 1.0 / 60.0
const REACH: float = 2.0
const ARC: float = deg_to_rad(110.0)

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _reaches(target: Vector3, forward: Vector3 = Vector3.FORWARD) -> bool:
	return MeleeSolver.can_reach(Vector3.ZERO, forward, target, REACH, ARC)


func test_something_straight_ahead_is_hit() -> void:
	# Vector3.FORWARD is -Z, which is the way a node faces.
	assert_true(_reaches(Vector3(0.0, 0.0, -1.5)))


func test_something_behind_you_is_not() -> void:
	assert_false(_reaches(Vector3(0.0, 0.0, 1.5)), "punched somebody behind you")


func test_something_out_of_reach_is_not() -> void:
	assert_false(_reaches(Vector3(0.0, 0.0, -2.5)))


func test_the_edge_of_reach_still_counts() -> void:
	assert_true(_reaches(Vector3(0.0, 0.0, -REACH)))


func test_something_off_to_the_side_is_inside_a_wide_arc() -> void:
	# 110 degrees wide means 55 either side, so 45 degrees off is a hit.
	assert_true(_reaches(Vector3(-1.0, 0.0, -1.0)))
	assert_true(_reaches(Vector3(1.0, 0.0, -1.0)))


func test_something_at_a_right_angle_is_outside_it() -> void:
	assert_false(_reaches(Vector3(1.5, 0.0, 0.0)), "punched somebody at your shoulder")


## Height is ignored on purpose: a punch that misses because the target stands
## slightly downhill is worse than one generous about height.
func test_height_does_not_decide_a_hit() -> void:
	assert_true(_reaches(Vector3(0.0, 1.4, -1.0)))
	assert_true(_reaches(Vector3(0.0, -1.4, -1.0)))


func test_standing_inside_somebody_counts() -> void:
	assert_true(_reaches(Vector3.ZERO), "no direction to test, but certainly a hit")


func test_no_reach_hits_nothing() -> void:
	assert_false(MeleeSolver.can_reach(Vector3.ZERO, Vector3.FORWARD, Vector3.ZERO, 0.0, ARC))


func test_the_arc_can_be_opened_all_the_way_round() -> void:
	assert_true(
		MeleeSolver.can_reach(
			Vector3.ZERO, Vector3.FORWARD, Vector3(0.0, 0.0, 1.5), REACH, deg_to_rad(360.0)
		)
	)


## Searched by type, because a hard-coded node name works until the first actor
## that names it something else, and fails silently when it does.
func test_health_is_found_on_whatever_was_hit() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var actor: CharacterBody3D = load(WANDERER_SCENE).instantiate()
	tree.root.add_child(actor)
	_mounted.append(actor)
	assert_not_null(MeleeSolver.health_of(actor), "a wanderer's health was not found")


func test_something_with_no_health_is_not_a_target() -> void:
	var node := Node3D.new()
	_mounted.append(node)
	assert_null(MeleeSolver.health_of(node))
	assert_null(MeleeSolver.health_of(null))


func test_the_player_swing_is_wired_to_a_body() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	tree.root.add_child(player)
	_mounted.append(player)

	var attack: AttackComponent = player.get_node("Attack")
	assert_eq(attack.body, player, "the punch has no idea where it is swung from")
	assert_true(attack.config.reach > 0.0)
	assert_true(attack.config.damage > 0.0)


func _hurt_actor() -> HurtReaction:
	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var reaction := HurtReaction.new()
	reaction.health = health
	reaction.stagger_seconds = 0.5
	health.add_child(reaction)
	_mounted.append(health)
	# _ready has already run for neither, so connect the way the scene does.
	health.damaged.connect(reaction._on_damaged)
	return reaction


func test_taking_damage_starts_a_flinch() -> void:
	var reaction := _hurt_actor()
	assert_false(reaction.is_reacting())
	reaction.health.take_damage(10.0)
	assert_true(reaction.is_reacting(), "being hit did nothing")


func test_the_flinch_wears_off() -> void:
	var reaction := _hurt_actor()
	reaction.health.take_damage(10.0)
	for _frame in 40:  # two thirds of a second
		reaction.step(STEP)
	assert_false(reaction.is_reacting(), "it never recovered")


## A second hit should restart the reel rather than be swallowed by the first,
## which is the difference between a punch that lands and one that does nothing.
func test_a_second_hit_restarts_the_flinch() -> void:
	var reaction := _hurt_actor()
	reaction.health.take_damage(10.0)
	for _frame in 20:
		reaction.step(STEP)
	reaction.health.take_damage(10.0)
	for _frame in 20:
		reaction.step(STEP)
	assert_true(reaction.is_reacting(), "the second hit was swallowed by the first")


func test_it_announces_the_flinch_and_the_recovery() -> void:
	var reaction := _hurt_actor()
	var flinches := [0]
	var recoveries := [0]
	reaction.flinched.connect(func() -> void: flinches[0] += 1)
	reaction.recovered.connect(func() -> void: recoveries[0] += 1)

	reaction.health.take_damage(5.0)
	for _frame in 40:
		reaction.step(STEP)
	assert_eq(flinches[0], 1)
	assert_eq(recoveries[0], 1)


func test_a_dead_actor_is_not_alive() -> void:
	var reaction := _hurt_actor()
	reaction.health.take_damage(reaction.health.maximum())
	assert_false(reaction.is_alive())


## Being hit beats your own swing: a punch that lands on someone mid-punch has
## to interrupt them, or it did not land.
func test_the_flinch_beats_everything_on_screen() -> void:
	var machine := AnimationStateMachine.new(AnimationConfig.new())
	assert_eq(
		machine.update(7.0, true, true, 0.0, true, true), AnimationStateMachine.State.HURT
	)


func test_the_flinch_has_a_clip_in_the_rig() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var actor: CharacterBody3D = load(WANDERER_SCENE).instantiate()
	tree.root.add_child(actor)
	_mounted.append(actor)

	var animation: AnimationComponent = actor.get_node("Animation")
	assert_not_null(animation.hurt, "a wanderer would never show a flinch")
	var rig: AnimationPlayer = animation.animation_player
	assert_true(
		rig.has_animation(animation.config.hurt_animation),
		'no clip named "%s" in %s' % [animation.config.hurt_animation, rig.get_animation_list()]
	)


func test_a_reeling_wanderer_stands_still() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var actor: CharacterBody3D = load(WANDERER_SCENE).instantiate()
	tree.root.add_child(actor)
	_mounted.append(actor)

	var wander: WanderComponent = actor.get_node("Wander")
	var health: HealthComponent = actor.get_node("Health")

	# Get it walking, then hit it.
	for _frame in 600:
		wander.step(STEP)
		if wander.input_source().poll().is_moving():
			break
	health.take_damage(10.0)
	wander.step(STEP)
	assert_false(
		wander.input_source().poll().is_moving(), "it kept walking through being punched"
	)


func test_a_dead_wanderer_stops_for_good() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var actor: CharacterBody3D = load(WANDERER_SCENE).instantiate()
	tree.root.add_child(actor)
	_mounted.append(actor)

	var wander: WanderComponent = actor.get_node("Wander")
	var health: HealthComponent = actor.get_node("Health")
	health.take_damage(health.maximum())

	for _frame in 600:
		wander.step(STEP)
		assert_false(wander.input_source().poll().is_moving(), "a dead wanderer walked off")
