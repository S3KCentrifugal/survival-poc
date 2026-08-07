class_name ShotResult
extends RefCounted
## What came back from taking one [ShotConfig]: a picture, what it cost to draw,
## or a reason it failed.
##
## A struct rather than a return tuple because these travel together and every
## caller needs all of them -- the tool that writes PNGs, the tool that compares
## against goldens, and the report at the end of a run.

var shot: ShotConfig

## The captured frame at full [member ShotConfig.resolution], or null if the
## shot failed.
var image: Image

## Draw calls issued for what the camera can see, per frame.
##
## The headline cost. It is a count rather than a time because no timing on this
## machine survived being checked -- see [FrameStats] for the three ways that was
## established. A count is exact, the same on every machine, and is what moves
## when geometry is added.
var draw_calls: FrameStats = FrameStats.new()

var primitives: FrameStats = FrameStats.new()

var objects: FrameStats = FrameStats.new()

## The shadow pass, counted separately, and it is not a footnote: every shot
## measured draws three to four times as many primitives into the shadow map as
## into the frame -- 665,000 against 207,000 in the vista, 525,000 against
## 131,000 looking at bare ground. The directional light renders the whole
## 256-metre heightfield regardless of where the camera is pointing. Nothing in
## the project knew that before there was a harness to ask.
var shadow_draw_calls: FrameStats = FrameStats.new()

var shadow_primitives: FrameStats = FrameStats.new()

## What can be measured about how the frame looks, as opposed to what it cost.
##
## Measured at golden size rather than full resolution: it is the image the
## goldens compare, it is seven times faster to walk, and no measurement here is
## sensitive to the difference.
var look: FrameLook = FrameLook.new()

## Where the player is on screen, normalised 0-1, or negative if they are not
## in frame. Normalised so it survives being scaled to golden size.
var subject_point: Vector2 = -Vector2.ONE

## How tall the player appears, as a share of the frame height. Normalised for
## the same reason, and needed because a subject measurement taken with a disc
## the wrong size measures the background instead.
var subject_height: float = 0.0

## Empty when the shot worked.
var error: String = ""


func ok() -> bool:
	return error.is_empty() and image != null and not image.is_empty()


## Whether the frame fits the shot's budgets. Unbudgeted shots always pass.
func within_budget() -> bool:
	if shot == null:
		return true
	return over_budget_reason().is_empty()


## Why it does not fit, in English, or an empty string.
##
## Every breach is listed rather than the first one. A change that pushes three
## counts over at once is one change, and reporting it three times is how the
## cause gets found in one pass instead of three.
func over_budget_reason() -> String:
	if shot == null:
		return ""
	var reasons := PackedStringArray()
	_note(reasons, draw_calls, shot.draw_call_budget, "draw calls")
	_note(reasons, primitives, shot.primitive_budget, "primitives")
	_note(reasons, shadow_draw_calls, shot.shadow_draw_call_budget, "shadow draw calls")
	_note(reasons, shadow_primitives, shot.shadow_primitive_budget, "shadow primitives")
	return ", ".join(reasons)


static func _note(into: PackedStringArray, measured: FrameStats, budget: int, what: String) -> void:
	if not measured.within_budget(budget):
		into.append("%.0f %s against %d allowed" % [measured.median(), what, budget])


## Why the frame breaks the art direction, in English, or an empty string.
##
## Separate from [method over_budget_reason] because they are different
## failures with different fixes: one says the frame costs too much, this says
## it is the wrong picture. `ART.md` is what these numbers are checking.
func look_problems() -> String:
	if shot == null:
		return ""
	var found := PackedStringArray()
	if not look.is_readable(shot.max_dark_fraction):
		found.append("%.0f%% of the frame is too dark to read, against %.0f%% allowed" % [
			look.dark_fraction * 100.0, shot.max_dark_fraction * 100.0
		])
	if not look.is_coherent(shot.max_hue_count):
		found.append("%d distinct hues against %d allowed" % [
			look.hue_count, shot.max_hue_count
		])
	if not look.subject_stands_out(shot.min_subject_contrast):
		found.append(
			"the player stands out at %.1f:1 against %.1f:1 required" % [
				look.subject_contrast, shot.min_subject_contrast
			]
			if look.subject_measured
			else "the player could not be found in the frame to measure"
		)
	return ", ".join(found)


## "  88 draws + 155 shadow    207k prims +  665k shadow", for a tool's output.
##
## The shadow figure is never hidden behind a flag. It is larger than the visible
## one, and a cost report that omits the larger half teaches the wrong lesson
## about where the frame goes.
func cost() -> String:
	return "%4.0f draws +%4.0f shadow  %5.0fk prims +%5.0fk shadow" % [
		draw_calls.median(),
		shadow_draw_calls.median(),
		primitives.median() / 1000.0,
		shadow_primitives.median() / 1000.0,
	]


## One line for the run's report.
func summary() -> String:
	if not ok():
		return "%s: FAILED -- %s" % [shot.shot_name if shot != null else "?", error]
	return "%s  %dx%d  %s" % [shot.shot_name, image.get_width(), image.get_height(), cost()]
