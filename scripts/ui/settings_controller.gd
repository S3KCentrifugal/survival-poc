class_name SettingsController
extends Node
## Loads, applies and saves [GameSettings], for whoever is showing them.
##
## Both the title screen and the pause menu offer settings, and both need the
## same three lines. Having them twice is having two places for the settings
## path to drift.

signal settings_applied(settings: GameSettings)

## Overridable so a test writes somewhere harmless. A suite that saves to the
## real path rewrites the settings of whoever ran it.
@export var settings_path: String = SettingsStore.DEFAULT_PATH

## Applies the two settings that belong to a camera, when there is one.
@export var camera: CameraController

var _store: SettingsStore
var _settings: GameSettings


## Reads what is on disk and makes the machine obey it.
func load_and_apply() -> GameSettings:
	_store = SettingsStore.new(settings_path)
	_settings = _store.load_settings(maxi(DisplayServer.get_screen_count(), 1))
	apply(_settings, false)
	return _settings


## The settings in force -- what was saved, not what a panel is showing.
func settings() -> GameSettings:
	if _settings == null:
		load_and_apply()
	return _settings


## Pushes settings onto the machine, optionally writing them out.
func apply(new_settings: GameSettings, save: bool = true) -> void:
	_settings = new_settings
	SettingsApplier.apply(_settings, get_window())
	SettingsApplier.apply_to_camera(_settings, camera)
	if save and _store != null:
		_store.save_settings(_settings)
	settings_applied.emit(_settings)
