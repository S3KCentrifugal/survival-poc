class_name ModalPanel
extends Node
## Everything a panel that takes over the screen has to get right.
##
## The inventory, the workbench and the shop each had their own copy of this,
## and each copy was thirty lines of visibility, cursor, input suspension and
## close-key handling. Which was fine until a bug turned up in all three at once
## and had to be fixed three times -- see devblog 038.
##
## A component the panel **holds** rather than a class it extends. The panels
## are all [CanvasLayer]s already, and inheriting from a shared one would put a
## base class where this project has none. This way a panel keeps its own
## contents, its own signals and its own reason to exist, and delegates the four
## things that are the same everywhere.

## Emitted after the panel opens, and after it closes.
signal opened
signal closed

## The panel this drives. Defaults to this component's owner.
@export var panel: CanvasLayer

## Told to give the cursor and the keyboard back. Optional, so a panel can be
## tested with no world around it.
@export var world_root: WorldRoot

## Keys that close the panel. Escape is always one of them; the rest are the
## panel's own -- I for the bag, E for the bench, F for the shop -- so the key
## that opened it also shuts it.
@export var close_keys: Array[Key] = [KEY_ESCAPE]


func _ready() -> void:
	if panel == null:
		panel = owner as CanvasLayer
	if panel == null:
		panel = get_parent() as CanvasLayer
	if panel != null:
		# Panels have to keep running once something else pauses, or a panel
		# open when the pause menu appears can never be closed.
		panel.process_mode = Node.PROCESS_MODE_ALWAYS
		panel.visible = false


## Close keys are handled in [method Node._input], and that is not a style
## choice.
##
## `_unhandled_input` is delivered in reverse tree order, and the pause menu
## happens to sit after these panels in the scene -- so Escape reached the menu
## first and opened it *over* an open shop, which could then never be closed.
## Tree order is an invisible dependency and a bad one to rest on. `_input` runs
## before all of it, and an open modal panel is exactly the thing that should
## win its own close key.
func _input(event: InputEvent) -> void:
	if panel == null or not panel.visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if close_keys.has(key.keycode):
		set_open(false)
		panel.get_viewport().set_input_as_handled()


## Opens or closes the panel, and everything that goes with it.
func set_open(open: bool) -> void:
	if panel == null or open == panel.visible:
		return
	panel.visible = open
	if world_root != null:
		world_root.set_mouse_captured(not open)
		# And the keyboard and buttons with it. Releasing only the cursor left
		# the character playable behind the panel -- harmless while the only
		# bindings were keys you would not press, and immediately visible once
		# right click became an attack.
		world_root.set_input_suspended(open)
	if open:
		opened.emit()
	else:
		closed.emit()


func is_open() -> bool:
	return panel != null and panel.visible


## Opens on [param subject], or closes when it is null.
##
## The shape every one of these panels wanted: "show me this bench" and "show me
## nothing" are the same call, so the caller does not branch.
func toggle_for(subject: Object, currently: Object) -> bool:
	var same := subject != null and subject == currently and is_open()
	set_open(subject != null and not same)
	return is_open()
