class_name PauseMenu
extends CanvasLayer
## Escape opens this. Resume, Settings, Quit.
##
## Owns three things that have to happen together and are easy to get out of
## step: the game pauses, the cursor comes back, and the menu appears. Any one
## without the others is a bug you can feel -- a menu you cannot click, or a
## character that walks away while you read it.

signal opened
signal resumed

@export var open_key: Key = KEY_ESCAPE

## Where settings are persisted. Overridable so a test can write somewhere
## harmless -- a test suite that saves to the real path rewrites the settings of
## whoever ran it, which is a rude thing for a test to do.
@export var settings_path: String = SettingsStore.DEFAULT_PATH

## Released while the menu is open and taken back on resume.
@export var world_root: WorldRoot

## Reads settings at startup and hands them to the machine.
@export var camera: CameraController

@export var root_panel: Control
@export var settings_menu: SettingsMenu
@export var resume_button: Button
@export var settings_button: Button
@export var quit_button: Button

var _store: SettingsStore
var _settings: GameSettings


func _ready() -> void:
	# Has to keep running once it has paused everything else.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	_store = SettingsStore.new(settings_path)
	_settings = _store.load_settings(maxi(DisplayServer.get_screen_count(), 1))
	apply_settings(_settings)

	if resume_button != null:
		resume_button.pressed.connect(func() -> void: set_open(false))
	if settings_button != null:
		settings_button.pressed.connect(_show_settings)
	if quit_button != null:
		quit_button.pressed.connect(func() -> void: get_tree().quit())
	if settings_menu != null:
		settings_menu.applied.connect(_on_settings_applied)
		settings_menu.closed.connect(_show_root)
		settings_menu.visible = false


## Escape is handled as *unhandled* input on purpose. The dev console takes its
## own Escape first, so the key closes the console if one is open and only
## reaches the menu when nothing else wanted it.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != open_key:
		return
	# Inside settings, Escape steps back rather than closing everything.
	if visible and settings_menu != null and settings_menu.visible:
		_show_root()
	else:
		set_open(not visible)
	get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	visible = open
	get_tree().paused = open
	if world_root != null:
		world_root.set_mouse_captured(not open)
	if open:
		_show_root()
		opened.emit()
	else:
		resumed.emit()


## The settings in force. Saved copy, not what the panel currently shows.
func settings() -> GameSettings:
	return _settings


## Pushes [param new_settings] onto the machine and remembers them.
func apply_settings(new_settings: GameSettings) -> void:
	_settings = new_settings
	SettingsApplier.apply(_settings, get_window())
	SettingsApplier.apply_to_camera(_settings, camera)


func _on_settings_applied(new_settings: GameSettings) -> void:
	apply_settings(new_settings)
	_store.save_settings(new_settings)


func _show_settings() -> void:
	if settings_menu == null:
		return
	settings_menu.show_settings(_settings)
	settings_menu.visible = true
	if root_panel != null:
		root_panel.visible = false


func _show_root() -> void:
	if settings_menu != null:
		settings_menu.visible = false
	if root_panel != null:
		root_panel.visible = true
	if resume_button != null:
		resume_button.grab_focus()
