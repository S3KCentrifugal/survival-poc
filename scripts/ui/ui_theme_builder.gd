class_name UiThemeBuilder
extends RefCounted
## Turns [UiTokens] into the [Theme] every Control inherits.
##
## A project-wide theme rather than per-node overrides. Godot walks up the tree
## for a theme item, so setting one here styles every button in the game --
## including buttons added next year by somebody who never read this file. That
## is the whole point: the default has to be right, because the default is what
## most things will use.
##
## Built by code and saved, rather than hand-authored. A `.tres` theme is a few
## hundred lines of `Button/styles/normal = SubResource(...)` that nobody can
## review, and every value in it would be a second copy of a token.

const THEME_PATH: String = "res://resources/ui/game_theme.tres"


## Builds the theme from the tokens.
static func build() -> Theme:
	var theme := Theme.new()
	var face := UiTokens.font()
	theme.default_font = face
	theme.default_font_size = UiTokens.TEXT_BODY

	_labels(theme)
	_buttons(theme)
	_panels(theme)
	_inputs(theme)
	_bars(theme)
	_lists(theme)
	_tooltip(theme)
	return theme


## Writes the theme to disk. Called by a tool script, not at runtime.
static func save() -> Error:
	return ResourceSaver.save(build(), THEME_PATH)


static func _labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	theme.set_constant("outline_size", "Label", 0)

	# Named variants, so a screen asks for "a caption" rather than setting a
	# size and a colour and hoping they match the last screen that did.
	for name: String in ["Display", "Title", "Subtitle", "Body", "Caption", "Muted", "Value"]:
		theme.add_type(name)
		theme.set_type_variation(name, "Label")
	theme.set_font_size("font_size", "Display", UiTokens.TEXT_DISPLAY)
	theme.set_font_size("font_size", "Title", UiTokens.TEXT_TITLE)
	theme.set_font_size("font_size", "Subtitle", UiTokens.TEXT_SUBTITLE)
	theme.set_font_size("font_size", "Body", UiTokens.TEXT_BODY)
	theme.set_font_size("font_size", "Caption", UiTokens.TEXT_CAPTION)
	theme.set_font_size("font_size", "Muted", UiTokens.TEXT_SMALL)
	theme.set_color("font_color", "Muted", UiTokens.TEXT_SECONDARY)
	theme.set_color("font_color", "Caption", UiTokens.TEXT_SECONDARY)
	theme.set_font_size("font_size", "Value", UiTokens.TEXT_BODY)
	theme.set_color("font_color", "Value", UiTokens.GOLD)


static func _buttons(theme: Theme) -> void:
	var padding := UiTokens.SPACE_MD
	var normal := UiTokens.box(
		UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD, UiTokens.BORDER, UiTokens.BORDER_WIDTH, padding
	)
	var hover := UiTokens.box(
		UiTokens.SURFACE_RAISED.lightened(0.08),
		UiTokens.RADIUS_MD,
		UiTokens.BORDER_STRONG,
		UiTokens.BORDER_WIDTH,
		padding
	)
	var pressed := UiTokens.box(
		UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_MD, UiTokens.BORDER_STRONG, UiTokens.BORDER_WIDTH, padding
	)
	# A disabled control still has to read as a control. Removing its border
	# makes it look like a label, and then nobody knows there was anything to
	# enable.
	var disabled := UiTokens.box(
		UiTokens.SURFACE_PANEL, UiTokens.RADIUS_MD, UiTokens.BORDER, UiTokens.BORDER_WIDTH, padding
	)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	# Keyboard focus has to be visible, and visibly different from hover: a
	# player on a pad or arrow keys has nothing else telling them where they are.
	theme.set_stylebox("focus", "Button", UiTokens.outline(UiTokens.FOCUS))

	theme.set_color("font_color", "Button", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_pressed_color", "Button", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", UiTokens.TEXT_DISABLED)
	theme.set_color("font_focus_color", "Button", UiTokens.TEXT_PRIMARY)
	theme.set_font_size("font_size", "Button", UiTokens.TEXT_BODY)

	# One button per screen should look like the answer. Everything else is the
	# default above, so the accent keeps its meaning by being rare.
	theme.add_type("PrimaryButton")
	theme.set_type_variation("PrimaryButton", "Button")
	theme.set_stylebox("normal", "PrimaryButton", UiTokens.box(UiTokens.ACCENT, UiTokens.RADIUS_MD, Color.TRANSPARENT, 0, padding))
	theme.set_stylebox("hover", "PrimaryButton", UiTokens.box(UiTokens.ACCENT_HOVER, UiTokens.RADIUS_MD, Color.TRANSPARENT, 0, padding))
	theme.set_stylebox("pressed", "PrimaryButton", UiTokens.box(UiTokens.ACCENT_PRESSED, UiTokens.RADIUS_MD, Color.TRANSPARENT, 0, padding))
	theme.set_stylebox("disabled", "PrimaryButton", disabled)
	theme.set_stylebox("focus", "PrimaryButton", UiTokens.outline(UiTokens.FOCUS))
	theme.set_color("font_color", "PrimaryButton", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "PrimaryButton", UiTokens.TEXT_DISABLED)

	# The way out of a screen is not the same weight as the way through it.
	theme.add_type("QuietButton")
	theme.set_type_variation("QuietButton", "Button")
	var quiet := UiTokens.box(Color.TRANSPARENT, UiTokens.RADIUS_MD, Color.TRANSPARENT, 0, padding)
	theme.set_stylebox("normal", "QuietButton", quiet)
	theme.set_stylebox("hover", "QuietButton", UiTokens.box(UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD, Color.TRANSPARENT, 0, padding))
	theme.set_stylebox("pressed", "QuietButton", UiTokens.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_MD, Color.TRANSPARENT, 0, padding))
	theme.set_stylebox("disabled", "QuietButton", quiet)
	theme.set_stylebox("focus", "QuietButton", UiTokens.outline(UiTokens.FOCUS))
	theme.set_color("font_color", "QuietButton", UiTokens.TEXT_SECONDARY)


static func _panels(theme: Theme) -> void:
	theme.set_stylebox(
		"panel",
		"PanelContainer",
		UiTokens.box(
			UiTokens.SURFACE_PANEL,
			UiTokens.RADIUS_LG,
			UiTokens.BORDER,
			UiTokens.BORDER_WIDTH,
			UiTokens.SPACE_XL
		)
	)
	theme.set_stylebox("panel", "Panel", UiTokens.box(UiTokens.SURFACE_PANEL, UiTokens.RADIUS_LG, UiTokens.BORDER, UiTokens.BORDER_WIDTH, 0))

	# The dim behind a modal. Its job is to say "the thing behind this is not
	# what you are looking at", which needs no border and no radius.
	theme.add_type("Scrim")
	theme.set_type_variation("Scrim", "PanelContainer")
	theme.set_stylebox("panel", "Scrim", UiTokens.box(UiTokens.SCRIM, 0, Color.TRANSPARENT, 0, 0))

	# A block inside a panel: a row, a group, a readout.
	theme.add_type("Card")
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox(
		"panel",
		"Card",
		UiTokens.box(UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD, UiTokens.BORDER, UiTokens.BORDER_WIDTH, UiTokens.SPACE_MD)
	)

	theme.add_type("Sunken")
	theme.set_type_variation("Sunken", "PanelContainer")
	theme.set_stylebox(
		"panel",
		"Sunken",
		UiTokens.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_MD, UiTokens.BORDER, UiTokens.BORDER_WIDTH, UiTokens.SPACE_SM)
	)

	theme.set_constant("separation", "VBoxContainer", UiTokens.SPACE_MD)
	theme.set_constant("separation", "HBoxContainer", UiTokens.SPACE_MD)
	theme.set_constant("h_separation", "GridContainer", UiTokens.SPACE_SM)
	theme.set_constant("v_separation", "GridContainer", UiTokens.SPACE_SM)

	# A rule, for separating groups without a heading.
	theme.set_stylebox(
		"separator",
		"HSeparator",
		UiTokens.box(UiTokens.BORDER, 0, Color.TRANSPARENT, 0, 0)
	)
	theme.set_constant("separation", "HSeparator", UiTokens.SPACE_SM)


static func _inputs(theme: Theme) -> void:
	var field := UiTokens.box(
		UiTokens.SURFACE_SUNKEN,
		UiTokens.RADIUS_SM,
		UiTokens.BORDER,
		UiTokens.BORDER_WIDTH,
		UiTokens.SPACE_SM
	)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", UiTokens.outline(UiTokens.FOCUS, UiTokens.FOCUS_WIDTH, UiTokens.RADIUS_SM))
	theme.set_color("font_color", "LineEdit", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_placeholder_color", "LineEdit", UiTokens.TEXT_DISABLED)
	theme.set_color("caret_color", "LineEdit", UiTokens.FOCUS)
	theme.set_color("selection_color", "LineEdit", Color(UiTokens.ACCENT, 0.4))

	theme.set_stylebox("normal", "OptionButton", field)
	theme.set_stylebox("hover", "OptionButton", UiTokens.box(UiTokens.SURFACE_RAISED, UiTokens.RADIUS_SM, UiTokens.BORDER_STRONG, UiTokens.BORDER_WIDTH, UiTokens.SPACE_SM))
	theme.set_stylebox("pressed", "OptionButton", field)
	theme.set_stylebox("focus", "OptionButton", UiTokens.outline(UiTokens.FOCUS, UiTokens.FOCUS_WIDTH, UiTokens.RADIUS_SM))
	theme.set_color("font_color", "OptionButton", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "OptionButton", UiTokens.TEXT_DISABLED)

	theme.set_stylebox("panel", "PopupMenu", UiTokens.box(UiTokens.SURFACE_RAISED, UiTokens.RADIUS_MD, UiTokens.BORDER_STRONG, UiTokens.BORDER_WIDTH, UiTokens.SPACE_XS))
	theme.set_color("font_color", "PopupMenu", UiTokens.TEXT_PRIMARY)
	theme.set_color("font_hover_color", "PopupMenu", UiTokens.TEXT_PRIMARY)
	theme.set_stylebox("hover", "PopupMenu", UiTokens.box(UiTokens.ACCENT, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, UiTokens.SPACE_XS))

	theme.set_stylebox("grabber", "HSlider", UiTokens.box(UiTokens.TEXT_PRIMARY, UiTokens.RADIUS_LG, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("slider", "HSlider", UiTokens.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_area", "HSlider", UiTokens.box(UiTokens.ACCENT, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))


static func _bars(theme: Theme) -> void:
	theme.set_stylebox(
		"background",
		"ProgressBar",
		UiTokens.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_SM, UiTokens.BORDER, UiTokens.BORDER_WIDTH, 0)
	)
	theme.set_stylebox("fill", "ProgressBar", UiTokens.box(UiTokens.ACCENT, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))
	theme.set_color("font_color", "ProgressBar", UiTokens.TEXT_PRIMARY)
	theme.set_font_size("font_size", "ProgressBar", UiTokens.TEXT_CAPTION)

	# One variation per meaning, so a bar's colour is chosen by what it measures
	# rather than by whoever built the screen.
	for name: String in ["HealthBar", "StaminaBar", "ExperienceBar"]:
		theme.add_type(name)
		theme.set_type_variation(name, "ProgressBar")
	theme.set_stylebox("fill", "HealthBar", UiTokens.box(UiTokens.DANGER, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "StaminaBar", UiTokens.box(UiTokens.WARNING, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "ExperienceBar", UiTokens.box(UiTokens.INFO, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))


static func _lists(theme: Theme) -> void:
	theme.set_color("default_color", "RichTextLabel", UiTokens.TEXT_PRIMARY)
	theme.set_font_size("normal_font_size", "RichTextLabel", UiTokens.TEXT_SMALL)
	theme.set_stylebox("panel", "ScrollContainer", UiTokens.box(Color.TRANSPARENT, 0, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("scroll", "VScrollBar", UiTokens.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber", "VScrollBar", UiTokens.box(UiTokens.BORDER_STRONG, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("grabber_highlight", "VScrollBar", UiTokens.box(UiTokens.TEXT_DISABLED, UiTokens.RADIUS_SM, Color.TRANSPARENT, 0, 0))


static func _tooltip(theme: Theme) -> void:
	theme.set_stylebox(
		"panel",
		"TooltipPanel",
		UiTokens.box(UiTokens.SURFACE_SUNKEN, UiTokens.RADIUS_SM, UiTokens.BORDER_STRONG, UiTokens.BORDER_WIDTH, UiTokens.SPACE_SM)
	)
	theme.set_color("font_color", "TooltipLabel", UiTokens.TEXT_PRIMARY)
	theme.set_font_size("font_size", "TooltipLabel", UiTokens.TEXT_SMALL)
