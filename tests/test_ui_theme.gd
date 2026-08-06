extends TestCase
## The design system: that the palette is legible, the scales are scales, and
## every screen actually inherits the theme.
##
## Colour and spacing are exactly the kind of thing that drifts -- somebody
## nudges a grey to fix one screen and quietly breaks the contrast on another,
## and nothing complains. These are the assertions that complain.
##
## The guidelines these check, and where they come from, are in UI.md.

const THEME_PATH: String = "res://resources/ui/game_theme.tres"
const MAIN_SCENE: String = "res://scenes/main.tscn"

## WCAG 2.2 AA: 4.5:1 for body text, 3:1 for large text and for the boundary of
## anything interactive.
const AA_TEXT: float = 4.5
const AA_LARGE: float = 3.0


func _theme() -> Theme:
	return load(THEME_PATH)


func test_the_theme_resource_exists_and_is_applied_project_wide() -> void:
	assert_true(ResourceLoader.exists(THEME_PATH), "there is no theme")
	assert_eq(
		ProjectSettings.get_setting("gui/theme/custom", ""),
		THEME_PATH,
		"the theme is not the project default, so nothing inherits it"
	)


## Text has to be readable on the surface it sits on. Measured, not judged.
func test_every_text_colour_passes_contrast_on_every_surface() -> void:
	for surface: Array in [
		[UiTokens.SURFACE_PANEL, "panel"],
		[UiTokens.SURFACE_RAISED, "raised"],
		[UiTokens.SURFACE_SUNKEN, "sunken"],
	]:
		for text: Array in [
			[UiTokens.TEXT_PRIMARY, "primary", AA_TEXT],
			[UiTokens.TEXT_SECONDARY, "secondary", AA_TEXT],
			[UiTokens.TEXT_DISABLED, "disabled", AA_LARGE],
			[UiTokens.GOLD, "gold", AA_TEXT],
			[UiTokens.DANGER, "danger", AA_TEXT],
			[UiTokens.WARNING, "warning", AA_TEXT],
			[UiTokens.SUCCESS, "success", AA_TEXT],
			[UiTokens.INFO, "info", AA_TEXT],
		]:
			var ratio := UiTokens.contrast(text[0], surface[0])
			assert_true(
				ratio >= text[2],
				"%s text on the %s surface is %.2f:1, below the %.1f:1 it needs"
					% [text[1], surface[1], ratio, text[2]]
			)


## The focus ring is the only thing telling a keyboard or pad player where they
## are, so it has to be visible against the controls it outlines.
func test_the_focus_ring_stands_out_from_the_controls() -> void:
	for surface: Color in [UiTokens.SURFACE_RAISED, UiTokens.SURFACE_PANEL, UiTokens.ACCENT]:
		var ratio := UiTokens.contrast(UiTokens.FOCUS, surface)
		assert_true(ratio >= AA_LARGE, "the focus ring is only %.2f:1 against a control" % ratio)


## Text on the accent has to work too -- it is the one place text sits on a
## saturated colour rather than on a grey.
func test_text_on_the_accent_is_readable() -> void:
	var ratio := UiTokens.contrast(UiTokens.TEXT_PRIMARY, UiTokens.ACCENT)
	assert_true(ratio >= AA_LARGE, "button text on the accent is %.2f:1" % ratio)


## A scale that is not ordered is a list of numbers.
func test_the_type_scale_ascends() -> void:
	var sizes: Array[int] = [
		UiTokens.TEXT_CAPTION,
		UiTokens.TEXT_SMALL,
		UiTokens.TEXT_BODY,
		UiTokens.TEXT_SUBTITLE,
		UiTokens.TEXT_TITLE,
		UiTokens.TEXT_DISPLAY,
	]
	for index in range(1, sizes.size()):
		assert_true(sizes[index] > sizes[index - 1], "the type scale goes backwards at %d" % index)
	assert_true(UiTokens.TEXT_CAPTION >= 12, "text below 12 px is unreadable at a distance")


func test_the_spacing_scale_ascends_and_sits_on_the_grid() -> void:
	var steps: Array[int] = [
		UiTokens.SPACE_XS,
		UiTokens.SPACE_SM,
		UiTokens.SPACE_MD,
		UiTokens.SPACE_LG,
		UiTokens.SPACE_XL,
		UiTokens.SPACE_2XL,
		UiTokens.SPACE_3XL,
	]
	for index in steps.size():
		assert_eq(steps[index] % UiTokens.SPACE_XS, 0, "%d is off the 4 px grid" % steps[index])
		if index > 0:
			assert_true(steps[index] > steps[index - 1], "the spacing scale goes backwards")


## Fitts's law, and WCAG 2.2's 24 px minimum for a pointer target.
func test_controls_are_big_enough_to_hit() -> void:
	assert_true(UiTokens.CONTROL_HEIGHT >= 32, "buttons are %d px tall" % UiTokens.CONTROL_HEIGHT)
	assert_true(UiTokens.CONTROL_HEIGHT_SM >= 24, "small controls are below the WCAG minimum")
	assert_true(UiTokens.SLOT_SIZE >= 44, "an inventory slot is too small to drag from")


## Anything over about a quarter of a second in an interface reads as lag.
func test_motion_is_fast_enough_not_to_be_waited_on() -> void:
	assert_true(UiTokens.MOTION_NORMAL <= 0.25, "the normal transition is a wait")
	assert_true(UiTokens.MOTION_FAST < UiTokens.MOTION_NORMAL)


## The whole point of a theme: a button added tomorrow is styled without anyone
## touching it.
func test_the_theme_styles_the_controls_it_needs_to() -> void:
	var theme := _theme()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(theme.has_stylebox(state, "Button"), "Button has no %s style" % state)
	assert_true(theme.has_stylebox("panel", "PanelContainer"))
	assert_true(theme.has_stylebox("normal", "LineEdit"))
	assert_true(theme.has_stylebox("focus", "LineEdit"), "a focused field looks unfocused")
	assert_true(theme.has_stylebox("background", "ProgressBar"))
	assert_not_null(theme.default_font, "the theme has no font, so every platform picks its own")


func test_the_named_variations_exist() -> void:
	var theme := _theme()
	for name: String in [
		"Display", "Title", "Subtitle", "Body", "Caption", "Muted", "Value",
		"PrimaryButton", "QuietButton", "Scrim", "Card", "Sunken",
		"HealthBar", "StaminaBar", "ExperienceBar",
	]:
		assert_true(
			theme.get_type_variation_base(name) != &"",
			"%s is not a variation, so a screen asking for it gets the default" % name
		)


## Bar colour is chosen by what the bar measures, not by whoever built the
## screen -- and the three must be told apart by more than brightness.
func test_the_bar_colours_are_distinct() -> void:
	var theme := _theme()
	var fills: Array[Color] = []
	for name: String in ["HealthBar", "StaminaBar", "ExperienceBar"]:
		var box := theme.get_stylebox("fill", name) as StyleBoxFlat
		assert_not_null(box, "%s has no fill" % name)
		fills.append(box.bg_color)
	for index in fills.size():
		for other in range(index + 1, fills.size()):
			assert_true(
				UiTokens.contrast(fills[index], fills[other]) > 1.15,
				"two bars are nearly the same colour"
			)


## The theme owns **appearance**; a scene owns **arrangement**.
##
## So `theme_override_constants/separation = 24` is fine -- that is this panel
## saying its two columns sit further apart than the default, which is layout.
## `theme_override_colors/font_color` is not: that is a screen deciding what a
## label looks like, which is how eighty-four overrides across ten scenes
## happened and why nothing quite matched anything else.
func test_no_screen_restyles_itself() -> void:
	var styling := [
		"theme_override_colors/",
		"theme_override_fonts/",
		"theme_override_font_sizes/",
		"theme_override_styles/",
	]
	for path: String in [
		"res://ui/store_screen.tscn",
		"res://ui/crafting_screen.tscn",
		"res://ui/inventory_screen.tscn",
		"res://ui/pause_menu.tscn",
		"res://ui/settings_menu.tscn",
		"res://scenes/title.tscn",
	]:
		var text := FileAccess.get_file_as_string(path)
		for prefix: String in styling:
			assert_eq(
				text.count(prefix),
				0,
				"%s sets %s itself; that belongs in the theme" % [path, prefix]
			)


func test_every_screen_inherits_the_theme() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	for path: String in ["StoreScreen", "CraftingScreen", "InventoryScreen", "PauseMenu"]:
		var panel: CanvasLayer = world.get_node(path)
		var control: Control = null
		for child: Node in panel.get_children():
			if child is Control:
				control = child
				break
		assert_not_null(control, "%s has no root Control" % path)
		# Null means "inherit", which is what every screen should say.
		assert_null(control.theme, "%s carries its own theme instead of the project one" % path)
