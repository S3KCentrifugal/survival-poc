class_name TitleScreen
extends Control
## The first thing anyone sees.
##
## Three panels behind one root: what to play, who to play it with, and the
## settings — the same settings panel the pause menu shows, instanced rather
## than rebuilt, so there is one place a graphics option is added.
##
## Settings are loaded and applied *here*, before any world exists. Someone who
## set fullscreen last session should get fullscreen at the title, not after
## they press play.

signal launching(mode: GameSession.Mode)

@export var settings_controller: SettingsController
@export var settings_menu: SettingsMenu

@export_group("Panels")
@export var main_panel: Control
@export var multiplayer_panel: Control

@export_group("Main")
@export var single_player_button: Button
@export var multiplayer_button: Button
@export var settings_button: Button
@export var exit_button: Button

@export_group("Multiplayer")
@export var host_button: Button
@export var join_button: Button
@export var multiplayer_back_button: Button
@export var address_field: LineEdit
@export var port_field: LineEdit
@export var status_label: Label


func _ready() -> void:
	if settings_controller != null:
		settings_controller.load_and_apply()

	if single_player_button != null:
		single_player_button.pressed.connect(play_single_player)
		single_player_button.grab_focus()
	if multiplayer_button != null:
		multiplayer_button.pressed.connect(show_multiplayer)
	if settings_button != null:
		settings_button.pressed.connect(show_settings)
	if exit_button != null:
		exit_button.pressed.connect(exit_game)

	if host_button != null:
		host_button.pressed.connect(host_game)
	if join_button != null:
		join_button.pressed.connect(join_game)
	if multiplayer_back_button != null:
		multiplayer_back_button.pressed.connect(show_main)

	if settings_menu != null:
		settings_menu.applied.connect(_on_settings_applied)
		settings_menu.closed.connect(show_main)

	show_main()


## Straight into the world, no socket. The default, and what most launches are.
func play_single_player() -> void:
	launching.emit(GameSession.Mode.SINGLE_PLAYER)
	SceneRouter.to_game(get_tree(), GameSession.Mode.SINGLE_PLAYER)


func host_game() -> void:
	launching.emit(GameSession.Mode.HOST)
	SceneRouter.to_game(get_tree(), GameSession.Mode.HOST, "", chosen_port())


func join_game() -> void:
	var address := chosen_address()
	if address.is_empty():
		_say("Enter an address to join.")
		return
	launching.emit(GameSession.Mode.CLIENT)
	SceneRouter.to_game(get_tree(), GameSession.Mode.CLIENT, address, chosen_port())


func exit_game() -> void:
	get_tree().quit()


func show_main() -> void:
	_show_only(main_panel)


func show_multiplayer() -> void:
	_show_only(multiplayer_panel)
	_say("Hosting holds up to %d players." % NetworkService.MAX_PLAYERS)
	if address_field != null:
		address_field.grab_focus()


func show_settings() -> void:
	if settings_menu == null:
		return
	if settings_controller != null:
		settings_menu.show_settings(settings_controller.settings())
	_show_only(settings_menu)


## What is typed in the address box, trimmed. Empty when there is none.
func chosen_address() -> String:
	return "" if address_field == null else address_field.text.strip_edges()


## The port, falling back to the default rather than refusing a blank box.
func chosen_port() -> int:
	if port_field == null:
		return NetworkService.DEFAULT_PORT
	var typed := port_field.text.strip_edges()
	if not typed.is_valid_int():
		return NetworkService.DEFAULT_PORT
	var port := typed.to_int()
	return port if port > 0 and port < 65536 else NetworkService.DEFAULT_PORT


func _on_settings_applied(new_settings: GameSettings) -> void:
	if settings_controller != null:
		settings_controller.apply(new_settings)


func _show_only(panel: Control) -> void:
	for candidate: Control in [main_panel, multiplayer_panel, settings_menu]:
		if candidate != null:
			candidate.visible = candidate == panel


func _say(text: String) -> void:
	if status_label != null:
		status_label.text = text
