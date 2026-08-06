class_name Trade
extends RefCounted
## Moving goods and gold between two bags.
##
## Pure and static: two [Inventory] objects and an offer, no nodes. Which means
## the case that matters -- "the buyer paid and got nothing" -- is a test rather
## than a bug report from someone who lost their mushrooms.
##
## Every trade is checked in full *before* anything moves. There is no partial
## state to unwind, because there is never a partial state.

## Why a trade could not happen. Returned rather than logged, so the store can
## say it on the button instead of the player wondering.
enum Refusal {
	NONE,
	INVALID,
	NO_STOCK,
	SELLER_LACKS_GOODS,
	BUYER_CANNOT_AFFORD,
	BUYER_HAS_NO_ROOM,
	SELLER_HAS_NO_ROOM_FOR_GOLD,
}


## Whether the player can buy [param amount] at this offer, and why not.
static func check_purchase(
	player: Inventory, merchant: Inventory, offer: TradeOffer, amount: int = 1
) -> Refusal:
	if offer == null or not offer.is_valid() or amount <= 0:
		return Refusal.INVALID
	if not offer.has_stock(amount):
		return Refusal.NO_STOCK
	if merchant != null and not merchant.has(offer.item.id, amount):
		return Refusal.SELLER_LACKS_GOODS

	var price := offer.price * amount
	if not Purse.can_afford(player, price):
		return Refusal.BUYER_CANNOT_AFFORD
	# Paying can free the slot the goods land in -- spending your last coins
	# empties the gold stack. Only counted when the payment takes *all* of it,
	# which is the case that is obviously true rather than one that needs a
	# simulation of the bag to answer.
	if not _pays_out(Purse.balance(player), price) and not player.has_room_for(offer.item, amount):
		return Refusal.BUYER_HAS_NO_ROOM
	if merchant != null and not Purse.has_room(merchant, price):
		return Refusal.SELLER_HAS_NO_ROOM_FOR_GOLD
	return Refusal.NONE


## The player buys from the merchant. Returns how many changed hands.
static func purchase(
	player: Inventory, merchant: Inventory, offer: TradeOffer, amount: int = 1
) -> int:
	if check_purchase(player, merchant, offer, amount) != Refusal.NONE:
		return 0

	var price := offer.price * amount
	# Gold first, then goods. The order matters only because the payment frees
	# the room the goods land in.
	if not Purse.pay(player, price):
		return 0
	if merchant != null:
		merchant.remove(offer.item.id, amount)
		Purse.receive(merchant, price)
	offer.take_stock(amount)

	var left := player.add(offer.item, amount)
	if left > 0:
		# Should be unreachable -- check_purchase asked. If it ever happens, the
		# player is refunded rather than quietly shorted.
		Purse.receive(player, offer.price * left)
		push_warning("Purchase did not fit after payment; refunded %d" % left)
	return amount - left


## Whether the player can sell [param amount] at this offer, and why not.
static func check_sale(
	player: Inventory, merchant: Inventory, offer: TradeOffer, amount: int = 1
) -> Refusal:
	if offer == null or not offer.is_valid() or amount <= 0:
		return Refusal.INVALID
	if player == null or not player.has(offer.item.id, amount):
		return Refusal.SELLER_LACKS_GOODS

	var price := offer.price * amount
	if merchant != null and not Purse.can_afford(merchant, price):
		return Refusal.BUYER_CANNOT_AFFORD
	if merchant != null and not merchant.has_room_for(offer.item, amount):
		return Refusal.BUYER_HAS_NO_ROOM
	# Same rule the other way round: handing over the last of something frees
	# the slot the gold lands in.
	if (
		not _pays_out(player.count_of(offer.item.id), amount)
		and not Purse.has_room(player, price)
	):
		return Refusal.SELLER_HAS_NO_ROOM_FOR_GOLD
	return Refusal.NONE


## The player sells to the merchant. Returns how many changed hands.
static func sell(
	player: Inventory, merchant: Inventory, offer: TradeOffer, amount: int = 1
) -> int:
	if check_sale(player, merchant, offer, amount) != Refusal.NONE:
		return 0

	var price := offer.price * amount
	player.remove(offer.item.id, amount)
	if merchant != null:
		Purse.pay(merchant, price)
		merchant.add(offer.item, amount)
	Purse.receive(player, price)
	return amount


## Whether handing over [param amount] out of [param held] empties the stack it
## came from, and so frees a slot.
static func _pays_out(held: int, amount: int) -> bool:
	return held > 0 and held == amount


## What to put on a greyed-out button.
static func reason(refusal: Refusal) -> String:
	match refusal:
		Refusal.NONE:
			return ""
		Refusal.NO_STOCK:
			return "Sold out."
		Refusal.SELLER_LACKS_GOODS:
			return "You have none to sell."
		Refusal.BUYER_CANNOT_AFFORD:
			return "Not enough gold."
		Refusal.BUYER_HAS_NO_ROOM:
			return "No room in your bag."
		Refusal.SELLER_HAS_NO_ROOM_FOR_GOLD:
			return "No room for the gold."
		_:
			return "This offer is broken."
