extends TestCase
## Punching: the cooldown, the rising edge, and what shows on the character.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const CONFIG_RESOURCE: String = "res://resources/attack/player_attack.tres"
const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _attacker(cooldown: float = 0.35) -> AttackComponent:
	var config := AttackConfig.new()
	config.cooldown = cooldown
	var component := AttackComponent.new()
	component.config = config
	component.input_source = ScriptedInputSource.new()
	_mounted.append(component)
	return component


func _source_of(attack: AttackComponent) -> ScriptedInputSource:
	return attack.input_source


func _mount_player() -> CharacterBody3D:
	var tree := Engine.get_main_loop() as SceneTree
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	tree.root.add_child(player)
	_mounted.append(player)
	return player


func test_the_config_resource_loads() -> void:
	var config: AttackConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not an AttackConfig" % CONFIG_RESOURCE)
	assert_true(config.cooldown > 0.0, "a punch with no cooldown is a punch every frame")


func test_the_action_is_bound() -> void:
	assert_true(
		InputMap.has_action(PlayerInputSource.ACTION_ATTACK),
		"the attack action is not in the InputMap, so no click produces one"
	)


func test_the_player_carries_an_attack_component() -> void:
	var player := _mount_player()
	var attack: AttackComponent = player.get_node_or_null("Attack")
	assert_not_null(attack, "the player cannot punch")
	assert_not_null(attack.config, "config is not wired in the scene")


func test_the_animation_component_watches_the_attack() -> void:
	var player := _mount_player()
	var animation: AnimationComponent = player.get_node("Animation")
	assert_eq(animation.attack, player.get_node("Attack"), "a punch would never be shown")


func test_the_rig_has_the_punch_clip() -> void:
	var player := _mount_player()
	var animation: AnimationComponent = player.get_node("Animation")
	var rig: AnimationPlayer = animation.animation_player
	assert_true(
		rig.has_animation(animation.config.punch_animation),
		'no clip named "%s" in %s' % [
			animation.config.punch_animation, rig.get_animation_list()
		]
	)


func test_clicking_throws_a_punch() -> void:
	var attack := _attacker()
	var thrown := [0]
	attack.attacked.connect(func() -> void: thrown[0] += 1)

	_source_of(attack).attack(true)
	attack.step(STEP)
	assert_eq(thrown[0], 1, "the click did not land a punch")


## The rate limit, which is the point of the feature.
func test_a_second_punch_has_to_wait() -> void:
	var attack := _attacker(0.35)
	var source := _source_of(attack)
	var thrown := [0]
	attack.attacked.connect(func() -> void: thrown[0] += 1)

	# Click, release, click again immediately.
	source.attack(true)
	attack.step(STEP)
	source.attack(false)
	attack.step(STEP)
	source.attack(true)
	attack.step(STEP)
	assert_eq(thrown[0], 1, "punched %d times inside one cooldown" % thrown[0])


func test_the_punch_comes_back_after_the_cooldown() -> void:
	var attack := _attacker(0.2)
	var source := _source_of(attack)
	var thrown := [0]
	attack.attacked.connect(func() -> void: thrown[0] += 1)

	source.attack(true)
	attack.step(STEP)
	source.attack(false)
	for _frame in 20:  # a third of a second
		attack.step(STEP)
	source.attack(true)
	attack.step(STEP)
	assert_eq(thrown[0], 2, "the punch never became available again")


## A held button is one punch, not one per frame. Releasing arms the next --
## the same rule as jump.
func test_holding_the_button_punches_once() -> void:
	var attack := _attacker(0.05)
	var thrown := [0]
	attack.attacked.connect(func() -> void: thrown[0] += 1)

	_source_of(attack).attack(true)
	for _frame in 60:
		attack.step(STEP)
	assert_eq(thrown[0], 1, "a held button threw %d punches" % thrown[0])


func test_it_says_when_it_is_ready_again() -> void:
	var attack := _attacker(0.1)
	var ready := [0]
	attack.ready_again.connect(func() -> void: ready[0] += 1)

	attack.punch()
	assert_false(attack.can_attack())
	for _frame in 20:
		attack.step(STEP)
	assert_true(attack.can_attack())
	assert_eq(ready[0], 1, "ready_again fired %d times" % ready[0])


func test_it_is_attacking_for_the_length_of_the_cooldown() -> void:
	var attack := _attacker(0.2)
	attack.punch()
	assert_true(attack.is_attacking())
	for _frame in 6:  # 0.1s, halfway
		attack.step(STEP)
	assert_true(attack.is_attacking(), "the swing ended early")
	for _frame in 12:
		attack.step(STEP)
	assert_false(attack.is_attacking(), "the swing never ended")


func test_punching_can_be_asked_for_directly() -> void:
	# A scripted actor, or the console later, should not have to fake a click.
	var attack := _attacker(0.2)
	assert_true(attack.punch())
	assert_false(attack.punch(), "the cooldown did not refuse the second call")


func test_an_attack_with_no_input_source_never_swings() -> void:
	var attack := AttackComponent.new()
	attack.config = AttackConfig.new()
	_mounted.append(attack)
	for _frame in 30:
		attack.step(STEP)
	assert_false(attack.is_attacking())


## The character has to look like it is punching, and go back to what it was
## doing afterwards.
func test_the_animation_shows_a_punch_and_then_stops() -> void:
	var player := _mount_player()
	var attack: AttackComponent = player.get_node("Attack")
	var animation: AnimationComponent = player.get_node("Animation")

	attack.punch()
	animation.step()
	assert_eq(animation.state_name(), &"punch")

	for _frame in 40:
		attack.step(STEP)
	animation.step()
	assert_ne(animation.state_name(), &"punch", "the character never stopped punching")


## Punching beats locomotion, which is crude but predictable.
func test_a_punch_is_shown_even_while_running() -> void:
	var config := AnimationConfig.new()
	var machine := AnimationStateMachine.new(config)
	var state := machine.update(7.0, true, true, 0.0, true)
	assert_eq(state, AnimationStateMachine.State.PUNCH)


func test_not_punching_leaves_locomotion_alone() -> void:
	var machine := AnimationStateMachine.new(AnimationConfig.new())
	assert_eq(machine.update(3.0, false, true, 0.0, false), AnimationStateMachine.State.WALK)
