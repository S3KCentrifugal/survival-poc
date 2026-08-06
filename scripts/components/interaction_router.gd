class_name InteractionRouter
extends Node
## Owns the interact key and decides what it meant.
##
## There are two kinds of thing you walk up to and press F at: something to pick
## up, and someone to trade with. Giving each its own component reading the same
## key means standing between a mushroom and a merchant picks the mushroom *and*
## opens the shop, which is not what either press meant.
##
## So one component reads the key, asks [Proximity] across both groups at once,
## and dispatches to whichever is actually nearest. The components it dispatches
## to keep their public methods -- [method PickupCollector.collect] still works
## from a console or a test -- they just no longer each watch the keyboard.
##
## The workbench is deliberately not in here. It is on E, because operating a
## fixture is a different verb from walking up to a thing, and because a bench
## you cannot mistake for a mushroom does not need disambiguating.

## Emitted when what F would act on changes, including to nothing. A prompt
## reads this rather than polling.
signal target_changed(target: Node)

## Emitted when the player hails a merchant, for a store to open on.
signal merchant_hailed(merchant: MerchantComponent)

@export var body: Node3D

## Does the picking up. Its reach is used for pickups.
@export var collector: PickupCollector

## How far a merchant can be hailed from. Wider than a pickup's reach: a person
## is bigger than a mushroom and you should not have to stand on their feet.
@export_range(0.5, 8.0, 0.1) var merchant_reach: float = 2.8

## Where intent comes from, assigned by whoever assembles the actor.
var input_source: InputSource

var _held: bool = false
var _target: Node


func _process(_delta: float) -> void:
	step()


## One tick: work out what F would do, and do it if asked.
func step() -> void:
	_set_target(find_target())
	if input_source == null:
		return

	var state := input_source.poll()
	var pressed := state.interact and not _held
	_held = state.interact
	if pressed:
		interact()


## Does whatever F would do. Returns whether anything happened.
func interact() -> bool:
	_set_target(find_target())
	if _target == null:
		return false

	var merchant := _target as MerchantComponent
	if merchant != null:
		merchant.hail(body)
		merchant_hailed.emit(merchant)
		return true

	var pickup := _target as PickupComponent
	if pickup != null and collector != null:
		return collector.collect() > 0
	return false


## The nearest thing F would act on, across both groups.
##
## The two reaches differ, so this cannot be one call to [Proximity]. Each group
## is searched at its own distance and the closer winner is taken -- a merchant
## three metres away does not beat a mushroom at your feet.
func find_target() -> Node:
	if body == null or not is_inside_tree():
		return null
	var here := body.global_position

	var pickup: Node = null
	if collector != null:
		pickup = Proximity.nearest(
			here, get_tree().get_nodes_in_group(PickupComponent.GROUP), collector.reach
		)
	var merchant := Proximity.nearest(
		here, get_tree().get_nodes_in_group(MerchantComponent.GROUP), merchant_reach
	)

	if pickup == null:
		return merchant
	if merchant == null:
		return pickup
	var to_pickup := here.distance_squared_to(pickup.call(&"world_position"))
	var to_merchant := here.distance_squared_to(merchant.call(&"world_position"))
	return pickup if to_pickup <= to_merchant else merchant


func target() -> Node:
	return _target


## What a prompt should read, or an empty string when there is nothing in reach.
func prompt_text() -> String:
	return "" if _target == null else String(_target.call(&"prompt_text"))


func _set_target(node: Node) -> void:
	if node == _target:
		return
	_target = node
	target_changed.emit(node)
