extends TestCase
## The debug overlay: what it says, and what it says when it was given nothing.

const OVERLAY_SCENE: String = "res://ui/debug_overlay.tscn"
const MAIN_SCENE: String = "res://scenes/main.tscn"
const PLAYER_SCENE: String = "res://characters/player.tscn"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount_overlay() -> DebugOverlay:
	var tree := Engine.get_main_loop() as SceneTree
	var overlay: DebugOverlay = load(OVERLAY_SCENE).instantiate()
	tree.root.add_child(overlay)
	_mounted.append(overlay)
	return overlay


func _watching_a_player() -> DebugOverlay:
	var tree := Engine.get_main_loop() as SceneTree
	var player: CharacterBody3D = load(PLAYER_SCENE).instantiate()
	tree.root.add_child(player)
	_mounted.append(player)

	var overlay := _mount_overlay()
	overlay.body = player
	overlay.movement = player.get_node("Movement")
	overlay.health = player.get_node("Health")
	overlay.stamina = player.get_node("Stamina")
	overlay.animation = player.get_node("Animation")

	var day_night := DayNightComponent.new()
	day_night.config = DayNightConfig.new()
	overlay.add_child(day_night)
	overlay.day_night = day_night
	return overlay


func test_the_overlay_scene_wires_its_own_label() -> void:
	var overlay := _mount_overlay()
	assert_not_null(overlay.label, "the label reference is not wired -- nothing would show")
	assert_false(overlay.label.text.is_empty(), "the panel rendered blank")


func test_the_main_scene_wires_the_overlay_to_what_it_watches() -> void:
	var root: Node = load(MAIN_SCENE).instantiate()
	_mounted.append(root)
	var overlay: DebugOverlay = root.get_node_or_null("DebugOverlay")
	assert_not_null(overlay, "the main scene has no debug overlay")
	assert_eq(overlay.body, root.get_node("Player"))
	assert_eq(overlay.movement, root.get_node("Player/Movement"))
	assert_eq(overlay.health, root.get_node("Player/Health"))
	assert_eq(overlay.stamina, root.get_node("Player/Stamina"))
	assert_eq(overlay.animation, root.get_node("Player/Animation"))
	assert_eq(overlay.day_night, root.get_node("DayNight"))


func test_it_reports_every_line_it_watches() -> void:
	var overlay := _watching_a_player()
	var text := overlay.build_text()
	for expected: String in ["fps", "pos", "speed", "state", "health", "stamina"]:
		assert_true(text.contains(expected), "no %s line in:\n%s" % [expected, text])
	assert_false(text.contains(DebugReadout.ABSENT), "watched values read as absent:\n%s" % text)


func test_it_reports_live_values() -> void:
	var overlay := _watching_a_player()
	overlay.health.take_damage(40.0)
	overlay.body.velocity = Vector3(3.0, 0.0, 4.0)

	var text := overlay.build_text()
	assert_true(text.contains("60 / 100"), "health did not update:\n%s" % text)
	assert_true(text.contains("5.00 m/s"), "speed did not update:\n%s" % text)


## Dropping this into a half-built scene should still be useful.
func test_an_unwatched_overlay_says_so_rather_than_failing() -> void:
	var overlay := _mount_overlay()
	var text := overlay.build_text()
	for name: String in ["time", "pos", "speed", "state", "health", "stamina"]:
		assert_true(
			text.contains("%s %s" % [name.rpad(DebugReadout.LABEL_WIDTH), DebugReadout.ABSENT]),
			"no absent line for %s in:\n%s" % [name, text]
		)


func test_the_panel_has_a_line_for_everything_at_all_times() -> void:
	# Same shape whether it is watching a world or nothing at all, so the panel
	# does not jump around as components come and go.
	var watching := _watching_a_player().build_text().split("\n").size()
	var empty := _mount_overlay().build_text().split("\n").size()
	assert_eq(watching, empty, "the panel changes height depending on what it watches")


func test_exhaustion_is_called_out() -> void:
	var overlay := _watching_a_player()
	assert_false(overlay.build_text().contains("(spent)"))

	for _tick in 600:
		overlay.stamina.request_drain()
		overlay.stamina.step(1.0 / 60.0)
	assert_true(overlay.stamina.is_exhausted(), "the bar did not empty")
	assert_true(overlay.build_text().contains("(spent)"), "an empty bar was not called out")


func test_the_clock_comes_from_the_cycle() -> void:
	var overlay := _mount_overlay()
	var day_night := DayNightComponent.new()
	day_night.config = DayNightConfig.new()
	overlay.add_child(day_night)
	day_night.set_time_of_day(0.5)
	overlay.day_night = day_night

	assert_true(overlay.build_text().contains("12:00"), "got:\n%s" % overlay.build_text())


func test_refreshing_writes_the_text_to_the_label() -> void:
	var overlay := _watching_a_player()
	overlay.health.take_damage(25.0)
	overlay.refresh()
	assert_eq(overlay.label.text, overlay.build_text())
	assert_true(overlay.label.text.contains("75 / 100"))


func test_the_toggle_key_hides_and_shows_it() -> void:
	var overlay := _mount_overlay()
	assert_true(overlay.visible)

	var press := InputEventKey.new()
	press.keycode = overlay.toggle_key
	press.pressed = true

	overlay._unhandled_key_input(press)
	assert_false(overlay.visible, "the toggle did not hide it")
	overlay._unhandled_key_input(press)
	assert_true(overlay.visible, "the toggle did not bring it back")


func test_other_keys_are_left_alone() -> void:
	var overlay := _mount_overlay()
	var press := InputEventKey.new()
	press.keycode = KEY_W
	press.pressed = true

	overlay._unhandled_key_input(press)
	assert_true(overlay.visible, "an unrelated key toggled the overlay")


## Key repeat would strobe the panel for as long as the key is held.
func test_a_repeat_is_not_a_second_press() -> void:
	var overlay := _mount_overlay()
	var echo := InputEventKey.new()
	echo.keycode = overlay.toggle_key
	echo.pressed = true
	echo.echo = true

	overlay._unhandled_key_input(echo)
	assert_true(overlay.visible)
