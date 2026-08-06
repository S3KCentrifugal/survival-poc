class_name InventoryScreen
extends CanvasLayer
## What you are carrying, on I.
##
## Deliberately does **not** pause the game. The pause menu does, because it is
## a menu about the game; this is a screen about your character, and in
## multiplayer a bag that stops the world is a bag that cannot exist. It does
## release the cursor, because a grid you cannot click is not a grid.
##
## Drag a stack onto another slot to move it, or out of the panel entirely to
## put it on the ground. Neither rule lives here: moving is
## [method Inventory.move_to] and dropping is [ItemDropper], both reachable
## without a mouse. This file only decides which one a gesture meant.

signal opened
signal closed

## Emitted when a stack is put on the ground, for a sound later.
signal dropped(definition: ItemDefinition, amount: int)

@export var toggle_key: Key = KEY_I

@export var inventory: InventoryComponent

## Puts dragged-out stacks back in the world. Without one, dragging out of the
## panel does nothing rather than deleting what you dragged.
@export var dropper: ItemDropper

## Released while the screen is open and taken back on close. Optional, so the
## screen can be tested with no world around it.
@export var world_root: WorldRoot

@export var grid: GridContainer

## Everything outside the panel. Dropping a stack here puts it on the ground --
## which is why it has to accept drops rather than ignore the mouse.
@export var drop_zone: Control

@export var empty_label: Label
@export var title_label: Label

## Slots per row. Five by four is a bag that reads at a glance.
@export_range(1, 12, 1) var columns: int = 5

## Kept so a redraw reuses them rather than rebuilding controls every time a
## mushroom is picked.
var _cells: Array[InventoryCell] = []


func _ready() -> void:
	# Has to keep running if anything else ever pauses while this is open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if grid != null:
		grid.columns = columns
	if inventory != null:
		inventory.changed.connect(refresh)
	if drop_zone != null:
		# Forwarding rather than a script of its own: the zone has no state and
		# no behaviour beyond "a drag ended out here", and a whole file for one
		# question is a file to keep in sync.
		drop_zone.mouse_filter = Control.MOUSE_FILTER_STOP
		drop_zone.set_drag_forwarding(Callable(), _can_drop_outside, _dropped_outside)
	refresh()


## Handled as *unhandled* input, so a console or a text field takes the key
## first. Typing "inventory" into the dev console should not open the bag five
## times.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != toggle_key:
		return
	set_open(not visible)
	get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	if open == visible:
		return
	visible = open
	if world_root != null:
		world_root.set_mouse_captured(not open)
		# And the keyboard and buttons with it. Releasing only the cursor left
		# the character playable behind the panel -- harmless while the only
		# bindings were keys you would not press, and immediately visible once
		# right click became an attack.
		world_root.set_input_suspended(open)
	if open:
		refresh()
		opened.emit()
	else:
		closed.emit()


func is_open() -> bool:
	return visible


## Rebuilds every cell from the bag.
##
## Whole, not diffed. A bag holds twenty slots, and a diff between two lists of
## twenty is more code and more bugs than rebuilding them.
func refresh() -> void:
	if grid == null:
		return
	var bag := inventory.inventory() if inventory != null else Inventory.new()
	_ensure_cells(bag.size())
	for index in _cells.size():
		_cells[index].show_slot(bag.slot(index))
	if empty_label != null:
		empty_label.visible = bag.is_empty()
	if title_label != null:
		title_label.text = "Inventory"


## Moves a stack from one slot to another, merging or swapping.
##
## Public and mouse-free: this is what a drag *means*, and a test should not
## have to synthesise one to check it.
func move_stack(from: int, to: int) -> bool:
	if inventory == null:
		return false
	var moved := inventory.inventory().move_to(from, to)
	if moved:
		refresh()
	return moved


## Puts the whole of one slot on the ground. Returns how many were dropped.
##
## Nothing leaves the bag until the item is standing in the world. A stack
## removed first and then failed to spawn is a stack that no longer exists
## anywhere.
func drop_to_world(index: int) -> int:
	if inventory == null or dropper == null:
		return 0
	var bag := inventory.inventory()
	var slot := bag.slot(index)
	if slot == null or slot.is_empty() or not slot.definition.can_drop():
		return 0

	var definition := slot.definition
	var amount := slot.count
	if dropper.drop(definition, amount) == null:
		return 0

	bag.take_all(index)
	refresh()
	dropped.emit(definition, amount)
	return amount


## What a cell's count reads, so a test does not have to walk the tree.
func cell_text(index: int) -> String:
	return "" if index < 0 or index >= _cells.size() else _cells[index].count_text()


func cell(index: int) -> InventoryCell:
	return null if index < 0 or index >= _cells.size() else _cells[index]


func cell_count() -> int:
	return _cells.size()


func _ensure_cells(wanted: int) -> void:
	while _cells.size() > wanted:
		var extra: InventoryCell = _cells.pop_back()
		grid.remove_child(extra)
		extra.queue_free()
	while _cells.size() < wanted:
		var cell_node := InventoryCell.new()
		cell_node.index = _cells.size()
		cell_node.received.connect(_on_cell_received.bind(cell_node.index))
		grid.add_child(cell_node)
		_cells.append(cell_node)


func _on_cell_received(from_index: int, to_index: int) -> void:
	move_stack(from_index, to_index)


func _can_drop_outside(_at: Vector2, data: Variant) -> bool:
	if not InventoryCell.is_inventory_drag(data) or inventory == null or dropper == null:
		return false
	var slot := inventory.inventory().slot(int((data as Dictionary).get("index", -1)))
	# Refuses rather than accepting and doing nothing, so the cursor says no to
	# an item with no world form instead of swallowing it.
	return slot != null and not slot.is_empty() and slot.definition.can_drop()


func _dropped_outside(_at: Vector2, data: Variant) -> void:
	if InventoryCell.is_inventory_drag(data):
		drop_to_world(int((data as Dictionary).get("index", -1)))
