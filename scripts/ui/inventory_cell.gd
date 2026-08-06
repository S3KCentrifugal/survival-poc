class_name InventoryCell
extends PanelContainer
## One slot in the inventory grid: an icon, a count, and a thing you can drag.
##
## Owns how a slot *looks* and how a mouse gets hold of it. What a drag actually
## does to the bag is [Inventory]'s decision, reached through the signals below
## -- so the rules can be tested with numbers and this file only has to be
## looked at.

## Emitted when a stack is dragged onto this cell from [param from_index].
signal received(from_index: int)

## Which slot this draws. Set once, when the grid is built.
var index: int = 0

var _icon: TextureRect
var _swatch: ColorRect
var _count: Label
var _empty: bool = true


func _init() -> void:
	custom_minimum_size = Vector2(UiTokens.SLOT_SIZE, UiTokens.SLOT_SIZE)
	# Its own StyleBox. A shared one is the trap this project has met five
	# times now: recolouring a slot would recolour every slot.
	add_theme_stylebox_override(&"panel", _style())
	# An empty slot and a full one have to be distinguishable at a glance, which
	# is what the fill difference below is for.

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)

	var frame := Control.new()
	frame.name = "Frame"
	frame.custom_minimum_size = Vector2(UiTokens.SPACE_2XL + UiTokens.SPACE_LG, UiTokens.SPACE_2XL + UiTokens.SPACE_LG)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(frame)

	# Behind the icon, and all there is when an item has no art yet.
	_swatch = ColorRect.new()
	_swatch.name = "Swatch"
	_swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_swatch)

	_icon = TextureRect.new()
	_icon.name = "Icon"
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The two that make an icon of any size look right in a cell of any size:
	# ignore the texture's own dimensions when measuring, and letterbox rather
	# than stretch. Without KEEP_ASPECT_CENTERED a tall icon is squashed into
	# the square, and without IGNORE_SIZE a 512-pixel icon makes the cell 512
	# pixels wide and the grid explodes off the screen.
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_icon)

	_count = Label.new()
	_count.name = "Count"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Outlined, because the count sits over an icon and has to stay legible on
	# whatever colour that icon happens to be.
	_count.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	_count.add_theme_constant_override(&"outline_size", UiTokens.SPACE_XS)
	_count.add_theme_font_size_override(&"font_size", UiTokens.TEXT_SMALL)
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_count)


## Draws [param slot], or empties the cell when it is null or empty.
func show_slot(slot: InventorySlot) -> void:
	_empty = slot == null or slot.is_empty()
	if _empty:
		_icon.texture = null
		_swatch.color = Color(1.0, 1.0, 1.0, 0.03)
		_count.text = ""
		tooltip_text = ""
		return

	var definition := slot.definition
	_icon.texture = definition.icon
	# Dimmed behind an icon so it reads as a backing plate, full strength when
	# it *is* the item.
	_swatch.color = (
		Color(definition.colour, 0.18) if definition.icon != null else definition.colour
	)
	# Only for things that stack. A "1" under an item you can only hold one of
	# is a number that never changes and therefore says nothing.
	_count.text = str(slot.count) if definition.stacks() else ""
	tooltip_text = "%s x%d" % [definition.display_name, slot.count]


func is_empty() -> bool:
	return _empty


## What the count reads, so a test does not have to walk the tree.
func count_text() -> String:
	return _count.text


func icon() -> Texture2D:
	return _icon.texture


## What this cell hands over when dragged, or null if there is nothing to drag.
##
## Split out from [method _get_drag_data] so it can be checked without one:
## [method Control.set_drag_preview] only means anything inside a real drag, and
## calling it outside one hands the viewport a Control that nothing ever frees.
## Which is to say a test that called _get_drag_data leaked a node, and the
## suite said so.
func drag_payload() -> Variant:
	return null if _empty else {"source": &"inventory", "index": index}


## Godot's drag API. Returning null is what stops a drag from starting at all.
func _get_drag_data(_at: Vector2) -> Variant:
	var payload: Variant = drag_payload()
	if payload != null:
		set_drag_preview(_preview())
	return payload


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return is_inventory_drag(data)


func _drop_data(_at: Vector2, data: Variant) -> void:
	if is_inventory_drag(data):
		received.emit(int((data as Dictionary).get("index", -1)))


## Whether a payload is one of ours. Everything that accepts a drop asks this,
## so a file dragged in from the desktop is not mistaken for a mushroom.
static func is_inventory_drag(data: Variant) -> bool:
	# Typed check before the cast. `data as Dictionary` on a String does not
	# return null -- it raises "Invalid cast", which a test caught by dragging
	# a string at it.
	if typeof(data) != TYPE_DICTIONARY:
		return false
	return (data as Dictionary).get("source", &"") == &"inventory"


## What follows the cursor. A copy, not the cell itself -- reparenting the real
## one leaves a hole in the grid mid-drag.
func _preview() -> Control:
	var preview := TextureRect.new()
	preview.texture = _icon.texture
	preview.custom_minimum_size = Vector2(56, 56)
	preview.size = Vector2(56, 56)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate = Color(1.0, 1.0, 1.0, 0.85)

	if _icon.texture == null:
		var swatch := ColorRect.new()
		swatch.color = _swatch.color
		swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
		preview.add_child(swatch)

	# Centred on the cursor rather than hanging off it, which is where the
	# thing you are holding belongs.
	var holder := Control.new()
	holder.add_child(preview)
	preview.position = -preview.size * 0.5
	return holder


func _style() -> StyleBoxFlat:
	return UiTokens.box(
		UiTokens.SURFACE_SUNKEN,
		UiTokens.RADIUS_SM,
		UiTokens.BORDER,
		UiTokens.BORDER_WIDTH,
		UiTokens.SPACE_XS
	)
