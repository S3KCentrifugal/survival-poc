class_name TradeOffer
extends Resource
## One thing a merchant will buy or sell, and what they will pay for it.

## Which way the goods move.
enum Direction {
	## The merchant sells; the player pays.
	SELLS,
	## The merchant buys; the player is paid.
	BUYS,
}

@export var item: ItemDefinition

@export var direction: Direction = Direction.BUYS

## Gold per unit.
@export_range(1, 100000, 1) var price: int = 1

## How many the merchant has, or will take. -1 for no limit.
##
## A limit rather than an assumption: a merchant with one sword should sell one
## sword, and a merchant who will buy mushrooms forever is a mushroom
## money-printer that nobody has to leave the first field to operate.
@export_range(-1, 9999, 1) var stock: int = -1


func is_valid() -> bool:
	return item != null and item.is_valid() and price > 0


func is_unlimited() -> bool:
	return stock < 0


## Whether there is anything left to trade at this offer.
func has_stock(amount: int = 1) -> bool:
	return is_unlimited() or stock >= amount


## Draws down the stock. Unlimited offers are unchanged.
func take_stock(amount: int) -> void:
	if not is_unlimited():
		stock = maxi(stock - amount, 0)


func label() -> String:
	if not is_valid():
		return "(broken offer)"
	var remaining := "" if is_unlimited() else "  (%d left)" % stock
	return "%s  —  %d gold%s" % [item.display_name, price, remaining]
