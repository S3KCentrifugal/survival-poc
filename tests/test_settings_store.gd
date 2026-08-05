extends TestCase
## Persistence, and every way the file on disk can be wrong.

const TEST_PATH: String = "user://test_settings.cfg"

var _store: SettingsStore


func before_each() -> void:
	_store = SettingsStore.new(TEST_PATH)
	_store.clear()


func after_each() -> void:
	_store.clear()


func _write_raw(text: String) -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_settings_survive_being_written_and_read_back() -> void:
	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.BORDERLESS
	settings.resolution = Vector2i(2560, 1440)
	settings.vsync = false
	settings.max_fps = 144
	settings.msaa = 4
	settings.render_scale = 0.75
	settings.master_volume = 0.3
	settings.look_sensitivity = 0.44
	settings.invert_pitch = true

	assert_true(_store.save_settings(settings), "the write failed")
	var loaded := _store.load_settings(1)
	assert_true(loaded.matches(settings), "%s came back as %s" % [
		settings.to_dictionary(), loaded.to_dictionary()
	])


## First run. There is no file, and that is not an error.
func test_no_file_gives_defaults() -> void:
	assert_false(_store.exists())
	assert_true(_store.load_settings(1).matches(GameSettings.new()))


## The one piece of state a player can reach with a text editor. It must never
## be able to stop the game starting.
##
## [b]This test prints one ConfigFile parse error to stderr and that is
## expected.[/b] Godot's parser logs before returning its error code, and there
## is no quiet variant. It is the only error line a passing run produces; if you
## see a second one, something is actually wrong.
func test_a_corrupt_file_gives_defaults_rather_than_failing_and_logs_one_error() -> void:
	_write_raw("this is not a config file {{{{ ]][[ = = =")
	var loaded := _store.load_settings(1)
	assert_not_null(loaded)
	assert_true(loaded.matches(GameSettings.new()))


func test_a_file_missing_our_section_gives_defaults() -> void:
	_write_raw("[something_else]\nfoo=1\n")
	assert_true(_store.load_settings(1).matches(GameSettings.new()))


func test_a_half_written_file_keeps_what_it_can() -> void:
	_write_raw('[settings]\nmax_fps=120\nmsaa=4\n')
	var loaded := _store.load_settings(1)
	assert_eq(loaded.max_fps, 120)
	assert_eq(loaded.msaa, 4)
	assert_eq(loaded.vsync, GameSettings.new().vsync, "the rest should be defaults")


func test_nonsense_values_in_the_file_are_sanitised_on_load() -> void:
	_write_raw('[settings]\nmax_fps=99999\nmonitor=7\nrender_scale=50.0\n')
	var loaded := _store.load_settings(1)
	assert_eq(loaded.max_fps, 240)
	assert_eq(loaded.monitor, 0, "loaded a monitor that does not exist")
	assert_true(loaded.render_scale <= 2.0)


func test_keys_we_do_not_know_are_ignored() -> void:
	# A settings file from a later build should not stop an earlier one loading.
	_write_raw('[settings]\nmax_fps=60\nray_tracing=true\n')
	assert_eq(_store.load_settings(1).max_fps, 60)


func test_saving_twice_replaces_rather_than_appends() -> void:
	var settings := GameSettings.new()
	settings.max_fps = 60
	_store.save_settings(settings)
	settings.max_fps = 144
	_store.save_settings(settings)
	assert_eq(_store.load_settings(1).max_fps, 144)


func test_clearing_forgets_everything() -> void:
	_store.save_settings(GameSettings.new())
	assert_true(_store.exists())
	_store.clear()
	assert_false(_store.exists())


## Settings follow the player, not the build -- they must not be written into
## the project folder.
func test_the_default_path_is_the_user_directory() -> void:
	assert_true(
		SettingsStore.DEFAULT_PATH.begins_with("user://"),
		"settings would be written next to the game files"
	)
