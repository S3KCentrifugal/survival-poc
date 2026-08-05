class_name DamageNumbers
extends Node
## Prints what your punches are worth.
##
## Attached to the attacker rather than to the victim. The question being
## answered is "how much am *I* doing", so it belongs to whoever asked -- and it
## means a wanderer punching a wall does not litter the world with numbers
## nobody is reading.

@export var attack: AttackComponent

## The number to spawn. Optional; without one nothing is printed and nothing
## breaks.
@export var effect: PackedScene

## Where the number appears above the target's feet.
@export_range(0.0, 5.0, 0.1) var height: float = 1.9


func _ready() -> void:
	if attack == null:
		push_warning("DamageNumbers has no attack; nothing will ever be printed")
		return
	attack.hit.connect(_on_hit)


## Prints [param amount] over [param target] now.
func print_damage(target: Node3D, amount: float, killing: bool = false) -> void:
	if effect == null or target == null or not target.is_inside_tree():
		return
	# Into the world, not onto the target: the killing hit is the one you most
	# want to read, and the target is about to be freed.
	DamageNumber.pop(
		effect,
		target.get_parent(),
		target.global_position + Vector3.UP * height,
		amount,
		killing
	)


func _on_hit(target: Node3D, damage: float) -> void:
	# Read before the damage lands, so "did this finish them" is answered by
	# what is about to happen rather than by what already has.
	var health := MeleeSolver.health_of(target)
	var killing := health != null and health.current() <= damage
	print_damage(target, damage, killing)
