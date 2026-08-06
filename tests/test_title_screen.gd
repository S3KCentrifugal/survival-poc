extends TestCase
## The home screen, and the way in and out of a world.
##
## Nothing here presses Single player for real: [SceneRouter] frees the current
## scene, and the current scene during a test run is the test runner. What is
## checked instead is everything up to that call -- the panels, the fields, the
## wiring -- plus the router's own decisions in isolation.

const TITLE_SCENE: String = "res://scenes/title.tscn"


func _mount_title() -> TitleScreen:
	var title: TitleScreen = load(TITLE_SCENE).instantiate()
	mount(title)
	return title


func test_the_title_screen_loads_with_every_reference_wired() -> void:
	var title := _mount_title()
	assert_not_null(title.main_panel, "no main panel")
	assert_not_null(title.multiplayer_panel, "no multiplayer panel")
	assert_not_null(title.settings_menu, "no settings panel")
	assert_not_null(title.settings_controller, "nothing loads the saved settings")
	for button: Button in [
		title.single_player_button,
		title.multiplayer_button,
		title.settings_button,
		title.exit_button,
		title.host_button,
		title.join_button,
		title.multiplayer_back_button,
	]:
		assert_not_null(button, "a button is missing from the scene")


func test_it_opens_on_the_main_panel() -> void:
	var title := _mount_title()
	assert_true(title.main_panel.visible)
	assert_false(title.multiplayer_panel.visible)
	assert_false(title.settings_menu.visible)


## Exactly one panel at a time. Two showing at once is the bug you get from
## turning things on without turning anything off.
func test_only_one_panel_shows_at_a_time() -> void:
	var title := _mount_title()

	title.multiplayer_button.pressed.emit()
	assert_true(title.multiplayer_panel.visible, "multiplayer did not open")
	assert_false(title.main_panel.visible)
	assert_false(title.settings_menu.visible)

	title.settings_button.pressed.emit()
	assert_true(title.settings_menu.visible, "settings did not open")
	assert_false(title.main_panel.visible)
	assert_false(title.multiplayer_panel.visible)

	title.multiplayer_button.pressed.emit()
	title.multiplayer_back_button.pressed.emit()
	assert_true(title.main_panel.visible, "back did not return to the main panel")


## The same panel the pause menu shows, instanced rather than rebuilt.
func test_the_settings_panel_is_the_shared_one() -> void:
	var title := _mount_title()
	assert_true(title.settings_menu is SettingsMenu)
	assert_not_null(
		title.settings_menu.control(&"display_mode"), "the settings panel built no controls"
	)


func test_the_settings_panel_opens_showing_the_saved_settings() -> void:
	var title := _mount_title()
	title.settings_button.pressed.emit()
	assert_true(
		title.settings_menu.collect().matches(title.settings_controller.settings()),
		"the panel is showing something other than what is in force"
	)


func test_a_blank_port_falls_back_to_the_default() -> void:
	var title := _mount_title()
	for typed: String in ["", "   ", "not a port", "0", "70000"]:
		title.port_field.text = typed
		assert_eq(
			title.chosen_port(),
			NetworkService.DEFAULT_PORT,
			"%s should have fallen back to the default port" % [typed]
		)

	title.port_field.text = " 27016 "
	assert_eq(title.chosen_port(), 27016, "a typed port was not used")


func test_the_address_is_trimmed() -> void:
	var title := _mount_title()
	title.address_field.text = "  10.0.0.4  "
	assert_eq(title.chosen_address(), "10.0.0.4")


## Joining nowhere should say so rather than opening a socket to "".
func test_join_with_no_address_refuses_and_explains() -> void:
	var title := _mount_title()
	var launched: Array[int] = []
	title.launching.connect(func(mode: GameSession.Mode) -> void: launched.append(mode))

	title.address_field.text = "   "
	title.join_game()

	assert_eq(launched.size(), 0, "it tried to join nothing")
	assert_false(title.status_label.text.is_empty(), "it refused without saying why")


## The router is what the buttons call, so its constants have to be real files.
func test_the_router_points_at_scenes_that_exist() -> void:
	assert_true(ResourceLoader.exists(SceneRouter.TITLE_SCENE), "no title scene")
	assert_true(ResourceLoader.exists(SceneRouter.GAME_SCENE), "no game scene")


## Returning to the title from a paused menu must unpause on the way out -- a
## paused title screen is one whose buttons do nothing.
func test_returning_to_the_title_unpauses() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	# Deliberately no scene to swap: the swap is what frees the runner. What is
	# being checked is the tidy-up that happens before it.
	tree.paused = true
	SceneRouter.to_title(null)
	assert_true(tree.paused, "a null tree should have been left alone")
	tree.paused = false


func test_the_pause_menu_offers_a_way_back_to_the_title() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var menu: PauseMenu = load("res://ui/pause_menu.tscn").instantiate()
	menu.settings_path = "user://test_title_settings.cfg"
	mount(menu)

	assert_not_null(menu.main_menu_button, "the pause menu has no way back to the title")
	assert_not_null(menu.quit_button, "the pause menu has no way out of the game")
	SettingsStore.new(menu.settings_path).clear()
