class_name SettingsMenu
extends PanelContainer
## The settings panel.
##
## Rows are built in code rather than laid out in the scene. A dozen
## label-and-control pairs hand-written into a .tscn is four hundred lines that
## have to be edited in lockstep with [GameSettings]; built from a list, adding
## a setting is one entry and the layout cannot drift out of step with it.
##
## Knows nothing about applying anything. It shows a [GameSettings], reads one
## back, and says when the player pressed a button.

## The player pressed Apply. Carries a fresh settings object; whoever owns this
## decides what to do with it.
signal applied(settings: GameSettings)

## The player pressed Back.
signal closed

@export var rows: VBoxContainer
@export var apply_button: Button
@export var defaults_button: Button
@export var back_button: Button

var _controls: Dictionary[StringName, Control] = {}
var _screen_count: int = 1


func _ready() -> void:
	_screen_count = maxi(DisplayServer.get_screen_count(), 1)
	_build()
	if apply_button != null:
		apply_button.pressed.connect(func() -> void: applied.emit(collect()))
	if defaults_button != null:
		defaults_button.pressed.connect(_on_defaults)
	if back_button != null:
		back_button.pressed.connect(func() -> void: closed.emit())


## Fills every control from [param settings].
func show_settings(settings: GameSettings) -> void:
	if _controls.is_empty():
		_build()
	_option(&"display_mode").selected = settings.display_mode
	_option(&"resolution").selected = _resolution_index(settings.resolution)
	_option(&"monitor").selected = clampi(settings.monitor, 0, _screen_count - 1)
	_option(&"max_fps").selected = maxi(GameSettings.FPS_CAPS.find(settings.max_fps), 0)
	_option(&"msaa").selected = maxi(GameSettings.MSAA_LEVELS.find(settings.msaa), 0)
	_check(&"vsync").button_pressed = settings.vsync
	_check(&"invert_pitch").button_pressed = settings.invert_pitch
	_slider(&"render_scale").value = settings.render_scale
	_slider(&"master_volume").value = settings.master_volume
	_slider(&"look_sensitivity").value = settings.look_sensitivity
	_refresh_availability()


## Reads the controls back into a settings object.
func collect() -> GameSettings:
	var settings := GameSettings.new()
	settings.display_mode = _option(&"display_mode").selected as GameSettings.DisplayMode
	settings.resolution = GameSettings.resolutions()[
		clampi(_option(&"resolution").selected, 0, GameSettings.resolutions().size() - 1)
	]
	settings.monitor = _option(&"monitor").selected
	settings.max_fps = GameSettings.FPS_CAPS[
		clampi(_option(&"max_fps").selected, 0, GameSettings.FPS_CAPS.size() - 1)
	]
	settings.msaa = GameSettings.MSAA_LEVELS[
		clampi(_option(&"msaa").selected, 0, GameSettings.MSAA_LEVELS.size() - 1)
	]
	settings.vsync = _check(&"vsync").button_pressed
	settings.invert_pitch = _check(&"invert_pitch").button_pressed
	settings.render_scale = _slider(&"render_scale").value
	settings.master_volume = _slider(&"master_volume").value
	settings.look_sensitivity = _slider(&"look_sensitivity").value
	settings.sanitise(_screen_count)
	return settings


## The control for [param key], for tests and for anything that wants to poke
## one directly.
func control(key: StringName) -> Control:
	return _controls.get(key)


func _on_defaults() -> void:
	var defaults := GameSettings.new()
	defaults.sanitise(_screen_count)
	show_settings(defaults)


func _build() -> void:
	if rows == null or not _controls.is_empty():
		return

	_section("Display")
	var modes: Array[String] = []
	for mode: int in range(GameSettings.DisplayMode.size()):
		modes.append(GameSettings.display_mode_name(mode as GameSettings.DisplayMode))
	_options(&"display_mode", "Mode", modes)

	var resolution_names: Array[String] = []
	for size: Vector2i in GameSettings.resolutions():
		resolution_names.append("%d x %d" % [size.x, size.y])
	_options(&"resolution", "Resolution", resolution_names)

	var monitors: Array[String] = []
	for index in _screen_count:
		monitors.append("Monitor %d" % (index + 1))
	_options(&"monitor", "Monitor", monitors)

	_checkbox(&"vsync", "V-Sync")

	var caps: Array[String] = []
	for cap: int in GameSettings.FPS_CAPS:
		caps.append("Unlimited" if cap == 0 else "%d FPS" % cap)
	_options(&"max_fps", "Frame rate", caps)

	_section("Graphics")
	var levels: Array[String] = []
	for level: int in GameSettings.MSAA_LEVELS:
		levels.append("Off" if level == 0 else "%dx" % level)
	_options(&"msaa", "Anti-aliasing", levels)
	_slider_row(&"render_scale", "Render scale", 0.5, 2.0, 0.05)

	_section("Audio")
	_slider_row(&"master_volume", "Master volume", 0.0, 1.0, 0.01)

	_section("Controls")
	_slider_row(&"look_sensitivity", "Look sensitivity", 0.02, 1.0, 0.01)
	_checkbox(&"invert_pitch", "Invert look")


## Greys out what the current mode ignores, rather than hiding it.
##
## A picker that vanishes leaves you wondering whether the game has the setting
## at all; one that greys out says "not for this mode".
func _refresh_availability() -> void:
	var windowed := (
		_option(&"display_mode").selected == GameSettings.DisplayMode.WINDOWED
	)
	_option(&"resolution").disabled = not windowed
	_option(&"monitor").disabled = _screen_count <= 1


func _section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.theme_type_variation = &"HeaderSmall"
	rows.add_child(label)


func _row(text: String, control_node: Control) -> Control:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(180.0, 0.0)
	row.add_child(label)
	control_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control_node)
	rows.add_child(row)
	return control_node


func _options(key: StringName, text: String, items: Array[String]) -> void:
	var picker := OptionButton.new()
	for item: String in items:
		picker.add_item(item)
	picker.item_selected.connect(func(_index: int) -> void: _refresh_availability())
	_controls[key] = _row(text, picker)


func _checkbox(key: StringName, text: String) -> void:
	_controls[key] = _row(text, CheckButton.new())


func _slider_row(key: StringName, text: String, low: float, high: float, step: float) -> void:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# A slider with no number on it is a slider you cannot set to a known value.
	var readout := Label.new()
	readout.custom_minimum_size = Vector2(56.0, 0.0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	readout.text = "%.2f" % slider.value
	slider.value_changed.connect(func(value: float) -> void: readout.text = "%.2f" % value)

	var holder := HBoxContainer.new()
	holder.add_child(slider)
	holder.add_child(readout)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row(text, holder)
	_controls[key] = slider


func _resolution_index(size: Vector2i) -> int:
	var index := GameSettings.resolutions().find(size)
	return index if index >= 0 else GameSettings.resolutions().size() - 1


func _option(key: StringName) -> OptionButton:
	return _controls.get(key) as OptionButton


func _check(key: StringName) -> CheckButton:
	return _controls.get(key) as CheckButton


func _slider(key: StringName) -> HSlider:
	return _controls.get(key) as HSlider
