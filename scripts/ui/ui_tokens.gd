class_name UiTokens
extends RefCounted
## The design system, as numbers.
##
## Every size, colour, radius and duration the interface uses lives here, and
## nowhere else. Before this there were eighty-four per-node
## `theme_override_*` entries across ten scenes, six arbitrary font sizes and
## ten near-identical panel colours -- which is what "each screen was styled
## when it was written" looks like, and why nothing quite matched anything else.
##
## Nothing reads these at runtime. [UiThemeBuilder] turns them into a Godot
## [Theme] that every [Control] inherits, so a button is styled once rather than
## in each scene that has one. They are constants rather than a resource because
## a design system that can be edited per-scene is not a design system.
##
## See UI.md for the guidelines these implement and where they come from.

# --- Spacing -----------------------------------------------------------------
## A 4-pixel base grid. Everything -- margins, gaps, padding -- is one of these.
##
## A scale rather than free numbers because inconsistent spacing is the single
## most legible sign of an unconsidered interface: the eye reads 12 next to 14
## as a mistake long before it can say why.
const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 12
const SPACE_LG: int = 16
const SPACE_XL: int = 24
const SPACE_2XL: int = 32
const SPACE_3XL: int = 48

# --- Type --------------------------------------------------------------------
## A modular scale, roughly 1.25 between steps. Six sizes, and a screen should
## rarely use more than three of them.
##
## Hierarchy is what makes a panel scannable: the eye needs to be told what to
## read first, and size is the cheapest way to say it.
const TEXT_CAPTION: int = 12
const TEXT_SMALL: int = 14
const TEXT_BODY: int = 16
const TEXT_SUBTITLE: int = 20
const TEXT_TITLE: int = 24
const TEXT_DISPLAY: int = 32

# --- Surfaces ----------------------------------------------------------------
## Darkest to lightest, and depth is the only thing they encode. A row does not
## get its own colour because it is a row; it gets [constant SURFACE_RAISED]
## because it sits on top of something.
const SCRIM: Color = Color(0.024, 0.031, 0.043, 0.72)
const SURFACE_PANEL: Color = Color(0.082, 0.102, 0.129)
const SURFACE_RAISED: Color = Color(0.114, 0.141, 0.176)
const SURFACE_SUNKEN: Color = Color(0.055, 0.071, 0.094)
const BORDER: Color = Color(0.200, 0.251, 0.306)
const BORDER_STRONG: Color = Color(0.294, 0.361, 0.435)

# --- Text --------------------------------------------------------------------
## Contrast ratios against [constant SURFACE_PANEL], measured rather than
## guessed. WCAG 2.2 AA wants 4.5:1 for body text and 3:1 for large text and
## for the boundaries of interactive controls.
##
## Checked against **every** surface, not just the panel: the first version of
## this palette passed on the panel and failed at 4.25:1 on the raised surface,
## which is the one buttons and rows are drawn on. A palette verified against
## one background is a palette verified for one screen.
const TEXT_PRIMARY: Color = Color(0.902, 0.925, 0.953)
const TEXT_SECONDARY: Color = Color(0.639, 0.694, 0.761)
const TEXT_DISABLED: Color = Color(0.420, 0.467, 0.529)
const TEXT_INVERSE: Color = Color(0.055, 0.071, 0.094)

# --- Semantic ----------------------------------------------------------------
## Colour carries meaning, and each of these means exactly one thing. Never
## decoration: a red that sometimes means damage and sometimes means "this row
## is different" means nothing at all.
##
## Also never the *only* signal -- around 4% of players cannot separate red from
## green, so anything said in colour is also said in text or shape.
const DANGER: Color = Color(0.910, 0.416, 0.373)
const WARNING: Color = Color(0.878, 0.702, 0.255)
const SUCCESS: Color = Color(0.420, 0.765, 0.541)
const INFO: Color = Color(0.435, 0.659, 0.863)
const GOLD: Color = Color(0.910, 0.722, 0.294)
const FOCUS: Color = Color(0.863, 0.918, 1.0)

## The accent used for the thing a screen most wants you to press.
const ACCENT: Color = Color(0.298, 0.478, 0.741)
const ACCENT_HOVER: Color = Color(0.365, 0.553, 0.824)
const ACCENT_PRESSED: Color = Color(0.235, 0.396, 0.639)

# --- Shape -------------------------------------------------------------------
const RADIUS_SM: int = 3
const RADIUS_MD: int = 5
const RADIUS_LG: int = 8

const BORDER_WIDTH: int = 1
## Thick enough to see at a glance and never mistaken for a border.
const FOCUS_WIDTH: int = 2

# --- Hit targets -------------------------------------------------------------
## Fitts's law: time to hit a target falls with its size. 40 px is comfortable
## with a mouse at this resolution and clears the 24 px WCAG 2.2 minimum with
## room to spare.
const CONTROL_HEIGHT: int = 40
const CONTROL_HEIGHT_SM: int = 32
## Square, and large enough to drag from without precision.
const SLOT_SIZE: int = 72

# --- Motion ------------------------------------------------------------------
## Fast enough not to be waited on. Anything over ~250 ms in an interface reads
## as lag rather than as polish.
const MOTION_FAST: float = 0.09
const MOTION_NORMAL: float = 0.16


## The font stack. A system font rather than a bundled one until there is an art
## direction to pick against -- and named explicitly, because Godot's default
## is a different face on every platform.
static func font() -> SystemFont:
	var face := SystemFont.new()
	face.font_names = PackedStringArray(["Inter", "Noto Sans", "DejaVu Sans", "sans-serif"])
	face.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return face


## A filled panel-ish box. The one place a StyleBoxFlat is built, so radius,
## border width and padding cannot drift apart between screens.
static func box(
	fill: Color,
	radius: int = RADIUS_MD,
	border: Color = Color.TRANSPARENT,
	border_width: int = 0,
	padding: int = SPACE_MD
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(radius)
	if border_width > 0:
		style.border_color = border
		style.set_border_width_all(border_width)
	style.set_content_margin_all(padding)
	return style


## An outline with nothing inside it, for focus rings.
static func outline(colour: Color, width: int = FOCUS_WIDTH, radius: int = RADIUS_MD) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = colour
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


## Relative luminance, for checking a colour before it ships.
##
## Here rather than in a spreadsheet so a test can assert the palette still
## passes when somebody nudges a colour -- which is exactly when it stops.
static func luminance(colour: Color) -> float:
	var channels := [colour.r, colour.g, colour.b]
	var linear: Array[float] = []
	for value: float in channels:
		linear.append(value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


## WCAG contrast ratio between two colours, from 1:1 to 21:1.
static func contrast(a: Color, b: Color) -> float:
	var high := maxf(luminance(a), luminance(b))
	var low := minf(luminance(a), luminance(b))
	return (high + 0.05) / (low + 0.05)
