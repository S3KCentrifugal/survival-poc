extends TestCase
## The merchants in the world: that they are findable, that they look different
## from the wanderers, and that F opens a shop rather than picking up a mushroom.

const MAIN_SCENE: String = "res://scenes/main.tscn"
const MERCHANT_SCENE: String = "res://characters/merchant.tscn"
const MUSHROOM_PATH: String = "res://resources/items/mushroom.tres"
const GOLD_PATH: String = "res://resources/items/gold.tres"


func _merchant_at(where: Vector3) -> MerchantComponent:
	var actor: Node3D = load(MERCHANT_SCENE).instantiate()
	mount(actor)
	actor.global_position = where
	var merchant: MerchantComponent = actor.get_node("Merchant")
	(actor.get_node("Stock") as InventoryComponent).collect(load(GOLD_PATH), 400)
	return merchant


func _bag(mushrooms: int, gold: int) -> InventoryComponent:
	var inventory := InventoryComponent.new()
	mount(inventory)
	if mushrooms > 0:
		inventory.collect(load(MUSHROOM_PATH), mushrooms)
	if gold > 0:
		inventory.collect(load(GOLD_PATH), gold)
	return inventory


func test_the_merchant_scene_is_assembled() -> void:
	var merchant := _merchant_at(Vector3.ZERO)
	assert_not_null(merchant.inventory, "the merchant has nowhere to keep stock or gold")
	assert_true(merchant.offers.size() >= 2, "the merchant trades in %d things" % merchant.offers.size())
	assert_true(merchant.is_in_group(MerchantComponent.GROUP), "nothing will ever find them")
	assert_true(merchant.is_available())


## "Distinct from other wandering characters" is the ask, and it is not met by
## a component nobody can see.
func test_a_merchant_looks_different_from_a_wanderer() -> void:
	var actor: Node3D = load(MERCHANT_SCENE).instantiate()
	mount(actor)

	assert_not_null(actor.get_node_or_null("Nameplate"), "there is no nameplate")
	assert_eq((actor.get_node("Nameplate") as Label3D).text, "Merchant")
	assert_not_null(actor.get_node_or_null("HatBrim"), "there is no hat")

	var tint: ModelTint = actor.get_node_or_null("Tint")
	assert_not_null(tint, "the merchant is the same colour as everyone else")
	assert_true(tint.painted_count() > 0, "the tint found no meshes, so it painted nothing")


## An overlay, not an override: an override replaces the model's materials and
## turns a textured robot into a flat silhouette.
func test_the_tint_is_an_overlay_that_keeps_the_model_visible() -> void:
	var actor: Node3D = load(MERCHANT_SCENE).instantiate()
	mount(actor)
	var tint: ModelTint = actor.get_node("Tint")

	assert_true(tint.tint.a < 1.0, "an opaque tint hides the character underneath")
	var meshes := ModelTint._meshes(tint.model)
	assert_true(meshes.size() > 0)
	for mesh: MeshInstance3D in meshes:
		assert_not_null(mesh.material_overlay, "a mesh was left untinted")
		assert_null(mesh.material_override, "the tint replaced the model's own materials")


## A merchant who walks off while you read their prices is one you stop
## visiting.
func test_merchants_do_not_wander() -> void:
	var actor: Node3D = load(MERCHANT_SCENE).instantiate()
	mount(actor)
	assert_null(actor.get_node_or_null("Wander"), "the merchant wanders off")
	assert_null(actor.get_node_or_null("Movement"), "the merchant can be moved")


## Two merchants from one scene must not share a stock counter -- buy the sword
## from one and the other having none reads as the shop being broken.
func test_two_merchants_do_not_share_their_stock() -> void:
	var first := _merchant_at(Vector3.ZERO)
	var second := _merchant_at(Vector3(20.0, 0.0, 0.0))

	var sword_offer: TradeOffer = null
	for offer: TradeOffer in first.offers:
		if offer.direction == TradeOffer.Direction.SELLS:
			sword_offer = offer
	assert_not_null(sword_offer, "the merchant sells nothing")

	var before := sword_offer.stock
	sword_offer.take_stock(1)
	var other := second.offers[first.offers.find(sword_offer)]
	assert_eq(other.stock, before, "both merchants are reading one stock counter")


func test_selling_mushrooms_through_the_merchant() -> void:
	var merchant := _merchant_at(Vector3.ZERO)
	var bag := _bag(6, 0)
	var offer: TradeOffer = null
	for candidate: TradeOffer in merchant.offers:
		if candidate.item.id == &"mushroom":
			offer = candidate

	assert_eq(merchant.buy_from(bag, offer, 3), 3)
	assert_eq(bag.count_of(&"mushroom"), 3)
	assert_eq(bag.count_of(&"gold"), offer.price * 3)
	assert_true(merchant.gold() < 400, "the merchant paid with somebody else's money")


func test_buying_the_sword_through_the_merchant() -> void:
	var merchant := _merchant_at(Vector3.ZERO)
	merchant.inventory.collect(load("res://resources/items/sword.tres"), 2)
	var bag := _bag(0, 200)
	var offer: TradeOffer = null
	for candidate: TradeOffer in merchant.offers:
		if candidate.direction == TradeOffer.Direction.SELLS:
			offer = candidate

	assert_eq(merchant.sell_to(bag, offer, 1), 1)
	assert_eq(bag.count_of(&"sword"), 1)
	assert_eq(bag.count_of(&"gold"), 200 - offer.price)


## It should say why rather than doing nothing, which is indistinguishable from
## being broken.
func test_the_merchant_says_why_it_refused() -> void:
	var merchant := _merchant_at(Vector3.ZERO)
	var reasons: Array[String] = []
	merchant.refused.connect(func(_o: TradeOffer, why: String) -> void: reasons.append(why))

	var offer: TradeOffer = merchant.offers[0]
	assert_eq(merchant.buy_from(_bag(0, 0), offer, 1), 0)
	assert_eq(reasons.size(), 1, "it refused silently")
	assert_true(reasons[0].length() > 0)


func test_a_merchant_will_not_trade_an_offer_it_does_not_have() -> void:
	var merchant := _merchant_at(Vector3.ZERO)
	var foreign := TradeOffer.new()
	foreign.item = load(MUSHROOM_PATH)
	foreign.price = 9999
	assert_eq(merchant.check(_bag(9, 0), foreign, 1), Trade.Refusal.INVALID)
	assert_eq(merchant.buy_from(_bag(9, 0), foreign, 1), 0)


func _world() -> Node:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	return world


func test_the_world_has_merchants_standing_on_the_ground() -> void:
	var world := _world()
	var post: MerchantPost = world.get_node_or_null("Merchants")
	assert_not_null(post, "there are no merchants in the world")
	assert_true(post.count() >= 2, "only %d merchant in the world" % post.count())

	var terrain: Terrain = world.get_node("Terrain")
	for merchant: Node3D in post.merchants():
		var ground := terrain.height_at_world(merchant.global_position)
		assert_true(
			absf(merchant.global_position.y - ground) < 0.3,
			"a merchant stands %.1f m off the ground" % (merchant.global_position.y - ground)
		)


func test_the_merchants_have_gold_and_stock_to_trade_with() -> void:
	var post: MerchantPost = _world().get_node("Merchants")
	for actor: Node3D in post.merchants():
		var merchant: MerchantComponent = actor.get_node("Merchant")
		assert_true(merchant.gold() > 0, "a merchant has no money to buy anything with")
		assert_true(
			merchant.inventory.count_of(&"sword") > 0, "a merchant has no swords to sell"
		)


func test_the_store_is_wired_to_the_router() -> void:
	var world := _world()
	var store: StoreScreen = world.get_node_or_null("StoreScreen")
	assert_not_null(store, "there is no store screen")
	assert_eq(store.inventory, world.get_node("Player/Inventory"))
	assert_eq(store.router, world.get_node("Player/Router"), "nothing would open it")
	assert_false(store.is_open(), "the store was open before anyone hailed anyone")


func _press_interact(router: InteractionRouter) -> void:
	var source: ScriptedInputSource = router.input_source
	source.interact(false)
	router.step()
	source.interact(true)
	router.step()


func test_pressing_the_key_at_a_merchant_opens_the_store() -> void:
	var world := _world()
	var store: StoreScreen = world.get_node("StoreScreen")
	var router: InteractionRouter = world.get_node("Player/Router")
	router.input_source = ScriptedInputSource.new()

	# Every pickup removed first. The world is full of mushrooms and the router
	# correctly prefers whichever is nearest, so leaving them in makes this a
	# test of where the patch happened to sprout. Which is worth knowing, and is
	# what the two priority tests below are for.
	for pickup: Node in world.get_tree().get_nodes_in_group(PickupComponent.GROUP):
		pickup.get_parent().free()

	var actor: Node3D = (world.get_node("Merchants") as MerchantPost).merchants()[0]
	(world.get_node("Player") as Node3D).global_position = (
		actor.global_position + Vector3(1.2, 0.0, 0.0)
	)

	_press_interact(router)
	assert_true(store.is_open(), "the store did not open")
	assert_eq(store.merchant(), actor.get_node("Merchant"))
	assert_true(store.offer_count() >= 2, "the store showed %d offers" % store.offer_count())


## One key, one owner. Two components each watching F means standing between a
## mushroom and a merchant does both.
func test_a_mushroom_at_your_feet_beats_a_merchant_further_away() -> void:
	var world := _world()
	var router: InteractionRouter = world.get_node("Player/Router")
	var actor: Node3D = (world.get_node("Merchants") as MerchantPost).merchants()[0]
	var player: Node3D = world.get_node("Player")
	player.global_position = actor.global_position + Vector3(2.0, 0.0, 0.0)

	var mushroom: Node3D = load("res://items/mushroom.tscn").instantiate()
	world.add_child(mushroom)
	mushroom.global_position = player.global_position + Vector3(0.3, 0.0, 0.0)

	assert_true(router.find_target() is PickupComponent, "the merchant won at two metres")


func test_a_merchant_beats_a_mushroom_further_away() -> void:
	var world := _world()
	var router: InteractionRouter = world.get_node("Player/Router")
	var actor: Node3D = (world.get_node("Merchants") as MerchantPost).merchants()[0]
	var player: Node3D = world.get_node("Player")
	player.global_position = actor.global_position + Vector3(0.9, 0.0, 0.0)

	var mushroom: Node3D = load("res://items/mushroom.tscn").instantiate()
	world.add_child(mushroom)
	mushroom.global_position = player.global_position + Vector3(1.6, 0.0, 0.0)

	assert_true(router.find_target() is MerchantComponent, "the mushroom won at 1.6 metres")


func test_the_store_does_not_pause_the_game() -> void:
	var world := _world()
	var store: StoreScreen = world.get_node("StoreScreen")
	store.show_merchant((world.get_node("Merchants") as MerchantPost).merchants()[0].get_node("Merchant"))
	assert_false((Engine.get_main_loop() as SceneTree).paused, "the shop paused the world")
	store.set_open(false)


## The whole loop, in the assembled world: mushrooms in, gold out, sword bought.
func test_selling_mushrooms_then_buying_a_sword() -> void:
	var world := _world()
	var store: StoreScreen = world.get_node("StoreScreen")
	var inventory: InventoryComponent = world.get_node("Player/Inventory")
	inventory.collect(load(MUSHROOM_PATH), 20)

	var merchant: MerchantComponent = (
		(world.get_node("Merchants") as MerchantPost).merchants()[0].get_node("Merchant")
	)
	store.show_merchant(merchant)

	var sold := 0
	for index in store.offer_count():
		if store._offers[index].item.id == &"mushroom":
			for _repeat in 20:
				sold += store.trade(index)
	assert_eq(sold, 20, "sold %d of twenty mushrooms" % sold)
	assert_true(inventory.count_of(&"gold") > 0, "selling produced no gold")

	# Top the purse up rather than grinding mushrooms; the sale is proved above.
	inventory.collect(load(GOLD_PATH), 200)
	for index in store.offer_count():
		if store._offers[index].direction == TradeOffer.Direction.SELLS:
			store.trade(index)
	assert_eq(inventory.count_of(&"sword"), 1, "the sword was not bought")


## The prompt has to come from whoever owns the key. Asking the collector means
## it can never say "Trade with Merchant" however close you stand.
func test_the_hud_says_when_a_merchant_is_in_reach() -> void:
	var world := _world()
	var hud: PlayerHud = world.get_node("PlayerHud")
	assert_eq(hud.router, world.get_node("Player/Router"), "the HUD cannot see merchants")

	for pickup: Node in world.get_tree().get_nodes_in_group(PickupComponent.GROUP):
		pickup.get_parent().free()

	var actor: Node3D = (world.get_node("Merchants") as MerchantPost).merchants()[0]
	(world.get_node("Player") as Node3D).global_position = (
		actor.global_position + Vector3(1.0, 0.0, 0.0)
	)
	(world.get_node("Player/Router") as InteractionRouter).step()

	assert_true(hud.prompt_label.visible, "standing at a merchant showed no prompt")
	assert_true(
		hud.prompt_label.text.contains("Trade with"),
		"the prompt reads '%s'" % hud.prompt_label.text
	)


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


## Reported: the shop could not be closed. Escape opened the pause menu *over*
## it and F did nothing.
##
## Escape reaches `_unhandled_input` in reverse tree order, and the pause menu
## sits after the store, so the menu won and the shop stayed open behind it.
func test_escape_closes_the_shop_without_opening_the_pause_menu() -> void:
	var world := _world()
	var store: StoreScreen = world.get_node("StoreScreen")
	var pause: PauseMenu = world.get_node("PauseMenu")
	store.show_merchant((world.get_node("Merchants") as MerchantPost).merchants()[0].get_node("Merchant"))

	world.get_tree().root.push_input(_key(KEY_ESCAPE))

	assert_false(store.is_open(), "escape did not close the shop")
	assert_false(pause.visible, "escape opened the pause menu over the shop")
	assert_false((Engine.get_main_loop() as SceneTree).paused, "the world was left paused")


func test_the_interact_key_closes_the_shop() -> void:
	var world := _world()
	var store: StoreScreen = world.get_node("StoreScreen")
	store.show_merchant((world.get_node("Merchants") as MerchantPost).merchants()[0].get_node("Merchant"))

	world.get_tree().root.push_input(_key(KEY_F))
	assert_false(store.is_open(), "F did not close the shop")


## The other half of the same report, and the harder half.
##
## Opening a panel suspends gameplay input, and a suspended source reports every
## button as released -- so the F still being held read as a brand new press the
## moment the panel closed and unsuspended, reopening it. The shop was
## uncloseable for as long as the key was down.
func test_a_key_held_through_a_panel_is_not_a_fresh_press_afterwards() -> void:
	var source := PlayerInputSource.new()
	source.suspended = true
	source.suspended = false

	# Nothing is physically held in a headless test, so the swallow list is the
	# thing to assert on: it is what a real held key would populate.
	assert_false(
		source.is_swallowing(PlayerInputSource.ACTION_INTERACT),
		"it swallowed a key that was never down"
	)


func test_resuming_swallows_the_edge_actions_that_are_still_held() -> void:
	var source := PlayerInputSource.new()
	for action: StringName in PlayerInputSource.EDGE_ACTIONS:
		Input.action_press(action)
	source.suspended = true
	source.suspended = false

	for action: StringName in PlayerInputSource.EDGE_ACTIONS:
		assert_true(source.is_swallowing(action), "%s was not swallowed" % action)
	var state := source.poll()
	assert_false(state.interact, "a held key read as a press right after resuming")
	assert_false(state.jump)
	assert_false(state.attack)
	assert_false(state.heavy_attack)
	assert_false(state.use)

	for action: StringName in PlayerInputSource.EDGE_ACTIONS:
		Input.action_release(action)
	source.poll()
	for action: StringName in PlayerInputSource.EDGE_ACTIONS:
		assert_false(source.is_swallowing(action), "%s never came back" % action)


## Movement is asked "are you held", not "were you pressed", so continuing to
## walk when a panel closes is correct -- swallowing it would strand the player
## until they let go of W.
func test_movement_is_not_swallowed() -> void:
	var source := PlayerInputSource.new()
	Input.action_press(PlayerInputSource.ACTION_MOVE_FORWARD)
	source.suspended = true
	source.suspended = false

	assert_true(source.poll().is_moving(), "the player was stranded until they let go")
	Input.action_release(PlayerInputSource.ACTION_MOVE_FORWARD)
