extends TestCase
## The player's health and stamina bars.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const HUD_SCENE: String = "res://ui/player_hud.tscn"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


## A HUD watching vitals of its own, so a test can move them freely.
func _hud() -> PlayerHud:
	var tree := Engine.get_main_loop() as SceneTree
	var hud: PlayerHud = load(HUD_SCENE).instantiate()

	var health := HealthComponent.new()
	health.config = HealthConfig.new()
	var stamina := StaminaComponent.new()
	stamina.config = StaminaConfig.new()
	hud.add_child(health)
	hud.add_child(stamina)
	hud.health = health
	hud.stamina = stamina

	tree.root.add_child(hud)
	_mounted.append(hud)
	hud.refresh()
	return hud


func test_the_main_scene_carries_a_hud_wired_to_the_player() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node = load(MAIN_SCENE).instantiate()
	tree.root.add_child(world)
	_mounted.append(world)

	var hud: PlayerHud = world.get_node_or_null("PlayerHud")
	assert_not_null(hud, "the player has no HUD")
	assert_eq(hud.health, world.get_node("Player/Health"))
	assert_eq(hud.stamina, world.get_node("Player/Stamina"))


## The HUD is for whoever is playing; the overlay is for whoever is building.
## F3 must not take the health bar away with it.
func test_it_is_not_the_debug_overlay() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var world: Node = load(MAIN_SCENE).instantiate()
	tree.root.add_child(world)
	_mounted.append(world)

	var hud: PlayerHud = world.get_node("PlayerHud")
	var overlay: DebugOverlay = world.get_node("DebugOverlay")
	assert_ne(hud, overlay)
	assert_true(hud.visible, "the HUD should be on from the start")

	overlay.set_open(false) if overlay.has_method("set_open") else overlay.set("visible", false)
	assert_true(hud.visible, "hiding the debug overlay hid the HUD too")


func test_it_starts_showing_full_bars() -> void:
	var hud := _hud()
	assert_true(is_equal_approx(hud.health_fraction(), 1.0))
	assert_true(is_equal_approx(hud.stamina_fraction(), 1.0))


func test_the_health_bar_follows_damage() -> void:
	var hud := _hud()
	hud.health.take_damage(40.0)
	assert_true(
		is_equal_approx(hud.health_fraction(), 0.6), "bar shows %f" % hud.health_fraction()
	)


func test_the_health_bar_follows_healing() -> void:
	var hud := _hud()
	hud.health.take_damage(50.0)
	hud.health.heal(25.0)
	assert_true(is_equal_approx(hud.health_fraction(), 0.75))


func test_the_stamina_bar_follows_the_bar() -> void:
	var hud := _hud()
	hud.stamina.set_current(hud.stamina.maximum() * 0.25)
	assert_true(
		is_equal_approx(hud.stamina_fraction(), 0.25), "bar shows %f" % hud.stamina_fraction()
	)


func test_the_numbers_are_written_out() -> void:
	var hud := _hud()
	hud.health.take_damage(33.0)
	assert_eq(hud.health_label.text, "67 / 100")


## A bar that looks the same at 90% and 9% is a bar you stop reading.
func test_low_health_changes_colour() -> void:
	var hud := _hud()
	var healthy := (hud.health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color

	hud.health.take_damage(85.0)
	var hurt := (hud.health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color
	assert_ne(healthy, hurt, "the bar looks the same at 15 health as at 100")


func test_the_stamina_bar_says_when_you_cannot_sprint() -> void:
	var hud := _hud()
	var ready := (hud.stamina_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color

	for _tick in 600:
		hud.stamina.request_drain()
		hud.stamina.step(1.0 / 60.0)
	assert_true(hud.stamina.is_exhausted(), "could not exhaust the bar to set up the test")

	var spent := (hud.stamina_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color
	assert_ne(ready, spent, "an actor locked out looks exactly like one who is not")


## Recolouring must not edit the StyleBox both bars were handed.
func test_recolouring_one_bar_leaves_the_other_alone() -> void:
	var hud := _hud()
	var stamina_before := (hud.stamina_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color
	hud.health.take_damage(90.0)
	var stamina_after := (hud.stamina_bar.get_theme_stylebox(&"fill") as StyleBoxFlat).bg_color
	assert_eq(stamina_before, stamina_after, "the health bar recoloured the stamina bar")


func test_a_hud_watching_nothing_does_not_crash() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var hud: PlayerHud = load(HUD_SCENE).instantiate()
	tree.root.add_child(hud)
	_mounted.append(hud)
	hud.refresh()
	assert_eq(hud.health_fraction(), 1.0)
