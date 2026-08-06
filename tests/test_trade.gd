extends TestCase
## Gold, prices, and the case that matters: nobody pays for nothing.
##
## All of it on two [Inventory] objects. Trade is a [RefCounted] with no nodes
## in it, which is why "the buyer paid and got nothing" is a test rather than a
## bug report from someone who lost their mushrooms.

const GOLD_PATH: String = "res://resources/items/gold.tres"
const MUSHROOM_PATH: String = "res://resources/items/mushroom.tres"
const SWORD_PATH: String = "res://resources/items/sword.tres"


func _offer(item_path: String, price: int, direction: TradeOffer.Direction) -> TradeOffer:
	var offer := TradeOffer.new()
	offer.item = load(item_path)
	offer.price = price
	offer.direction = direction
	return offer


func _bag(gold: int, capacity: int = 12) -> Inventory:
	var bag := Inventory.new(capacity)
	if gold > 0:
		bag.add(load(GOLD_PATH), gold)
	return bag


func test_gold_is_an_item_like_any_other() -> void:
	var gold: ItemDefinition = load(GOLD_PATH)
	assert_not_null(gold, "%s is missing or malformed" % GOLD_PATH)
	assert_true(gold.is_valid())
	assert_eq(gold.id, Purse.GOLD_ID)
	assert_true(gold.max_stack > 100, "coins would need a slot each")
	assert_true(gold.can_drop(), "gold could be carried but never put down")


func test_the_sword_exists_and_does_not_stack() -> void:
	var sword: ItemDefinition = load(SWORD_PATH)
	assert_not_null(sword)
	assert_true(sword.is_valid())
	assert_eq(sword.max_stack, 1, "a sword is not a thing you hold twenty of")
	assert_false(sword.stacks(), "the cell would show a count that never changes")


func test_a_purse_counts_what_is_in_the_bag() -> void:
	var bag := _bag(30)
	assert_eq(Purse.balance(bag), 30)
	assert_true(Purse.can_afford(bag, 30))
	assert_false(Purse.can_afford(bag, 31))


## Checked before it removes anything: a partial payment leaves the buyer poorer
## with nothing to show for it.
func test_paying_more_than_you_have_takes_nothing() -> void:
	var bag := _bag(10)
	assert_false(Purse.pay(bag, 25))
	assert_eq(Purse.balance(bag), 10, "a failed payment still took coins")


func test_paying_takes_exactly_the_price() -> void:
	var bag := _bag(50)
	assert_true(Purse.pay(bag, 18))
	assert_eq(Purse.balance(bag), 32)


func test_selling_mushrooms_pays_gold() -> void:
	var player := _bag(0)
	player.add(load(MUSHROOM_PATH), 5)
	var merchant := _bag(100)
	var offer := _offer(MUSHROOM_PATH, 2, TradeOffer.Direction.BUYS)

	assert_eq(Trade.sell(player, merchant, offer, 3), 3)
	assert_eq(player.count_of(&"mushroom"), 2, "it took the wrong number of mushrooms")
	assert_eq(Purse.balance(player), 6, "the player was paid %d" % Purse.balance(player))
	assert_eq(merchant.count_of(&"mushroom"), 3, "the merchant did not receive the goods")
	assert_eq(Purse.balance(merchant), 94, "the merchant did not pay from their own purse")


func test_you_cannot_sell_what_you_do_not_have() -> void:
	var player := _bag(0)
	var offer := _offer(MUSHROOM_PATH, 2, TradeOffer.Direction.BUYS)
	assert_eq(Trade.check_sale(player, _bag(100), offer, 1), Trade.Refusal.SELLER_LACKS_GOODS)
	assert_eq(Trade.sell(player, _bag(100), offer, 1), 0)


## The thing that stops a mushroom field being a money printer.
func test_a_merchant_cannot_pay_past_their_purse() -> void:
	var player := _bag(0)
	player.add(load(MUSHROOM_PATH), 20)
	var merchant := _bag(5)
	var offer := _offer(MUSHROOM_PATH, 2, TradeOffer.Direction.BUYS)

	assert_eq(Trade.check_sale(player, merchant, offer, 10), Trade.Refusal.BUYER_CANNOT_AFFORD)
	assert_eq(Trade.sell(player, merchant, offer, 10), 0)
	assert_eq(player.count_of(&"mushroom"), 20, "a refused sale still took the goods")


func test_buying_a_sword_costs_gold() -> void:
	var player := _bag(100)
	var merchant := _bag(0)
	merchant.add(load(SWORD_PATH), 1)
	var offer := _offer(SWORD_PATH, 60, TradeOffer.Direction.SELLS)

	assert_eq(Trade.purchase(player, merchant, offer, 1), 1)
	assert_eq(player.count_of(&"sword"), 1, "the sword did not arrive")
	assert_eq(Purse.balance(player), 40)
	assert_eq(Purse.balance(merchant), 60, "the merchant was not paid")
	assert_eq(merchant.count_of(&"sword"), 0, "the merchant kept the sword as well")


func test_you_cannot_buy_what_you_cannot_afford() -> void:
	var player := _bag(10)
	var merchant := _bag(0)
	merchant.add(load(SWORD_PATH), 1)
	var offer := _offer(SWORD_PATH, 60, TradeOffer.Direction.SELLS)

	assert_eq(Trade.check_purchase(player, merchant, offer, 1), Trade.Refusal.BUYER_CANNOT_AFFORD)
	assert_eq(Trade.purchase(player, merchant, offer, 1), 0)
	assert_eq(Purse.balance(player), 10, "a refused purchase still took the gold")
	assert_eq(merchant.count_of(&"sword"), 1, "a refused purchase still took the sword")


## A merchant with one sword sells one sword.
func test_stock_runs_out() -> void:
	var merchant := _bag(0)
	merchant.add(load(SWORD_PATH), 5)
	var offer := _offer(SWORD_PATH, 10, TradeOffer.Direction.SELLS)
	offer.stock = 1

	var player := _bag(100)
	assert_eq(Trade.purchase(player, merchant, offer, 1), 1)
	assert_eq(offer.stock, 0, "the stock was not drawn down")
	assert_eq(Trade.check_purchase(player, merchant, offer, 1), Trade.Refusal.NO_STOCK)


func test_an_unlimited_offer_never_runs_out() -> void:
	var offer := _offer(MUSHROOM_PATH, 2, TradeOffer.Direction.BUYS)
	offer.stock = -1
	assert_true(offer.is_unlimited())
	offer.take_stock(500)
	assert_true(offer.has_stock(9999), "an unlimited offer ran out")


## Spending your last coins empties the gold stack, which frees the slot the
## goods land in. Refusing that would be a rule nobody could work out.
func test_a_full_bag_still_buys_when_the_payment_frees_the_slot() -> void:
	var player := Inventory.new(1)
	player.add(load(GOLD_PATH), 60)
	var merchant := _bag(0)
	merchant.add(load(SWORD_PATH), 1)
	var offer := _offer(SWORD_PATH, 60, TradeOffer.Direction.SELLS)

	assert_false(player.has_room_for(load(SWORD_PATH), 1), "the bag is not actually full")
	assert_eq(Trade.check_purchase(player, merchant, offer, 1), Trade.Refusal.NONE)
	assert_eq(Trade.purchase(player, merchant, offer, 1), 1)
	assert_eq(player.count_of(&"sword"), 1)
	assert_eq(Purse.balance(player), 0)


## A partial trade would leave someone poorer with nothing to show for it, so
## there is no partial trade to leave.
func test_a_refused_trade_moves_nothing_at_all() -> void:
	var player := _bag(5)
	player.add(load(MUSHROOM_PATH), 1)
	var merchant := _bag(0)
	var before_player := Purse.balance(player)
	var before_merchant := Purse.balance(merchant)

	var offer := _offer(MUSHROOM_PATH, 2, TradeOffer.Direction.BUYS)
	assert_eq(Trade.sell(player, merchant, offer, 1), 0, "a broke merchant bought something")
	assert_eq(Purse.balance(player), before_player)
	assert_eq(Purse.balance(merchant), before_merchant)
	assert_eq(player.count_of(&"mushroom"), 1)


func test_an_invalid_offer_trades_nothing() -> void:
	var broken := TradeOffer.new()
	assert_false(broken.is_valid())
	assert_eq(Trade.check_sale(_bag(10), _bag(10), broken, 1), Trade.Refusal.INVALID)
	assert_eq(Trade.sell(_bag(10), _bag(10), broken, 1), 0)


func test_trading_zero_or_less_is_refused() -> void:
	var offer := _offer(MUSHROOM_PATH, 2, TradeOffer.Direction.BUYS)
	assert_eq(Trade.check_sale(_bag(0), _bag(10), offer, 0), Trade.Refusal.INVALID)
	assert_eq(Trade.check_purchase(_bag(10), _bag(10), offer, -3), Trade.Refusal.INVALID)


## Every refusal has to say something, or a greyed-out button is a mystery.
func test_every_refusal_has_a_reason() -> void:
	for refusal: int in Trade.Refusal.values():
		if refusal == Trade.Refusal.NONE:
			assert_eq(Trade.reason(refusal), "")
			continue
		assert_true(
			Trade.reason(refusal).length() > 0, "refusal %d has no message" % refusal
		)
