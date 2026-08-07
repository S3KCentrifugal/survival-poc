class_name Atmosphere
extends RefCounted
## What the air looks like, given how high the sun is.
##
## The same shape as [SkyGradient] and for the same reason: it takes an
## elevation and returns numbers, with no shader, no node and no clock in it. So
## "is there still light in the sky ten minutes after sunset?" is a test with a
## figure in it rather than a screenshot somebody has to squint at — which
## matters here more than usual, because the thing being fixed was invisible to
## everyone for forty-two features.
##
## Elevation is the sun's height as a fraction of straight up: -1 is midnight
## under your feet, 0 is exactly on the horizon, 1 is directly overhead.
##
## Colours are derived from [SkyGradient] rather than declared, so the fog and
## the ambient are always made of the sky the player can see. `ART.md` rule 2
## says depth is air; this is what makes the air the right colour for the hour.

var _sky: SkyGradient


func _init(sky_config: SkyConfig) -> void:
	_sky = SkyGradient.new(sky_config)


## How much skylight there is, 0 at full night rising to 1 in full daylight.
##
## The curve the whole phase turns on. The sun's own light stops the instant it
## crosses the horizon — that is what a horizon is — and the previous code let
## the world go with it, which is why the dusk shot measured 71% below the
## readable floor while the sky above it was still orange.
##
## This keeps skylight through [constant ArtTokens.AFTERGLOW_BAND] below the
## horizon, so the moment of sunset still has about half of it. That is not a
## fudge: the sky is a lit dome long after the sun is behind the hill, and the
## ground is lit by the dome.
func skylight_amount(elevation: float) -> float:
	var span := ArtTokens.TWILIGHT_BAND + ArtTokens.AFTERGLOW_BAND
	return clampf((elevation + ArtTokens.AFTERGLOW_BAND) / maxf(span, 0.01), 0.0, 1.0)


## Ambient strength.
func ambient_energy(elevation: float) -> float:
	return lerpf(ArtTokens.AMBIENT_NIGHT, ArtTokens.AMBIENT_DAY, skylight_amount(elevation))


## The flat colour ambient falls back to as the sky stops being able to provide
## one.
##
## Blended toward the sky's own horizon colour as day comes up, so that on the
## way in and out of night the fallback is never a colour the sky is not
## wearing — the same argument [method SkyGradient.ground_color] makes.
func ambient_color(elevation: float) -> Color:
	return ArtTokens.AMBIENT_NIGHT_COLOR.lerp(
		_sky.horizon_color(elevation), skylight_amount(elevation)
	)


## How much of the ambient is taken from the sky cubemap rather than
## [method ambient_color].
##
## The specific fix for the night bug. Godot's sky ambient reads the rendered
## sky, and this project's night sky is very nearly black by design — so an
## ambient sourced entirely from it is an ambient of nothing, and every surface
## not facing the moon renders black. Below the horizon the flat colour takes
## over completely.
func sky_contribution(elevation: float) -> float:
	return lerpf(
		ArtTokens.AMBIENT_SKY_AT_NIGHT, ArtTokens.AMBIENT_SKY_BY_DAY, skylight_amount(elevation)
	)


## What colour the air is.
##
## Pulled most of the way to the sky's horizon colour and then desaturated.
## Fully saturated fog reads as a filter over the lens; fog exactly matching the
## horizon swallows the skyline of every distant hill, which is the silhouette
## the depth cue depends on.
func fog_color(elevation: float) -> Color:
	var horizon := _sky.horizon_color(elevation)
	var tinted := horizon.darkened(1.0 - ArtTokens.FOG_SKY_TINT)
	return _desaturated(tinted, ArtTokens.FOG_DESATURATION)


## How thick the air is.
##
## Denser through dawn and dusk, which is both true — a low sun travels a long
## way through the thick part of the atmosphere — and the hour it flatters most.
func fog_density(elevation: float) -> float:
	var dusk := _sky.dusk_amount(elevation)
	return lerpf(ArtTokens.FOG_DENSITY, ArtTokens.FOG_DENSITY_DUSK, dusk)


## Tonemapper exposure.
##
## Lifted at night, and this is not papering over the ambient term: a night
## frame sits in the bottom eighth of the range, and a tonemapper handed that
## has almost no curve left to work with. The lift buys back the contrast the
## curve would otherwise spend.
func exposure(elevation: float) -> float:
	return lerpf(ArtTokens.EXPOSURE_NIGHT, ArtTokens.EXPOSURE_DAY, skylight_amount(elevation))


## Moves [param colour] toward its own luminance by [param amount].
##
## Toward grey of the *same brightness*, not toward grey — desaturating through
## Color.srgb_to_linear and back would darken the fog as it drained it, and the
## fog would then be doing two things when it was asked to do one.
static func _desaturated(colour: Color, amount: float) -> Color:
	var grey := UiTokens.luminance(colour)
	# Back out of linear luminance into something comparable with the sRGB
	# channels being blended, or a "desaturated" colour comes out far too dark.
	var level := pow(clampf(grey, 0.0, 1.0), 1.0 / 2.2)
	return Color(
		lerpf(colour.r, level, amount),
		lerpf(colour.g, level, amount),
		lerpf(colour.b, level, amount),
		colour.a
	)
