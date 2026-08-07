class_name ImageDiff
extends RefCounted
## How different two rendered frames are.
##
## The measurement under golden-image regression: a frame that was captured
## before a change and the same frame captured after it, with a number for how
## far apart they are. Without one, "improve the lighting" is a leap -- there is
## no way to assert that the eleven shots which should *not* have changed did
## not.
##
## Deliberately not pixel-exact. Two runs of the same scene on the same machine
## differ slightly (temporal antialiasing, floating-point ordering in the
## renderer), and a driver update moves every pixel a little. A test that fails
## on that gets disabled within a week, which is worse than no test. So the
## comparison is a tolerance, and the tolerance is stated.
##
## Works entirely on [Image], which is CPU-side -- so this is testable in the
## headless suite even though nothing headless can render.

## Whether the two images could be compared at all.
var comparable: bool = false

## False when the sizes differ, which is a failure in itself rather than a
## difference: a golden is stored at a fixed size and a shot that arrives at
## another one means the harness changed, not the picture.
var size_matches: bool = false

## Mean per-pixel difference, 0 for identical and 1 for black against white.
##
## The headline number. Averaged over the whole frame, so a large subtle shift
## (a colour grade, an exposure change) shows up here and a small violent one
## barely does -- which is why [member changed_fraction] exists as well.
var mean_difference: float = 0.0

## The single most different pixel.
var max_difference: float = 0.0

## Fraction of pixels that moved further than the per-pixel threshold.
##
## Catches the opposite case to [member mean_difference]: a new object in one
## corner changes very few pixels by a lot, and the mean hides it.
var changed_fraction: float = 0.0

var pixels_compared: int = 0


## The default per-pixel threshold: below this a pixel counts as unchanged.
##
## About five steps of 255, which is above renderer noise and below anything a
## person would call a difference.
const PIXEL_THRESHOLD: float = 0.02

## The default whole-frame tolerance for [method within].
const MEAN_TOLERANCE: float = 0.006

## The default share of pixels allowed to have moved.
const CHANGED_TOLERANCE: float = 0.02


## Compares two images.
##
## Neither is modified. Both are converted to RGB8 first, so a golden saved as
## PNG and a capture taken as RGBA are compared on equal terms rather than
## differing everywhere in an alpha channel neither of them uses.
static func compare(a: Image, b: Image, threshold: float = PIXEL_THRESHOLD) -> ImageDiff:
	var report := ImageDiff.new()
	if a == null or b == null or a.is_empty() or b.is_empty():
		return report
	report.size_matches = a.get_size() == b.get_size()
	if not report.size_matches:
		return report

	# Byte arrays rather than get_pixel(): a 480x270 golden is 130k pixels and
	# a per-pixel call into the engine for each one turns a check into a wait.
	var left := as_rgb8(a).get_data()
	var right := as_rgb8(b).get_data()
	var count := mini(left.size(), right.size()) / 3

	var total: float = 0.0
	var worst: float = 0.0
	var changed: int = 0
	for index in count:
		var at := index * 3
		var difference: float = (
			absi(left[at] - right[at])
			+ absi(left[at + 1] - right[at + 1])
			+ absi(left[at + 2] - right[at + 2])
		) / 765.0  # 3 channels x 255
		total += difference
		if difference > worst:
			worst = difference
		if difference > threshold:
			changed += 1

	report.comparable = count > 0
	report.pixels_compared = count
	report.mean_difference = total / maxf(float(count), 1.0)
	report.max_difference = worst
	report.changed_fraction = float(changed) / maxf(float(count), 1.0)
	return report


## Whether the difference is small enough to call the frame unchanged.
##
## Both conditions, not either: a frame can pass on the mean by being subtly
## wrong everywhere, or pass on the fraction by being violently wrong in one
## place. It has to pass both to be the same picture.
func within(
	mean_tolerance: float = MEAN_TOLERANCE, changed_tolerance: float = CHANGED_TOLERANCE
) -> bool:
	return (
		comparable
		and size_matches
		and mean_difference <= mean_tolerance
		and changed_fraction <= changed_tolerance
	)


## A picture of where the two differ, for writing next to a failure.
##
## Amplified, because an honest difference image of a real regression is almost
## black and tells nobody anything. This is a diagnostic, not a measurement --
## the numbers are the measurement.
static func difference_image(a: Image, b: Image, gain: float = 8.0) -> Image:
	if a == null or b == null or a.get_size() != b.get_size():
		return null
	var left := as_rgb8(a).get_data()
	var right := as_rgb8(b).get_data()
	var out := PackedByteArray()
	out.resize(mini(left.size(), right.size()))
	for at in out.size():
		out[at] = mini(int(absi(left[at] - right[at]) * gain), 255)
	return Image.create_from_data(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8, out)


## A capture reduced to the size a golden is stored at.
##
## Goldens live in the repository, and a repository this project keeps small.
## A 1280x720 PNG per shot would be a megabyte each; at 270 lines it is tens of
## kilobytes and still catches every change worth catching, because a regression
## that survives a 4.7x downscale is not a subtle one.
##
## [constant Image.INTERPOLATE_LANCZOS] on purpose: bilinear downscaling
## discards most of the pixels it is given, so two frames differing in fine
## detail can resize to the same image and pass a test they should fail.
static func to_golden(source: Image, height: int) -> Image:
	if source == null or source.is_empty() or height <= 0:
		return null
	var scaled := as_rgb8(source)
	if scaled.get_height() != height:
		var width := maxi(int(round(source.get_width() * float(height) / source.get_height())), 1)
		scaled.resize(width, height, Image.INTERPOLATE_LANCZOS)
	return scaled


## "mean 0.4%, 1.2% of pixels moved, worst 31%", for a tool's output.
func summary() -> String:
	if not size_matches:
		return "different sizes"
	if not comparable:
		return "not comparable"
	return "mean %.2f%%, %.2f%% of pixels moved, worst %.1f%%" % [
		mean_difference * 100.0, changed_fraction * 100.0, max_difference * 100.0
	]


## A copy in RGB8. Copied rather than converted in place -- the caller's golden
## is very often a cached resource, and converting it would edit everyone's.
##
## Public because [FrameLook] needs the same guarantee: every measurement in the
## project reads pixels the same way, or two numbers about one frame disagree
## because one of them was looking at an alpha channel.
static func as_rgb8(source: Image) -> Image:
	var copy := Image.new()
	copy.copy_from(source)
	if copy.get_format() != Image.FORMAT_RGB8:
		copy.convert(Image.FORMAT_RGB8)
	return copy
