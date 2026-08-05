class_name Inventory
extends RefCounted
## A fixed number of slots holding stacks of items.
##
## Pure: no nodes, no signals, no scene tree. Every rule that is easy to get
## subtly wrong -- topping up a partial stack before opening a fresh one,
## overflowing across two slots, a pickup that only half fits -- is a function
## with a number coming back out of it.
##
## [InventoryComponent] owns one of these and tells the world when it changes.

## Slots, empty ones included. The count never changes: a slot that empties
## stays where it was rather than closing up, because items sliding around the
## grid whenever you use one is infuriating.
var _slots: Array[InventorySlot] = []


func _init(capacity: int = 20) -> void:
	resize(maxi(capacity, 1))


func size() -> int:
	return _slots.size()


func slot(index: int) -> InventorySlot:
	return _slots[index] if index >= 0 and index < _slots.size() else null


func slots() -> Array[InventorySlot]:
	return _slots.duplicate()


## Puts [param amount] of an item in and returns how many did **not** fit.
##
## Zero back means it all went in. The leftover is the answer a caller needs:
## a pickup that only half fits should leave the rest on the ground rather than
## deleting it, and there is no way to notice that from a bool.
func add(definition: ItemDefinition, amount: int = 1) -> int:
	if definition == null or not definition.is_valid() or amount <= 0:
		return amount

	var left := amount
	# Partial stacks first. Otherwise picking up one mushroom at a time opens a
	# new slot every time and a full bag is mostly air.
	for pass_index in 2:
		var only_partial := pass_index == 0
		for existing: InventorySlot in _slots:
			if left <= 0:
				return 0
			if only_partial and existing.is_empty():
				continue
			left -= existing.add(definition, left)
	return maxi(left, 0)


## Moves a whole stack from one slot to another.
##
## Merges when both hold the same item and there is room, swaps otherwise.
## Swapping rather than refusing is what makes a grid feel like a grid: a
## dragged stack that snaps back because the target was occupied is a UI
## arguing with you.
##
## Returns whether anything changed, so a caller knows whether to redraw.
func move_to(from: int, to: int) -> bool:
	var source := slot(from)
	var target := slot(to)
	if source == null or target == null or from == to or source.is_empty():
		return false

	if target.is_empty() or not target.accepts(source.definition):
		_swap(from, to)
		return true

	# Same item with room: pour what fits and leave the rest behind, which is
	# how a stack of 20 dropped on a stack of 15 becomes 20 and 15 rather than
	# 35 in a slot that holds 20.
	var moved := target.add(source.definition, source.count)
	if moved <= 0:
		_swap(from, to)
		return true
	source.remove(moved)
	return true


## Takes everything out of one slot and returns it as a slot of its own.
##
## The slot rather than a definition and a count, because two return values in
## GDScript is a dictionary nobody wants to read. The bag's own slot is left
## empty.
func take_all(index: int) -> InventorySlot:
	var source := slot(index)
	if source == null or source.is_empty():
		return InventorySlot.new()
	var taken := InventorySlot.new(source.definition, source.count)
	source.clear()
	return taken


## Whether every one of [param amount] would fit right now.
func has_room_for(definition: ItemDefinition, amount: int = 1) -> bool:
	if definition == null or not definition.is_valid():
		return false
	var room := 0
	for existing: InventorySlot in _slots:
		room += existing.room_for(definition)
		if room >= amount:
			return true
	return false


## Takes [param amount] of an item out and returns how many actually came.
##
## Drains the smallest stacks first, which leaves the bag tidier: half-empty
## slots get closed rather than multiplied.
func remove(id: StringName, amount: int = 1) -> int:
	var taken := 0
	for existing: InventorySlot in _sorted_holders(id):
		if taken >= amount:
			break
		taken += existing.remove(amount - taken)
	return taken


func count_of(id: StringName) -> int:
	var total := 0
	for existing: InventorySlot in _slots:
		if not existing.is_empty() and existing.definition.id == id:
			total += existing.count
	return total


func has(id: StringName, amount: int = 1) -> bool:
	return count_of(id) >= amount


func is_empty() -> bool:
	for existing: InventorySlot in _slots:
		if not existing.is_empty():
			return false
	return true


## Slots holding anything, in slot order. What a UI draws.
func filled_slots() -> Array[InventorySlot]:
	var filled: Array[InventorySlot] = []
	for existing: InventorySlot in _slots:
		if not existing.is_empty():
			filled.append(existing)
	return filled


## Grows or shrinks the bag. Shrinking discards what was in the lost slots, so
## it is not something to do to a bag someone is carrying.
func resize(capacity: int) -> void:
	var wanted := maxi(capacity, 1)
	while _slots.size() > wanted:
		_slots.pop_back()
	while _slots.size() < wanted:
		_slots.append(InventorySlot.new())


func clear() -> void:
	for existing: InventorySlot in _slots:
		existing.clear()


func _swap(from: int, to: int) -> void:
	var source := _slots[from]
	var target := _slots[to]
	var definition := source.definition
	var count := source.count
	source.definition = target.definition
	source.count = target.count
	target.definition = definition
	target.count = count


func _sorted_holders(id: StringName) -> Array[InventorySlot]:
	var holders: Array[InventorySlot] = []
	for existing: InventorySlot in _slots:
		if not existing.is_empty() and existing.definition.id == id:
			holders.append(existing)
	holders.sort_custom(func(a: InventorySlot, b: InventorySlot) -> bool: return a.count < b.count)
	return holders
