class_name Purse
extends RefCounted
## What an [Inventory] can pay with.
##
## Gold is an item, not a number on a character sheet. That decision costs this
## file and buys everything else for free: coins stack, show up in the bag with
## an icon, can be dropped on the ground, and are carried by merchants using the
## same component the player uses. A separate wallet would have been a second
## system with its own capacity rules, its own save format, and its own bugs.
##
## Static, because "can this bag afford that" is a question about a bag, not a
## thing that needs to be constructed.

## The one item everything is priced in.
const GOLD_ID: StringName = &"gold"


static func definition() -> ItemDefinition:
	return load("res://resources/items/gold.tres")


static func balance(inventory: Inventory) -> int:
	return 0 if inventory == null else inventory.count_of(GOLD_ID)


static func can_afford(inventory: Inventory, price: int) -> bool:
	return price <= 0 or balance(inventory) >= price


## Whether [param amount] of gold would fit. Coins stack deep, but a bag full of
## other things can still have nowhere to put them.
static func has_room(inventory: Inventory, amount: int) -> bool:
	if inventory == null or amount <= 0:
		return true
	return inventory.has_room_for(definition(), amount)


## Takes [param price] out. Returns whether it was paid in full.
##
## Checked before it removes anything: a partial payment leaves the buyer poorer
## with nothing to show for it, which is the worst outcome available here.
static func pay(inventory: Inventory, price: int) -> bool:
	if price <= 0:
		return true
	if not can_afford(inventory, price):
		return false
	return inventory.remove(GOLD_ID, price) == price


## Puts [param amount] of gold in. Returns how much did not fit.
static func receive(inventory: Inventory, amount: int) -> int:
	if inventory == null or amount <= 0:
		return 0
	return inventory.add(definition(), amount)
