class_name WeaponComponent
extends Node
## Puts whatever you are carrying into your hand, and makes it count.
##
## Two jobs that are really one: a sword you can see and a sword that hurts more
## have to agree, or the game is lying about something. Both are driven off the
## inventory -- carry a sword and you are holding it. There is no equip screen,
## because there is one weapon.
##
## Reads the inventory it was given and writes to the attack it was given.
## Neither goes looking for the other, and neither knows this exists.

## Emitted when what is in the hand changes. Null means empty-handed.
signal wielded(weapon: WeaponDefinition)

## Where the weapon appears. A [BoneAttachment3D] on the hand bone, so the
## existing attack animation swings it without a single frame of new animation.
@export var grip: Node3D

## What is being carried.
@export var inventory: InventoryComponent

## What the bonuses are pushed onto.
@export var attack: AttackComponent

## Everything this actor knows how to wield, best last -- ties are broken by
## taking the later one, so the order in the scene is the preference order.
@export var weapons: Array[WeaponDefinition] = []

var _wielded: WeaponDefinition
var _held: Node3D


func _ready() -> void:
	if inventory != null:
		inventory.changed.connect(refresh)
	refresh()


## Works out what should be in the hand and puts it there.
##
## Public so a test needs no signal, and idempotent -- calling it twice does not
## stack a second sword over the first, which is the failure a naive
## "instantiate on pick-up" would have.
func refresh() -> void:
	var best := best_available()
	if best == _wielded:
		return
	_wielded = best
	_show(best)
	_apply_bonuses(best)
	wielded.emit(best)


## The best weapon currently carried, or null.
##
## Pure enough to test: give it an inventory with a sword in it and it says
## sword. The whole decision, in one place, rather than spread across whatever
## called `collect()`.
func best_available() -> WeaponDefinition:
	if inventory == null:
		return null
	var best: WeaponDefinition = null
	for weapon: WeaponDefinition in weapons:
		if weapon != null and inventory.count_of(weapon.item_id) > 0:
			best = weapon
	return best


## What is in the hand right now.
func wielding() -> WeaponDefinition:
	return _wielded


## The instantiated geometry, so a test can check something is actually there.
func held() -> Node3D:
	return _held


func _show(weapon: WeaponDefinition) -> void:
	if is_instance_valid(_held):
		_held.queue_free()
	_held = null
	if weapon == null or weapon.held_scene == null or grip == null:
		return
	_held = weapon.held_scene.instantiate() as Node3D
	grip.add_child(_held)
	# Set after adding, or it is a transform on a node with no parent to be
	# relative to.
	_held.transform = weapon.grip_transform()


## Pushes the weapon's numbers onto the attack.
##
## The attack's own [AttackConfig] is never touched. It is a `.tres` shared by
## every actor that uses it, so writing a sword's damage into it would arm every
## wanderer in the world -- the resource-cache trap, which this project has hit
## four times and which is exactly the shape of mistake a weapon system invites.
func _apply_bonuses(weapon: WeaponDefinition) -> void:
	if attack == null:
		return
	attack.bonus_damage = weapon.damage_bonus if weapon != null else 0.0
	attack.bonus_heavy_damage = weapon.heavy_damage_bonus if weapon != null else 0.0
	attack.bonus_reach = weapon.reach_bonus if weapon != null else 0.0
