extends TestCase
## The pause menu and the settings panel, mounted in the real scene.

const MAIN_SCENE: String = "res://scenes/main.tscn"


func after_each() -> void:
	# A test that leaves the tree paused takes every later suite with it.
	(Engine.get_main_loop() as SceneTree).paused = false


func _mount_world() -> Node:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	return world


func _menu(world: Node) -> PauseMenu:
	return world.get_node("PauseMenu")


func _escape() -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = KEY_ESCAPE
	key.pressed = true
	return key


func test_the_main_scene_carries_a_pause_menu() -> void:
	var world := _mount_world()
	var menu := _menu(world)
	assert_not_null(menu, "the main scene has no pause menu")
	assert_eq(menu.world_root, world, "it cannot give the cursor back")
	assert_eq(menu.camera, world.get_node("PlayerCamera"))
	assert_not_null(menu.settings_menu, "there is no settings panel to open")


## A menu that opens with the game is a menu you have to close first.
func test_it_starts_closed_and_unpaused() -> void:
	var menu := _menu(_mount_world())
	assert_false(menu.visible)
	assert_false((Engine.get_main_loop() as SceneTree).paused)


## The three have to happen together: pause, cursor, panel. Any one without the
## others is a bug you can feel.
func test_opening_pauses_the_game() -> void:
	var menu := _menu(_mount_world())
	menu.set_open(true)
	assert_true(menu.visible)
	assert_true((Engine.get_main_loop() as SceneTree).paused)

	menu.set_open(false)
	assert_false(menu.visible)
	assert_false((Engine.get_main_loop() as SceneTree).paused)


func test_escape_opens_and_closes_it() -> void:
	var menu := _menu(_mount_world())
	menu._unhandled_input(_escape())
	assert_true(menu.visible, "escape did not open the menu")
	menu._unhandled_input(_escape())
	assert_false(menu.visible, "escape did not close the menu")


func test_it_keeps_running_while_everything_else_is_paused() -> void:
	# Otherwise it pauses itself and can never be closed.
	var menu := _menu(_mount_world())
	assert_eq(menu.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_settings_opens_over_the_root_menu() -> void:
	var world := _mount_world()
	var menu := _menu(world)
	menu.set_open(true)
	menu.settings_button.pressed.emit()

	assert_true(menu.settings_menu.visible, "the settings panel did not open")
	assert_false(menu.root_panel.visible, "both panels are showing at once")


## Inside settings, escape should step back rather than closing everything --
## otherwise a mistyped key throws away the panel you were reading.
func test_escape_inside_settings_goes_back_one_step() -> void:
	var menu := _menu(_mount_world())
	menu.set_open(true)
	menu.settings_button.pressed.emit()

	menu._unhandled_input(_escape())
	assert_false(menu.settings_menu.visible)
	assert_true(menu.root_panel.visible)
	assert_true(menu.visible, "escape closed the whole menu instead of stepping back")


func test_every_setting_has_a_control() -> void:
	var menu := _menu(_mount_world())
	var panel := menu.settings_menu
	for key: StringName in [
		&"display_mode",
		&"resolution",
		&"monitor",
		&"vsync",
		&"max_fps",
		&"msaa",
		&"render_scale",
		&"master_volume",
		&"look_sensitivity",
		&"invert_pitch",
	]:
		assert_not_null(panel.control(key), "no control was built for %s" % key)


func test_the_panel_shows_what_it_is_given_and_gives_it_back() -> void:
	var menu := _menu(_mount_world())
	var panel := menu.settings_menu

	var settings := GameSettings.new()
	settings.display_mode = GameSettings.DisplayMode.BORDERLESS
	settings.resolution = Vector2i(2560, 1440)
	settings.max_fps = 144
	settings.msaa = 4
	settings.vsync = false
	settings.render_scale = 0.75
	settings.invert_pitch = true
	settings.sanitise(1)

	panel.show_settings(settings)
	var collected := panel.collect()
	assert_true(collected.matches(settings), "%s came back as %s" % [
		settings.to_dictionary(), collected.to_dictionary()
	])


## A resolution the monitor cannot use is ignored by both fullscreen modes, so
## the picker says so rather than pretending it did something.
func test_the_resolution_picker_greys_out_in_fullscreen() -> void:
	var panel := _menu(_mount_world()).settings_menu
	var settings := GameSettings.new()

	settings.display_mode = GameSettings.DisplayMode.WINDOWED
	panel.show_settings(settings)
	assert_false((panel.control(&"resolution") as OptionButton).disabled)

	settings.display_mode = GameSettings.DisplayMode.FULLSCREEN
	panel.show_settings(settings)
	assert_true((panel.control(&"resolution") as OptionButton).disabled)


func test_reset_puts_the_defaults_back_on_screen() -> void:
	var panel := _menu(_mount_world()).settings_menu
	var changed := GameSettings.new()
	changed.max_fps = 144
	panel.show_settings(changed)

	panel.defaults_button.pressed.emit()
	assert_eq(panel.collect().max_fps, GameSettings.new().max_fps)


## The point of the feature: what you set is still set next time.
##
## Mounted standalone with its own settings path. Going through the main scene
## would write the real file and rewrite the settings of whoever ran the tests.
func test_applying_saves_to_disk() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var menu: PauseMenu = load("res://ui/pause_menu.tscn").instantiate()
	menu.settings_path = "user://test_pause_settings.cfg"
	mount(menu)

	var panel := menu.settings_menu
	var wanted := GameSettings.new()
	wanted.max_fps = 144
	wanted.msaa = 4
	wanted.vsync = false
	panel.show_settings(wanted)
	panel.apply_button.pressed.emit()

	var reloaded := SettingsStore.new(menu.settings_path).load_settings(1)
	assert_eq(reloaded.max_fps, 144, "the frame cap did not persist")
	assert_eq(reloaded.msaa, 4)
	assert_false(reloaded.vsync)
	assert_true(menu.settings().matches(reloaded), "the menu and the file disagree")
	SettingsStore.new(menu.settings_path).clear()


## Every other test in this suite mounts the real scene, so the real path must
## not be what it writes to unless a test asks for it.
func test_tests_do_not_clobber_the_real_settings_file() -> void:
	# Deliberately does not press Apply. Nothing in this suite may write the
	# real path -- only the standalone test above writes, and it writes its own.
	var menu := _menu(_mount_world())
	assert_eq(
		menu.settings_path,
		SettingsStore.DEFAULT_PATH,
		"the scene should ship with the real path; only tests override it"
	)
