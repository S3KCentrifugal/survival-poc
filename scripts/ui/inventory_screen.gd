class_name InventoryScreen
extends CanvasLayer
## What you are carrying, on I.
##
## Deliberately does **not** pause the game. The pause menu does, because it is
## a menu about the game; this is a screen about your character, and in
## multiplayer a bag that stops the world is a bag that cannot exist. It does
## release the cursor, because a grid you cannot click is not a grid.
##
## Redrawn whole on every change. A bag holds twenty slots, and a diff between
## two lists of twenty is more code and more bugs than rebuilding them.

signal opened
signal closed

@export var toggle_key: Key = KEY_I

@export var inventory: InventoryComponent

## Released while the screen is open and taken back on close. Optional, so the
## screen can be tested with no world around it.
@export var world_root: WorldRoot

@export var grid: GridContainer
@export var empty_label: Label
@export var title_label: Label

## Slots per row. Five by four is a bag that reads at a glance.
@export_range(1, 12, 1) var columns: int = 5

## Kept so a redraw can reuse them rather than rebuilding controls every time
## a mushroom is picked.
var _cells: Array[PanelContainer] = []


func _ready() -> void:
	# Has to keep running if anything else ever pauses while this is open.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if grid != null:
		grid.columns = columns
	if inventory != null:
		inventory.changed.connect(refresh)
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
	if open:
		refresh()
		opened.emit()
	else:
		closed.emit()


func is_open() -> bool:
	return visible


## Rebuilds every cell from the bag.
func refresh() -> void:
	if grid == null:
		return
	var bag := inventory.inventory() if inventory != null else Inventory.new()
	_ensure_cells(bag.size())

	for index in _cells.size():
		_draw_cell(index, bag.slot(index))

	if empty_label != null:
		empty_label.visible = bag.is_empty()
	if title_label != null:
		title_label.text = "Inventory"


## What a cell shows, so a test can read it back without walking the tree.
func cell_text(index: int) -> String:
	if index < 0 or index >= _cells.size():
		return ""
	var label := _cells[index].get_node_or_null("Stack/Count") as Label
	return "" if label == null else label.text


func cell_count() -> int:
	return _cells.size()


func _ensure_cells(wanted: int) -> void:
	while _cells.size() > wanted:
		var extra: PanelContainer = _cells.pop_back()
		grid.remove_child(extra)
		extra.queue_free()
	while _cells.size() < wanted:
		_cells.append(_build_cell())


func _build_cell() -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(84, 84)
	# Its own StyleBox per cell. A shared one is the trap this project has met
	# four times: recolouring a slot would recolour every slot.
	cell.add_theme_stylebox_override(&"panel", _empty_style())

	var swatch := ColorRect.new()
	swatch.name = "Swatch"
	swatch.custom_minimum_size = Vector2(40, 40)
	swatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = Color.TRANSPARENT

	var count := Label.new()
	count.name = "Count"
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_child(swatch)
	stack.add_child(count)
	cell.add_child(stack)
	grid.add_child(cell)
	return cell


func _draw_cell(index: int, slot: InventorySlot) -> void:
	var cell := _cells[index]
	var swatch := cell.get_node_or_null("Stack/Swatch") as ColorRect
	var count := cell.get_node_or_null("Stack/Count") as Label
	var filled := slot != null and not slot.is_empty()

	if swatch != null:
		swatch.color = slot.definition.colour if filled else Color(1.0, 1.0, 1.0, 0.05)
	if count != null:
		# The count alone. A name in an 84-pixel cell is three characters and an
		# ellipsis, which tells you less than the colour already did.
		count.text = str(slot.count) if filled and slot.count > 1 else ("1" if filled else "")
	cell.tooltip_text = "" if not filled else "%s x%d" % [slot.definition.display_name, slot.count]


func _empty_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.14, 0.16, 0.9)
	style.border_color = Color(0.3, 0.33, 0.37)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style
