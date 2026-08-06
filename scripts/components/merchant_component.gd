class_name MerchantComponent
extends Node
## Someone who will trade with you.
##
## Carries the offers and performs them; what a trade *is* belongs to [Trade],
## and where the merchant stands belongs to the scene. The stock and the gold
## live in an ordinary [InventoryComponent] -- the same one the player has --
## so a merchant running out of coins, or out of swords, is the inventory
## system doing its job rather than a special case.

## Everyone you can walk up to and trade with is in this group.
const GROUP: StringName = &"merchant"

## Emitted when the player walks up and presses the key, for a store to open on.
signal hailed(by: Node)

## Emitted after goods change hands, either way.
signal traded(offer: TradeOffer, amount: int)

## Emitted when a trade was asked for and could not happen.
signal refused(offer: TradeOffer, reason: String)

## What this merchant will buy and sell.
##
## Duplicated on ready, so two merchants from one scene do not share a stock
## and sell each other's swords. Sixth time this project has met the
## shared-resource trap; the first time it was expected rather than discovered.
@export var offers: Array[TradeOffer] = []

## Their goods and their gold.
@export var inventory: InventoryComponent

## Where being-in-reach lives.
@export var interactable: InteractableComponent

@export var display_name: String = "Merchant"


func _ready() -> void:
	_own_the_offers()
	if interactable != null:
		interactable.interacted.connect(hail)


## Called by whoever walked up and pressed the key.
func hail(by: Node = null) -> void:
	hailed.emit(by)


## How much gold this merchant has left to pay with.
func gold() -> int:
	return 0 if inventory == null else Purse.balance(inventory.inventory())


## The player buys [param amount] at [param offer]. Returns how many they got.
func sell_to(player: InventoryComponent, offer: TradeOffer, amount: int = 1) -> int:
	return _perform(player, offer, amount, true)


## The player sells [param amount] at [param offer]. Returns how many were sold.
func buy_from(player: InventoryComponent, offer: TradeOffer, amount: int = 1) -> int:
	return _perform(player, offer, amount, false)


## Why a trade would be refused, or [constant Trade.Refusal.NONE].
func check(player: InventoryComponent, offer: TradeOffer, amount: int = 1) -> Trade.Refusal:
	if player == null or offer == null or not offers.has(offer):
		return Trade.Refusal.INVALID
	var mine := inventory.inventory() if inventory != null else null
	if offer.direction == TradeOffer.Direction.SELLS:
		return Trade.check_purchase(player.inventory(), mine, offer, amount)
	return Trade.check_sale(player.inventory(), mine, offer, amount)


func _perform(
	player: InventoryComponent, offer: TradeOffer, amount: int, buying: bool
) -> int:
	var refusal := check(player, offer, amount)
	if refusal != Trade.Refusal.NONE:
		refused.emit(offer, Trade.reason(refusal))
		return 0

	var mine := inventory.inventory() if inventory != null else null
	var moved := (
		Trade.purchase(player.inventory(), mine, offer, amount)
		if buying
		else Trade.sell(player.inventory(), mine, offer, amount)
	)
	if moved <= 0:
		refused.emit(offer, "Nothing changed hands.")
		return 0

	# Both bags changed underneath their components, so both are told.
	player.changed.emit()
	if inventory != null:
		inventory.changed.emit()
	traded.emit(offer, moved)
	return moved


## Gives this merchant its own copy of every offer.
##
## Without it, two merchants instanced from one scene share their `stock`
## counters -- buy the sword from one and the other has none either, which
## reads as the shop being broken rather than as two nodes pointing at one
## resource.
func _own_the_offers() -> void:
	var owned: Array[TradeOffer] = []
	for offer: TradeOffer in offers:
		owned.append(null if offer == null else offer.duplicate())
	offers = owned
