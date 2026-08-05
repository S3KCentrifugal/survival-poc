class_name InventorySlot
extends RefCounted
## One stack: a kind of item and how many of it.
##
## Its own class rather than a dictionary so the invariants have somewhere to
## live -- an empty slot is one with no definition *and* no count, and it is
## impossible to end up with one but not the other.

var definition: ItemDefinition
var count: int = 0


func _init(p_definition: ItemDefinition = null, p_count: int = 0) -> void:
	definition = p_definition
	count = p_count
	if definition == null or count <= 0:
		clear()


func is_empty() -> bool:
	return definition == null or count <= 0


## Whether [param other] would stack here: the same item, with room left.
func accepts(other: ItemDefinition) -> bool:
	if other == null or not other.is_valid():
		return false
	if is_empty():
		return true
	return definition.id == other.id and count < definition.max_stack


## How many more of the current item fit. Everything, if the slot is empty.
func room_for(other: ItemDefinition) -> int:
	if not accepts(other):
		return 0
	return other.max_stack if is_empty() else definition.max_stack - count


## Puts up to [param amount] in and returns how many actually went.
func add(other: ItemDefinition, amount: int) -> int:
	var accepted := mini(maxi(amount, 0), room_for(other))
	if accepted <= 0:
		return 0
	definition = other
	count += accepted
	return accepted


## Takes up to [param amount] out and returns how many actually came.
func remove(amount: int) -> int:
	var taken := mini(maxi(amount, 0), count)
	count -= taken
	if count <= 0:
		clear()
	return taken


func clear() -> void:
	definition = null
	count = 0


func _to_string() -> String:
	return "<empty>" if is_empty() else "%s x%d" % [definition.id, count]
