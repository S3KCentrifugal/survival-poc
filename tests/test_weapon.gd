extends TestCase
## Carrying a sword, holding it, and hitting harder with it.

const PLAYER: String = "res://characters/player.tscn"
const MAIN_SCENE: String = "res://scenes/main.tscn"


func _sword() -> ItemDefinition:
	return load("res://resources/items/sword.tres")


func _weapon_of(actor: Node) -> WeaponComponent:
	for node: Node in actor.find_children("*", "Node", true, false):
		if node is WeaponComponent:
			return node as WeaponComponent
	return null


func test_the_committed_sword_is_a_sane_weapon() -> void:
	var weapon: WeaponDefinition = load("res://resources/weapons/sword.tres")
	var problems := weapon.problems()
	assert_true(problems.is_empty(), ", ".join(problems))
	assert_eq(weapon.item_id, &"sword")


func test_a_weapon_that_changes_nothing_is_refused() -> void:
	# Decoration, not a weapon -- and a sword that hits no harder than a fist is
	# a thing nobody would buy.
	var weapon := WeaponDefinition.new()
	weapon.item_id = &"stick"
	weapon.held_scene = load("res://items/sword_held.tscn")
	assert_false(weapon.problems().is_empty())


func test_the_grip_is_built_from_degrees_rather_than_a_hand_written_basis() -> void:
	var weapon := WeaponDefinition.new()
	weapon.grip_rotation = Vector3(-90.0, 0.0, 0.0)
	weapon.grip_scale = 2.0
	var grip := weapon.grip_transform()
	# The blade lies along +Z in the sword's own scene. -90 about X turns it onto
	# the grip's +Y -- which is the hand bone's axis, pointing away from the
	# elbow, so the blade runs down the fist rather than out of the wrist.
	assert_true(grip.basis.z.normalized().is_equal_approx(Vector3.UP))
	assert_true(absf(grip.basis.get_scale().x - 2.0) < 0.01)


# --- Holding it ---------------------------------------------------------------

func test_the_player_holds_nothing_to_begin_with() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	assert_not_null(weapon, "the player cannot hold anything")
	assert_null(weapon.wielding())
	assert_null(weapon.held())


## Carry a sword and you are holding it. There is no equip screen because there
## is one weapon, and a screen for it would be a screen with one button.
func test_picking_up_a_sword_puts_it_in_the_hand() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	weapon.inventory.collect(_sword(), 1)

	assert_not_null(weapon.wielding(), "carrying a sword did not draw it")
	assert_eq(weapon.wielding().item_id, &"sword")
	assert_not_null(weapon.held(), "nothing was put in the hand")
	assert_eq(weapon.held().get_parent(), weapon.grip)


func test_dropping_it_takes_it_out_of_the_hand() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	weapon.inventory.collect(_sword(), 1)
	weapon.inventory.drop(&"sword", 1)

	assert_null(weapon.wielding())
	assert_null(weapon.held(), "the sword is still in the hand after being dropped")


## The failure a naive "instantiate on pick-up" would have: two swords in one
## fist, and only one of them ever removed.
func test_it_does_not_stack_a_second_sword_over_the_first() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	weapon.inventory.collect(_sword(), 1)
	var first := weapon.held()
	weapon.refresh()
	weapon.refresh()

	assert_eq(weapon.held(), first, "the hand was rebuilt for no reason")
	assert_eq(weapon.grip.get_child_count(), 1, "there are %d things in the hand" % weapon.grip.get_child_count())


## It hangs off the hand bone, so the existing attack clip swings it without a
## frame of new animation being authored.
func test_the_grip_follows_the_hand_bone() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var grip := _weapon_of(actor).grip as BoneAttachment3D
	assert_not_null(grip, "the grip is not attached to a bone")
	assert_eq(grip.bone_name, "hand.R")


func test_a_held_sword_carries_no_pickup_to_interact_with() -> void:
	# Otherwise the prompt offers to pick up the thing already in your hand.
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	weapon.inventory.collect(_sword(), 1)
	for node: Node in weapon.held().find_children("*", "Node", true, false):
		assert_false(node is InteractableComponent, "the held sword can be picked up")


# --- Hitting with it ----------------------------------------------------------

func test_a_sword_hits_harder_than_a_fist() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	var attack := weapon.attack
	assert_eq(attack.bonus_damage, 0.0)

	weapon.inventory.collect(_sword(), 1)
	assert_true(attack.bonus_damage > 0.0, "the sword does nothing in a fight")
	assert_true(attack.bonus_heavy_damage > 0.0)
	assert_true(attack.bonus_reach > 0.0, "a sword that reaches no further than an arm")


func test_dropping_it_takes_the_damage_back() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	weapon.inventory.collect(_sword(), 1)
	weapon.inventory.drop(&"sword", 1)
	assert_eq(weapon.attack.bonus_damage, 0.0, "the damage outlived the weapon")
	assert_eq(weapon.attack.bonus_reach, 0.0)


## The attack's config is a `.tres` shared by every actor that uses it. Writing
## a sword's damage into it would arm every wanderer in the world -- the
## resource-cache trap, and exactly the shape of mistake a weapon system invites.
func test_arming_the_player_does_not_arm_everything_else() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var weapon := _weapon_of(world.get_node("Player"))
	var before: float = (load("res://resources/attack/player_attack.tres") as AttackConfig).damage

	weapon.inventory.collect(_sword(), 1)

	var after: float = (load("res://resources/attack/player_attack.tres") as AttackConfig).damage
	assert_eq(after, before, "the shared attack config was edited")


func test_the_reach_bonus_widens_the_swing() -> void:
	var actor: Node = mount(load(PLAYER).instantiate())
	var weapon := _weapon_of(actor)
	var attack := weapon.attack
	# Asserted through the component rather than by counting hits, because what
	# is in range needs a physics frame and a target; that the number reaches
	# the query is the part that can go wrong silently.
	weapon.inventory.collect(_sword(), 1)
	assert_true(attack.bonus_reach > 0.0)
	assert_true(attack.config.reach + attack.bonus_reach > attack.config.reach)


## The AI keep their fists. Nothing else in the world has a WeaponComponent, so
## nothing else can quietly acquire a sword.
func test_nothing_else_can_hold_a_weapon() -> void:
	for path: String in [
		"res://characters/companion.tscn",
		"res://characters/wanderer.tscn",
		"res://characters/merchant.tscn",
	]:
		var actor: Node = mount(load(path).instantiate())
		assert_null(_weapon_of(actor), "%s can wield a sword" % path)
