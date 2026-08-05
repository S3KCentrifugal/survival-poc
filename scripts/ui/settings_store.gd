class_name SettingsStore
extends RefCounted
## Reads and writes [GameSettings] to disk.
##
## Everything here is about the file being wrong: missing, truncated, from an
## older build, or edited by hand by someone who wanted 4000 FPS. A settings
## file is the one piece of state a player can reach with a text editor, and it
## must never be able to stop the game starting.

## Where settings live. `user://` is the OS's per-user application directory,
## not the project folder -- settings follow the player, not the build.
const DEFAULT_PATH: String = "user://settings.cfg"

const SECTION: String = "settings"

var path: String


func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path


## Loads settings, falling back to defaults for anything unreadable.
##
## [param screen_count] is passed through to [method GameSettings.sanitise], so
## a file written on a different desk cannot place the window on a monitor that
## is no longer there.
func load_settings(screen_count: int = 1) -> GameSettings:
	var file := ConfigFile.new()
	if file.load(path) != OK:
		var defaults := GameSettings.new()
		defaults.sanitise(screen_count)
		return defaults

	var values: Dictionary = {}
	for key: String in file.get_section_keys(SECTION) if file.has_section(SECTION) else []:
		values[key] = file.get_value(SECTION, key)

	var settings := GameSettings.from_dictionary(values)
	settings.sanitise(screen_count)
	return settings


## Writes settings, returning whether it worked.
##
## A failed write is reported rather than thrown: settings not persisting is
## annoying, and a crash on a read-only disk is worse.
func save_settings(settings: GameSettings) -> bool:
	var file := ConfigFile.new()
	for key: String in settings.to_dictionary():
		file.set_value(SECTION, key, settings.to_dictionary()[key])

	var error := file.save(path)
	if error != OK:
		push_warning("Could not save settings to %s: %s" % [path, error_string(error)])
	return error == OK


func exists() -> bool:
	return FileAccess.file_exists(path)


## Forgets everything, so the next load returns defaults. For a "reset to
## defaults" button, and for tests that must not inherit each other's state.
func clear() -> void:
	if not exists():
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
