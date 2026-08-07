class_name RenderBudget
extends RefCounted
## How many pixels the 3D scene is allowed to cost, whatever the display is.
##
## The problem this exists for: Godot renders the 3D scene at the output
## resolution, and the output resolution is whatever the monitor happens to be.
## The machine this was written on has a 6144x3456 screen, so going fullscreen
## asked the renderer for **21 megapixels** -- ten times 1080p -- with nothing
## anywhere saying that might be a bad idea. It is not a measurement artefact
## and it is not specific to this desk: a tester on a 4K display gets 8.3
## megapixels for the same reason, and the only target that was ever safe is the
## Steam Deck, by the accident of being 1280x800.
##
## The fix is not to cap the *window*. A game that refuses to fill a nice monitor
## is worse than one that runs slowly, and the interface should still be crisp at
## native size. What has to be capped is the **3D render resolution** --
## [member Viewport.scaling_3d_scale] -- leaving the UI at full resolution and
## upscaling the world into it. That is the cheapest large performance win in
## the renderer and nobody notices it in motion.
##
## Pure arithmetic, so the policy can be tested without a display. See
## [SettingsApplier] for where it is applied and GRAPHICS.md for the reasoning.

## The most 3D pixels to render before scaling starts, near enough to 1440p.
##
## Chosen rather than derived: 1440p is where this project's art stops gaining
## from more resolution, and it means 1080p and 1440p displays render natively
## while 4K and above start paying for their size. Raise it when the art is good
## enough to be worth it -- that is a real decision, which is why it is a named
## constant and not a magic number in an if.
const DEFAULT_PIXELS: int = 3_686_400  # 2560 x 1440

## The scales offered, coarse on purpose.
##
## A continuous scale means a resize changes the number every frame and no two
## machines ever report the same one, which makes a performance figure
## impossible to compare. Six rungs are enough.
const LADDER: Array[float] = [0.5, 0.6, 0.7, 0.8, 0.9, 1.0]

## Never below this, even on a display that blows the budget several times over.
##
## Below about half, bilinear upscaling is visible as a soft, swimming image and
## the cure is worse than the disease. A display that still costs too much at 0.5
## needs FSR, which is a Phase 7 decision -- so the floor is a deliberate refusal
## to fix this the cheap way, not an oversight.
const MIN_SCALE: float = 0.5

const MAX_SCALE: float = 1.0


## The 3D render scale for an output of [param output] pixels.
##
## Returns [constant MAX_SCALE] whenever the display already fits the budget, so
## the common cases -- 1080p, 1440p, the Deck -- are untouched and cost nothing.
static func scale_for(output: Vector2i, budget: int = DEFAULT_PIXELS) -> float:
	var pixels := output.x * output.y
	if pixels <= 0 or budget <= 0 or pixels <= budget:
		return MAX_SCALE
	# Squared, because the scale applies to both axes: a scale of 0.5 renders a
	# quarter of the pixels, not half. Getting this wrong gives a number that
	# looks plausible and misses the budget by 2x.
	return snap(sqrt(float(budget) / float(pixels)))


## The largest rung at or below [param wanted], never under [constant MIN_SCALE].
##
## Rounds *down*, so snapping can only ever come in under the budget. Rounding to
## nearest would let a display sit above it, which defeats the point of having
## one.
static func snap(wanted: float) -> float:
	var best: float = MIN_SCALE
	for rung: float in LADDER:
		if rung <= wanted and rung > best:
			best = rung
	return clampf(best, MIN_SCALE, MAX_SCALE)


## How many pixels the 3D scene actually costs at [param scale].
##
## The number to quote when reporting what a change bought, because "render
## scale 0.7" means nothing without the display it was on.
static func rendered_pixels(output: Vector2i, scale: float) -> int:
	return int(round(float(output.x * output.y) * scale * scale))


## Whether [param output] is large enough for the budget to do anything.
##
## For the settings menu, which should say "Auto (100%)" rather than implying it
## is protecting a 1080p player from something.
static func is_capped(output: Vector2i, budget: int = DEFAULT_PIXELS) -> bool:
	return scale_for(output, budget) < MAX_SCALE


## "3840x2160 -> 70% (4.1 MP)", for a menu label or a tool's output.
static func describe(output: Vector2i, budget: int = DEFAULT_PIXELS) -> String:
	var scale := scale_for(output, budget)
	return "%dx%d -> %d%% (%.1f MP)" % [
		output.x,
		output.y,
		int(round(scale * 100.0)),
		rendered_pixels(output, scale) / 1_000_000.0,
	]
