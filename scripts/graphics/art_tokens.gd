class_name ArtTokens
extends RefCounted
## The art direction, as numbers.
##
## `ART.md` rule 8: every number the atmosphere is built from lives here and
## nowhere else, generated into whatever consumes it. Constants rather than a
## resource for the same reason [UiTokens] is — a design system that can be
## edited per-scene is not a design system, and the eighty-four per-node
## overrides that rule came from are the same mistake one layer down.
##
## [b]What this does not own.[/b] The sun's own colour and energy belong to
## [DayNightConfig], and the sky's palette to [SkyConfig]; both are resources
## the sky shader and the light already read, and copying them here would put a
## second version of each somewhere nobody looks. This owns the *atmosphere*:
## the ambient term, the fog, and the tonemapper — the three things that were
## previously nowhere at all, which is why the game had no night.
##
## [Atmosphere] turns these into per-elevation values; [AtmosphereComponent]
## pushes them onto the [Environment]. Nothing reads them directly.

# --- Tonemapping --------------------------------------------------------------
## AgX rather than the Filmic the project shipped with.
##
## Filmic clips hard into saturated highlights, which is the opposite of a
## painterly look; AgX rolls off and desaturates as it goes, which is what makes
## a bright sky sit next to a lit hillside without either going to paste.
const TONEMAP: Environment.ToneMapper = Environment.TONE_MAPPER_AGX

## Where the tonemapper puts pure white. Higher keeps more highlight detail and
## flattens the image; 6 is a compromise found by rendering all seven shots.
const TONEMAP_WHITE: float = 6.0

## Exposure by day, and the lift applied at night.
##
## The night lift is doing real work rather than papering over the ambient
## term: even with a moon, a night frame sits in the bottom eighth of the range
## and a tonemapper given that has almost no curve left to work with.
const EXPOSURE_DAY: float = 1.15
const EXPOSURE_NIGHT: float = 1.45

# --- Ambient ------------------------------------------------------------------
## Ambient energy at full daylight and at full night.
##
## `ART.md` rule 4: a shadow is a surface lit by skylight, not an absence of
## light. The night figure is the one that matters — the project measured 100%
## of its night frame below the readable floor because the ambient term at
## night was, in effect, zero.
const AMBIENT_DAY: float = 1.0
const AMBIENT_NIGHT: float = 0.75

## How much of the ambient comes from the sky cubemap rather than
## [constant AMBIENT_NIGHT_COLOR].
##
## By day the sky *is* the right answer and its own gradient does the tinting.
## At night the sky shader outputs very nearly black, so a cubemap-only ambient
## is a black ambient — which is exactly the bug. Below the horizon the flat
## moonlight colour takes over.
const AMBIENT_SKY_BY_DAY: float = 1.0
const AMBIENT_SKY_AT_NIGHT: float = 0.0

## Moonlight. Blue and desaturated, because `ART.md` rule 6 says night is blue
## and quiet rather than black, and because a warm night reads as a fire.
const AMBIENT_NIGHT_COLOR: Color = Color(0.30, 0.40, 0.66)

# --- Skylight curve -----------------------------------------------------------
## How far *below* the horizon skylight persists, as a fraction of straight up.
##
## The fix for the finding that dusk was already night. The sun's own light is
## gone the moment it sets and the previous code took the whole world with it,
## so 71% of the dusk frame was below the readable floor while the sky above it
## was still orange. Real dusk keeps a lit sky for a good while after sunset;
## this is that, and it costs one clamp.
const AFTERGLOW_BAND: float = 0.22

## Elevation above which it is unambiguously daytime. Matches
## [member DayNightConfig.twilight_band] and [member SkyConfig.twilight_band],
## which is the whole point: the light, the sky and the atmosphere have to
## change together or the frame comes apart at dawn.
const TWILIGHT_BAND: float = 0.25

# --- Fog ----------------------------------------------------------------------
## `ART.md` rule 2: depth is air, not detail. Fog here is the art direction and
## not an effect, so these are the most consequential numbers in the file.

## Exponential density. Tuned against `world-noon`, whose hills sit 100–200 m
## out: enough that distance reads, little enough that the middle ground stays
## crisp.
const FOG_DENSITY: float = 0.0022

## Extra density through dawn and dusk, when low sun through thick air is
## actually hazier — and when it flatters the frame most.
const FOG_DENSITY_DUSK: float = 0.0040

## Distant geometry takes the sky's colour. This is aerial perspective itself;
## at 0 the fog is a flat wash and the depth cue goes with it.
const FOG_AERIAL_PERSPECTIVE: float = 1.0

## How much the fog tints the sky as well as the world. Low on purpose: the sky
## is already the colour the fog is made of, and fogging it again turns the
## whole upper half of the frame to milk.
const FOG_SKY_AFFECT: float = 0.08

## How much light from the sun's direction scatters forward through the fog.
const FOG_SUN_SCATTER: float = 0.22

## Fog is pulled toward the sky's horizon colour but never all the way.
##
## At full strength the fog is exactly the horizon and the silhouette of every
## distant hill disappears into it; pulling it most of the way and leaving it
## slightly darker keeps the skyline.
const FOG_SKY_TINT: float = 0.85

## Saturation the fog is left at, relative to the sky it is drawn from.
##
## Air is not as colourful as the sky it scatters, and a fully saturated orange
## fog at sunset reads as a filter over the lens rather than as distance.
const FOG_DESATURATION: float = 0.35
