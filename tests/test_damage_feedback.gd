extends TestCase
## Seeing what a punch did: the number that floats up, and the bar over a head.

const PLAYER_SCENE: String = "res://characters/player.tscn"
const WANDERER_SCENE: String = "res://characters/wanderer.tscn"
const NUMBER_SCENE: String = "res://effects/damage_number.tscn"
const BAR_SCENE: String = "res://ui/health_bar_3d.tscn"


func _mount_wanderer() -> CharacterBody3D:
	var holder := Node3D.new()
	mount(holder)
	var actor: CharacterBody3D = load(WANDERER_SCENE).instantiate()
	holder.add_child(actor)
	return actor


func test_the_number_scene_loads() -> void:
	var number: Node = load(NUMBER_SCENE).instantiate()
	assert_true(number is DamageNumber)
	assert_not_null((number as DamageNumber).label, "it has nothing to write on")
	number.free()


func test_the_player_prints_its_damage() -> void:
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	mount(player)
	var numbers: DamageNumbers = player.get_node_or_null("DamageNumbers")
	assert_not_null(numbers, "punches would land silently")
	assert_eq(numbers.attack, player.get_node("Attack"))
	assert_not_null(numbers.effect)


func test_a_number_says_what_was_taken() -> void:
	var number: DamageNumber = load(NUMBER_SCENE).instantiate()
	mount(number)
	number.show_damage(37.0)
	assert_eq(number.label.text, "37")


func test_it_rounds_rather_than_printing_a_decimal() -> void:
	var number: DamageNumber = load(NUMBER_SCENE).instantiate()
	mount(number)
	number.show_damage(12.6)
	assert_eq(number.label.text, "13")


## The killing hit is the one you most want to read.
func test_a_killing_hit_looks_different() -> void:
	var ordinary: DamageNumber = load(NUMBER_SCENE).instantiate()
	var killing: DamageNumber = load(NUMBER_SCENE).instantiate()
	mount(ordinary)
	mount(killing)
	ordinary.show_damage(12.0, false)
	killing.show_damage(12.0, true)
	assert_ne(ordinary.label.modulate, killing.label.modulate)


func test_a_number_drifts_up_and_removes_itself() -> void:
	var number: DamageNumber = load(NUMBER_SCENE).instantiate()
	mount(number)
	number.global_position = Vector3(1.0, 2.0, 3.0)
	number._ready()

	number._process(0.2)
	assert_true(number.global_position.y > 2.0, "it did not rise")

	for _frame in 20:
		number._process(0.1)
	assert_true(number.is_queued_for_deletion(), "numbers would pile up forever")


func test_a_number_fades_before_it_goes() -> void:
	var number: DamageNumber = load(NUMBER_SCENE).instantiate()
	mount(number)
	number._ready()
	number._process(number.lifetime * 0.9)
	assert_true(number.label.modulate.a < 1.0, "it vanished at full opacity")


## Into the world, not onto the victim: the last hit is the one that killed,
## and the victim is about to be freed.
func test_a_number_is_not_parented_to_what_it_describes() -> void:
	var actor := _mount_wanderer()
	var world := actor.get_parent()
	var numbers := DamageNumbers.new()
	numbers.effect = load(NUMBER_SCENE)
	mount(numbers)

	numbers.print_damage(actor, 12.0)
	var found := false
	for child: Node in world.get_children():
		if child is DamageNumber:
			found = true
	assert_true(found, "the number was not put in the world beside the victim")


func test_printing_with_no_effect_scene_does_nothing() -> void:
	var actor := _mount_wanderer()
	var numbers := DamageNumbers.new()
	numbers.effect = null
	mount(numbers)
	numbers.print_damage(actor, 12.0)  # must not raise


func test_a_wanderer_carries_a_bar_over_its_head() -> void:
	var actor := _mount_wanderer()
	var bar: HealthBar3D = actor.get_node_or_null("HealthBar")
	assert_not_null(bar, "there is no way to see how hurt it is")
	assert_eq(bar.health, actor.get_node("Health"))
	assert_true(bar.position.y > 1.8, "the bar is not above the mesh")


func test_the_bar_tracks_health() -> void:
	var actor := _mount_wanderer()
	var bar: HealthBar3D = actor.get_node("HealthBar")
	var health: HealthComponent = actor.get_node("Health")

	health.take_damage(health.maximum() * 0.25)
	assert_true(is_equal_approx(bar.fraction(), 0.75), "bar shows %f" % bar.fraction())


## An untouched world of bars is a spreadsheet; a bar that appears when you hit
## something answers the only question you were asking.
func test_the_bar_appears_when_it_is_hit() -> void:
	var actor := _mount_wanderer()
	var bar: HealthBar3D = actor.get_node("HealthBar")
	assert_false(bar.visible, "every wanderer would show a bar all the time")

	(actor.get_node("Health") as HealthComponent).take_damage(5.0)
	assert_true(bar.visible, "hitting it did not bring the bar up")


func test_the_bar_hides_again_once_it_is_left_alone() -> void:
	var actor := _mount_wanderer()
	var bar: HealthBar3D = actor.get_node("HealthBar")
	(actor.get_node("Health") as HealthComponent).take_damage(5.0)

	for _frame in 400:
		bar._process(1.0 / 60.0)
	assert_false(bar.visible, "the bar stayed up forever")


## A scale of exactly zero collapses the basis and Godot complains every frame.
func test_an_empty_bar_does_not_collapse_its_transform() -> void:
	var bar: HealthBar3D = load(BAR_SCENE).instantiate()
	mount(bar)
	bar.set_fraction(0.0)
	assert_true(bar.fill_pivot.scale.x > 0.0)
	assert_true(bar.fill_pivot.transform.basis.determinant() != 0.0)


func test_a_nan_fraction_reads_as_empty() -> void:
	var bar: HealthBar3D = load(BAR_SCENE).instantiate()
	mount(bar)
	bar.set_fraction(sqrt(-1.0))
	assert_false(is_nan(bar.fraction()))


func test_a_low_bar_changes_colour() -> void:
	var bar: HealthBar3D = load(BAR_SCENE).instantiate()
	mount(bar)
	bar.set_fraction(1.0)
	var healthy := (bar.fill.material_override as StandardMaterial3D).albedo_color
	bar.set_fraction(0.1)
	var low := (bar.fill.material_override as StandardMaterial3D).albedo_color
	assert_ne(healthy, low)


## Recolouring one bar must not recolour every bar in the world.
func test_bars_do_not_share_a_material() -> void:
	var first: HealthBar3D = load(BAR_SCENE).instantiate()
	var second: HealthBar3D = load(BAR_SCENE).instantiate()
	mount(first)
	mount(second)
	second.set_fraction(1.0)
	var before := (second.fill.material_override as StandardMaterial3D).albedo_color
	first.set_fraction(0.05)
	var after := (second.fill.material_override as StandardMaterial3D).albedo_color
	assert_eq(before, after, "one bar recoloured another")
