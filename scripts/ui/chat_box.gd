class_name ChatBox
extends CanvasLayer
## The chat window: a log you can read and a line you can type into.
##
## Its own CanvasLayer rather than a branch of [PlayerHud], which is about
## health and stamina and should stay that way. It is still part of the
## heads-up display; it is just not part of that file.
##
## Everything it knows about messages it asks [ChatService]. What it owns is the
## keys, the focus, and the one thing that is easy to get wrong and impossible
## to miss: **the player must not walk while typing.**

signal shown
signal hidden

## Shows and hides the whole box.
@export var toggle_key: Key = KEY_F12

## Focuses the entry when the box is open and nothing has focus.
@export var focus_key: Key = KEY_ENTER

@export var service: ChatService

## Told to stop reading the keyboard as movement while the entry has focus.
@export var world_root: WorldRoot

@export var log_label: RichTextLabel
@export var entry: LineEdit
@export var scroll: ScrollContainer


func _ready() -> void:
	# Chat is not part of the simulation, and a pause menu is exactly when
	# someone types "back in a minute".
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if service != null:
		service.line_added.connect(_on_line_added)
	if entry != null:
		entry.text_submitted.connect(_on_submitted)
		entry.focus_entered.connect(_on_focus_changed)
		entry.focus_exited.connect(_on_focus_changed)
	refresh()


## Handled as *unhandled* input so the console and any focused text field get
## first refusal -- F12 typed into the dev console should reach the console.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if key.keycode == toggle_key:
		set_open(not visible)
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return

	if key.keycode == focus_key and not is_typing():
		focus_entry()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and is_typing():
		# Escape lets go of the entry rather than closing the box, so a
		# mistyped key does not throw away what is on screen. The pause menu
		# still gets Escape when nothing here wants it.
		release_entry()
		get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	if open == visible:
		return
	visible = open
	if open:
		refresh()
		shown.emit()
	else:
		release_entry()
		hidden.emit()


func is_open() -> bool:
	return visible


## Whether the entry has focus, which is the same question as "is the player
## typing rather than playing".
func is_typing() -> bool:
	return visible and entry != null and entry.has_focus()


func focus_entry() -> void:
	if entry != null:
		entry.grab_focus()


func release_entry() -> void:
	if entry != null and entry.has_focus():
		entry.release_focus()


## Says whatever is in the entry and clears it. Returns whether anything was
## said.
##
## Public and text-free so a test can send a message without synthesising a
## keystroke.
func submit() -> bool:
	if service == null or entry == null:
		return false
	var text := entry.text
	entry.text = ""
	return service.say(text)


## Redraws the log from the service.
func refresh() -> void:
	if log_label == null:
		return
	log_label.text = "" if service == null else service.chat_log().text()
	_scroll_to_end()


func _on_submitted(_text: String) -> void:
	submit()
	# Focus is kept, because the next thing anyone does after sending a message
	# is send another one.
	focus_entry()


func _on_line_added(_entry: ChatLog.Entry) -> void:
	refresh()


## The whole reason the world root is here.
##
## [PlayerInputSource] reads the keyboard directly, so without this, typing
## "we should go west" walks you west, jumps, and throws four punches. Suspended
## while the entry has focus and released the moment it does not.
func _on_focus_changed() -> void:
	if world_root != null:
		world_root.set_input_suspended(is_typing())


func _scroll_to_end() -> void:
	if scroll == null:
		return
	# Deferred: the label has not been laid out yet on the frame a line is
	# added, so its height is still the old one and scrolling to the bottom
	# lands one line short.
	await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
