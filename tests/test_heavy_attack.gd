extends TestCase
## The heavy attack: what it costs, what it hits, and that it looks different.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const CONFIG_PATH: String = "res://resources/attack/player_attack.tres"
const ANIMATION_PATH: String = "res://resources/animation/player_animation.tres"
const STEP: float = 1.0 / 60.0

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_mounted.append(node)
	return node


## An attacker with its own config copy, a full stamina bar, and a scripted
## hand on the buttons.
func _attacker() -> AttackComponent:
	var body := CharacterBody3D.new()
	_mount(body)

	var stamina := StaminaComponent.new()
	stamina.config = load("res://resources/stamina/player_stamina.tres")
	body.add_child(stamina)

	var attack := AttackComponent.new()
	attack.config = load(CONFIG_PATH).duplicate()
	attack.body = body
	attack.stamina = stamina
	attack.input_source = ScriptedInputSource.new()
	body.add_child(attack)
	return attack


func test_the_key_is_bound() -> void:
	assert_true(
		InputMap.has_action(PlayerInputSource.ACTION_HEAVY_ATTACK),
		"the heavy attack action is not in the InputMap, so no button produces one"
	)


func test_it_is_bound_to_the_right_mouse_button() -> void:
	var found := false
	for event: InputEvent in InputMap.action_get_events(PlayerInputSource.ACTION_HEAVY_ATTACK):
		var button := event as InputEventMouseButton
		if button != null and button.button_index == MOUSE_BUTTON_RIGHT:
			found = true
	assert_true(found, "heavy attack is not on right click")


## The whole point: it has to be worth the wait.
func test_it_hits_much_harder_than_a_punch() -> void:
	var config: AttackConfig = load(CONFIG_PATH)
	assert_true(
		config.heavy_damage > config.damage * 2.0,
		"heavy does %.0f against a punch's %.0f" % [config.heavy_damage, config.damage]
	)


## The wait *is* the cost. A heavy you can throw as fast as a light one is just
## a better light one.
func test_it_is_slower_than_a_punch() -> void:
	var config: AttackConfig = load(CONFIG_PATH)
	assert_true(config.heavy_cooldown > config.cooldown * 2.0, "the heavy is barely slower")


## Further, but narrower. A heavy that also forgives your aim is strictly better
## in every way.
func test_it_reaches_further_in_a_narrower_arc() -> void:
	var config: AttackConfig = load(CONFIG_PATH)
	assert_true(config.heavy_reach > config.reach, "the kick does not out-reach the fist")
	assert_true(config.heavy_arc_degrees < config.arc_degrees, "the heavy is the wider swing")


func test_right_click_throws_one() -> void:
	var attack := _attacker()
	var source: ScriptedInputSource = attack.input_source
	var heavies := [0]
	attack.heavy_attacked.connect(func() -> void: heavies[0] += 1)

	source.heavy_attack(true)
	attack.step(STEP)
	assert_eq(heavies[0], 1, "right click threw %d heavy attacks" % heavies[0])


func test_holding_right_click_throws_one() -> void:
	var attack := _attacker()
	(attack.input_source as ScriptedInputSource).heavy_attack(true)
	var heavies := [0]
	attack.heavy_attacked.connect(func() -> void: heavies[0] += 1)

	for _frame in 30:
		attack.step(STEP)
	assert_eq(heavies[0], 1, "a held button threw %d" % heavies[0])


func test_a_second_heavy_has_to_wait() -> void:
	var attack := _attacker()
	assert_true(attack.heavy_punch())
	assert_false(attack.heavy_punch(), "two heavy attacks in a row with no wait")

	for _frame in int(attack.config.heavy_cooldown / STEP) + 2:
		attack.step(STEP)
	assert_true(attack.can_heavy_attack(), "it never came back")


## The standard way this gets broken: throw a heavy, then cancel its recovery
## with a jab and pay none of the cost.
func test_a_punch_cannot_cancel_the_heavy_recovery() -> void:
	var attack := _attacker()
	attack.heavy_punch()
	assert_false(attack.punch(), "a jab cancelled the heavy's recovery")


func test_it_costs_stamina() -> void:
	var attack := _attacker()
	var before := attack.stamina.current()
	attack.heavy_punch()
	assert_true(
		attack.stamina.current() < before,
		"the heavy attack was free, which makes the light one pointless"
	)


## Refused rather than weakened. A heavy that quietly becomes a light one when
## you are tired is a heavy you cannot rely on.
func test_it_is_refused_when_there_is_no_stamina_for_it() -> void:
	var attack := _attacker()
	attack.stamina.set_current(1.0)

	assert_false(attack.can_heavy_attack())
	assert_false(attack.heavy_punch(), "it swung on an empty bar")
	assert_eq(attack.stamina.current(), 1.0, "a refused heavy still took stamina")


func test_stamina_refuses_a_lump_it_cannot_pay() -> void:
	var attack := _attacker()
	attack.stamina.set_current(10.0)
	assert_false(attack.stamina.spend(25.0))
	assert_eq(attack.stamina.current(), 10.0, "a refused payment still took some")
	assert_true(attack.stamina.spend(10.0))
	assert_eq(attack.stamina.current(), 0.0)


## Both buttons held should throw the one that costs something, not whichever
## happens to be checked first.
func test_holding_both_buttons_throws_the_heavy() -> void:
	var attack := _attacker()
	var source: ScriptedInputSource = attack.input_source
	var light := [0]
	var heavy := [0]
	attack.attacked.connect(func() -> void: light[0] += 1)
	attack.heavy_attacked.connect(func() -> void: heavy[0] += 1)

	source.attack(true)
	source.heavy_attack(true)
	attack.step(STEP)
	assert_eq(heavy[0], 1, "the heavy did not win")
	assert_eq(light[0], 0, "it threw a punch as well")


## "Make it clear from the animation it is a stronger attack" is answered by a
## different move, not the punch played slowly.
func test_the_heavy_plays_a_different_clip() -> void:
	var config: AnimationConfig = load(ANIMATION_PATH)
	assert_false(
		config.heavy_animation == config.punch_animation,
		"the heavy attack plays the punch animation"
	)
	assert_false(config.heavy_animation.is_empty())


func test_the_rig_has_the_clip_the_config_names() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	var animation: AnimationComponent = player.get_node("Animation")
	var rig: AnimationPlayer = animation.animation_player
	assert_true(
		rig.has_animation(animation.config.heavy_animation),
		'no clip named "%s" in %s' % [animation.config.heavy_animation, rig.get_animation_list()]
	)


## The heavy clip should be long enough that most of it plays inside the
## cooldown -- a swing cut into a jab does not read as heavy.
func test_the_heavy_swing_is_shown_for_most_of_its_clip() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	var animation: AnimationComponent = player.get_node("Animation")
	var attack: AttackComponent = player.get_node("Attack")
	var clip := (animation.animation_player as AnimationPlayer).get_animation(
		animation.config.heavy_animation
	)
	assert_true(
		attack.config.heavy_cooldown > clip.length * 0.7,
		"the %.2f s kick is cut to %.2f s" % [clip.length, attack.config.heavy_cooldown]
	)


## A heavy is also "attacking" as far as the cooldown is concerned, so the state
## machine has to be told which it is or it shows the jab.
func test_the_state_machine_prefers_the_heavy_state() -> void:
	var machine := AnimationStateMachine.new(load(ANIMATION_PATH))
	assert_eq(
		machine.update(0.0, false, true, 0.0, true, false, true),
		AnimationStateMachine.State.HEAVY,
		"a heavy swing showed the punch state"
	)
	assert_eq(
		machine.update(0.0, false, true, 0.0, true, false, false),
		AnimationStateMachine.State.PUNCH
	)


func test_being_hit_still_beats_a_heavy_swing() -> void:
	var machine := AnimationStateMachine.new(load(ANIMATION_PATH))
	assert_eq(
		machine.update(0.0, false, true, 0.0, true, true, true),
		AnimationStateMachine.State.HURT,
		"a heavy attack could not be interrupted"
	)


func test_the_player_is_assembled_for_heavy_attacks() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	_mount(player)
	var attack: AttackComponent = player.get_node("Attack")
	assert_eq(attack.stamina, player.get_node("Stamina"), "the heavy attack would be free")
	assert_true(attack.config.heavy_stamina_cost > 0.0)


## A panel that releases the cursor has to release the buttons too. Right click
## was free while the mouse was loose; now it is an attack, and clicking a
## "Sell" button would also kick whoever was standing behind the panel.
func test_open_panels_suspend_gameplay_input() -> void:
	var world: Node = load("res://scenes/main.tscn").instantiate()
	_mount(world)

	for path: String in ["InventoryScreen", "StoreScreen", "CraftingScreen"]:
		var panel: CanvasLayer = world.get_node(path)
		assert_false(world.is_input_suspended(), "%s left input suspended" % path)

		if panel is StoreScreen:
			(panel as StoreScreen).show_merchant(
				(world.get_node("Merchants") as MerchantPost).merchants()[0].get_node("Merchant")
			)
		elif panel is CraftingScreen:
			(panel as CraftingScreen).show_bench(world.get_node("Workbench/Bench"))
		else:
			(panel as InventoryScreen).set_open(true)

		assert_true(
			world.is_input_suspended(),
			"%s is open and the character can still be driven behind it" % path
		)
		panel.call(&"set_open", false)
		assert_false(world.is_input_suspended(), "%s did not give the keyboard back" % path)
