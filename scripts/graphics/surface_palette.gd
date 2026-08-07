class_name SurfacePalette
extends RefCounted
## Which brightness band a surface belongs to, and how to get it there.
##
## `ART.md` rule 3 is the reason this exists: a character has to sit at least
## 3:1 in luminance against what is immediately behind them, and the project
## measured 1.0-1.2:1 in every single shot. Phase 1 established that no amount
## of lighting moves that number, because it is not a lighting problem -- the
## robot's albedo simply sits at almost exactly the luminance of grass, of the
## building walls and of the floor.
##
## The fix is a value structure: every surface is assigned a band, and the bands
## are far enough apart that the gap between them *is* the silhouette. Ground
## low, structures in the middle, characters high.
##
## Pure arithmetic, so the thing rule 3 turns on can be checked in the headless
## suite rather than only in a rendered frame.

## What kind of surface this is, which decides which band it is pulled into.
enum Band {
	## Terrain. The floor of the value structure, and the thing everything else
	## is read against.
	GROUND,
	## Walls, floors, buildings. Between the ground and the actors, so a
	## character reads against a wall as well as against grass.
	STRUCTURE,
	## Items, mushrooms, the workbench. Slightly above structures so a thing you
	## can pick up separates from the thing it is sitting on.
	PROP,
	## Anything that moves and matters. The top of the structure.
	CHARACTER,
}


## Target relative luminance for each band.
static func value_of(band: Band) -> float:
	match band:
		Band.GROUND:
			return ArtTokens.VALUE_GROUND
		Band.STRUCTURE:
			return ArtTokens.VALUE_STRUCTURE
		Band.PROP:
			return ArtTokens.VALUE_PROP
		_:
			return ArtTokens.VALUE_CHARACTER


## How firmly a surface of this kind is pulled into its band.
##
## Not 1.0 for anything: at full strength every surface in a band renders at
## exactly one brightness, which flattens a character into a paper cut-out and
## loses the shading that says what shape it is. The band is a target to sit
## near, not a colour to become.
static func strength_of(band: Band) -> float:
	match band:
		Band.GROUND:
			return ArtTokens.VALUE_STRENGTH_GROUND
		Band.CHARACTER:
			return ArtTokens.VALUE_STRENGTH_CHARACTER
		_:
			return ArtTokens.VALUE_STRENGTH_OTHER


## Pulls [param colour] toward [param target] brightness, keeping its hue.
##
## Scaled rather than mixed toward a grey of that brightness: mixing would
## desaturate as it moved, so a green field pulled down would come out sludge
## rather than dark green -- which fails rule 1 while fixing rule 3.
##
## Takes and returns an sRGB [Color] but does the work in **linear**, because
## that is the space the shader's ALBEDO is in and the two have to agree. The
## first version scaled the sRGB channels directly and asking it for 0.25 gave
## back 0.41 -- a formula that was wrong in exactly the way that leaves the
## picture looking plausible.
##
## NOTE: `stylised_to_band()` in `shaders/stylised.gdshaderinc` is this formula
## in GLSL, for textured surfaces. It needs no conversion because ALBEDO is
## already linear. If you change one, change both.
static func to_band(colour: Color, target: float, amount: float) -> Color:
	var linear := colour.srgb_to_linear()
	var level := maxf(
		0.2126 * linear.r + 0.7152 * linear.g + 0.0722 * linear.b, 0.0001
	)
	var scale := target / level
	var moved := Color(
		clampf(lerpf(linear.r, linear.r * scale, amount), 0.0, 1.0),
		clampf(lerpf(linear.g, linear.g * scale, amount), 0.0, 1.0),
		clampf(lerpf(linear.b, linear.b * scale, amount), 0.0, 1.0),
		colour.a
	)
	var result := moved.linear_to_srgb()
	result.a = colour.a
	return result


## The colour a surface of [param band] ends up as.
static func in_band(colour: Color, band: Band) -> Color:
	return to_band(colour, value_of(band), strength_of(band))


## The WCAG-style contrast between two bands, before any lighting.
##
## What rule 3 is asking for, computed from the tokens alone -- so the value
## structure can be asserted to satisfy the rule without rendering anything, and
## a change to the palette that quietly closes the gap fails in the suite rather
## than in a screenshot.
static func contrast_between(a: Band, b: Band) -> float:
	var high := maxf(value_of(a), value_of(b))
	var low := minf(value_of(a), value_of(b))
	return (high + 0.05) / (low + 0.05)
