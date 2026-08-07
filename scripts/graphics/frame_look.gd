class_name FrameLook
extends RefCounted
## What can be measured about how a rendered frame looks.
##
## `ART.md` is the art direction; this is the part of it that is a number rather
## than an opinion. The split is the one `UI.md` and [method UiTokens.contrast]
## already proved works: state the rule, then measure the thing the rule is
## about, so a change can be checked instead of admired.
##
## It does not and cannot say whether a frame looks good. It says whether the
## frame is crushed to black, blown out, incoherent in hue, or has a character
## the player cannot pick out of the grass -- four ways of being objectively
## wrong that a golden image cannot catch, because a golden only knows whether
## something *changed*.
##
## Works on an [Image], which is CPU-side, so it runs in the headless suite.

## Relative luminance below which a pixel carries no readable detail.
##
## Linear, not sRGB: 0.004 is about sRGB 0.07.
##
## [b]Calibrated, after being guessed wrong.[/b] The first value here was 0.015,
## picked before there was any frame to check it against. It turned out not to
## discriminate at all: it called the pre-Phase-1 night frame -- a black screen
## you genuinely could not play in -- 100% dark, and the frame that replaced it,
## which is plainly readable, 90% dark. A measure that gives the same answer
## either side of the fix it exists to verify is not a measure.
##
## Re-derived from those two frames, which bracket the thing being asked about:
##
## [codeblock]
##                    <0.0005  <0.0010  <0.0020  <0.0040  <0.0080  <0.0150
## night, unplayable      67%      72%      78%      78%     100%     100%
## night, readable         0%       0%       0%      11%      86%      90%
## dusk, before            0%       0%       0%      64%      67%      71%
## dusk, after             0%       0%       0%       0%      20%      51%
## [/codeblock]
##
## 0.004 separates them with room on both sides. Everything from 0.008 up is
## measuring how dark a night is, which is not the question -- night is supposed
## to be dark. The question is whether anything in it can be made out.
const DARK: float = 0.004

## Above this a pixel is blown out and its detail is gone for good.
const BRIGHT: float = 0.95

## Hues are counted in buckets this wide, in degrees.
##
## Twelve buckets. Finer than that and ordinary dithering in a texture reads as
## a dozen separate hues; coarser and a genuinely incoherent frame passes.
const HUE_BUCKET_DEGREES: float = 30.0

## A hue bucket holding less than this share of the coloured pixels is noise
## rather than a colour the frame is using.
const HUE_PRESENCE: float = 0.02

## Pixels below this saturation are grey and have no hue worth counting;
## below this value they are too dark for their hue to be visible.
const HUE_MIN_SATURATION: float = 0.15
const HUE_MIN_VALUE: float = 0.10

## Mean relative luminance of the frame, 0 to 1.
var mean_luminance: float = 0.0

## Share of the frame below [constant DARK]. The night-readability number: a
## frame that is 90% below this is a frame nobody can play in.
var dark_fraction: float = 0.0

## Share of the frame above [constant BRIGHT].
var bright_fraction: float = 0.0

## The 5th and 95th percentiles of luminance -- how much of the available range
## the frame actually uses.
##
## Reported rather than enforced, because the right answer is style. A painterly
## look deliberately uses *less* range than a photographic one; what it must not
## do is use none.
var low_luminance: float = 0.0
var high_luminance: float = 0.0

## How many distinct hues the frame is built from.
##
## Cohesion is most of what "Nintendo quality" means and this is the part of it
## that is countable. A frame drawing from four hues reads as designed; one
## drawing from eleven reads as assembled from whatever was to hand.
var hue_count: int = 0

## Share of the coloured pixels sitting in the single largest hue bucket.
var dominant_hue_share: float = 0.0

## Luminance contrast between the subject and what is immediately behind it,
## as a WCAG-style ratio from 1:1 to 21:1.
##
## Zero when no subject was given. The measurement `UI.md` makes for text,
## pointed at a character standing in grass -- if the player cannot be told from
## the background, that is a number and not a matter of taste.
var subject_contrast: float = 0.0

var subject_measured: bool = false

var pixels: int = 0


## Measures [param image], optionally around a subject at [param subject] in
## pixel coordinates and [param subject_height] pixels tall.
##
## Pass [param subject] as a negative vector, or leave it out, for a frame with
## no subject in it -- a landscape has nothing to separate from anything.
##
## [param subject_height] is how tall the subject actually appears, which the
## caller knows and this cannot work out. A fixed disc was the first attempt and
## it measured mostly grass whenever the character was more than a few metres
## away: the wide gameplay shot reported 1.0:1 for a player who is plainly
## visible in it, because the disc was four times the size of the thing it was
## supposed to be sampling.
static func measure(
	image: Image, subject: Vector2i = -Vector2i.ONE, subject_height: int = 0
) -> FrameLook:
	var look := FrameLook.new()
	if image == null or image.is_empty():
		return look

	var frame := ImageDiff.as_rgb8(image)
	var data := frame.get_data()
	var width := frame.get_width()
	var height := frame.get_height()
	var to_linear := _srgb_table()

	# A histogram rather than a list of samples: at 480x270 a frame is 130,000
	# pixels, and a sortable array of those costs more than everything else here
	# put together.
	var buckets := PackedInt32Array()
	buckets.resize(1024)
	var hues := PackedFloat64Array()
	hues.resize(int(360.0 / HUE_BUCKET_DEGREES))

	var total: float = 0.0
	var dark := 0
	var bright := 0
	var coloured: float = 0.0
	var count := data.size() / 3

	for index in count:
		var at := index * 3
		var red := to_linear[data[at]]
		var green := to_linear[data[at + 1]]
		var blue := to_linear[data[at + 2]]
		var luminance := 0.2126 * red + 0.7152 * green + 0.0722 * blue
		total += luminance
		if luminance < DARK:
			dark += 1
		elif luminance > BRIGHT:
			bright += 1
		buckets[clampi(int(luminance * 1023.0), 0, 1023)] += 1

		var high := maxi(maxi(data[at], data[at + 1]), data[at + 2])
		var low := mini(mini(data[at], data[at + 1]), data[at + 2])
		if high == 0 or float(high) / 255.0 < HUE_MIN_VALUE:
			continue
		if float(high - low) / float(high) < HUE_MIN_SATURATION:
			continue
		hues[_hue_bucket(data[at], data[at + 1], data[at + 2], high, low)] += 1.0
		coloured += 1.0

	look.pixels = count
	look.mean_luminance = total / maxf(float(count), 1.0)
	look.dark_fraction = float(dark) / maxf(float(count), 1.0)
	look.bright_fraction = float(bright) / maxf(float(count), 1.0)
	look.low_luminance = _percentile(buckets, count, 0.05)
	look.high_luminance = _percentile(buckets, count, 0.95)

	for weight: float in hues:
		if coloured > 0.0 and weight / coloured >= HUE_PRESENCE:
			look.hue_count += 1
		look.dominant_hue_share = maxf(
			look.dominant_hue_share, weight / coloured if coloured > 0.0 else 0.0
		)

	if subject.x >= 0 and subject.y >= 0 and subject.x < width and subject.y < height:
		look._measure_subject(data, width, height, subject, subject_height, to_linear)
	return look


## Contrast between a disc on the subject and the ring of background around it.
##
## A ring rather than the whole frame: what matters is whether the character
## separates from what is *immediately* behind them. A dark player against a
## dark forest reads as invisible even in a frame with a bright sky in it.
##
## Both radii come from the subject's own on-screen height, and both had to.
## The first version used a fixed disc and sampled grass for any character more
## than a few metres away. The second sized the disc correctly but put the
## background ring at three times its radius, which for a close-up is still
## inside the silhouette -- so it compared the character against itself and
## dutifully reported 1.0:1.
func _measure_subject(
	data: PackedByteArray,
	width: int,
	height: int,
	at: Vector2i,
	subject_height: int,
	to_linear: PackedFloat64Array
) -> void:
	# Fractions of the subject's own height. 0.15 sits well inside the torso;
	# a humanoid is roughly a quarter as wide as it is tall, so 0.45 clears the
	# silhouette with room and 0.95 stays close enough to be the background
	# immediately behind them rather than the whole frame.
	var scale := float(subject_height) if subject_height > 0 else height * 0.18
	var inner := maxi(int(scale * 0.15), 2)
	var near := maxi(int(scale * 0.45), inner + 2)
	var outer := maxi(int(scale * 0.95), near + 2)
	var subject_total: float = 0.0
	var subject_count := 0
	var around_total: float = 0.0
	var around_count := 0

	for y in range(maxi(at.y - outer, 0), mini(at.y + outer + 1, height)):
		for x in range(maxi(at.x - outer, 0), mini(at.x + outer + 1, width)):
			var offset := Vector2(x - at.x, y - at.y)
			var distance := offset.length()
			if distance > outer:
				continue
			var index := (y * width + x) * 3
			var luminance := (
				0.2126 * to_linear[data[index]]
				+ 0.7152 * to_linear[data[index + 1]]
				+ 0.0722 * to_linear[data[index + 2]]
			)
			if distance <= inner:
				subject_total += luminance
				subject_count += 1
			elif distance >= near:
				# The gap between inner and near is skipped on purpose: the
				# pixels either side of a silhouette are a blend of both and
				# would drag the two means together, making a well-separated
				# character look worse than it is.
				around_total += luminance
				around_count += 1

	if subject_count == 0 or around_count == 0:
		return
	subject_measured = true
	var subject_luminance := subject_total / subject_count
	var around_luminance := around_total / around_count
	var lighter := maxf(subject_luminance, around_luminance)
	var darker := minf(subject_luminance, around_luminance)
	subject_contrast = (lighter + 0.05) / (darker + 0.05)


## Whether the frame is bright enough to be played in.
##
## Named for what it is asking rather than for the number, because "is
## dark_fraction under 0.55" is not a question anyone has.
func is_readable(max_dark: float) -> bool:
	return max_dark <= 0.0 or dark_fraction <= max_dark


func is_coherent(max_hues: int) -> bool:
	return max_hues <= 0 or hue_count <= max_hues


func subject_stands_out(minimum: float) -> bool:
	return minimum <= 0.0 or (subject_measured and subject_contrast >= minimum)


## "mean 0.21, 34% dark, 4 hues, subject 3.1:1", for a tool's output.
func summary() -> String:
	var subject := (
		"subject %.1f:1" % subject_contrast if subject_measured else "no subject"
	)
	return "mean %.3f  %.0f%% dark  %.0f%% blown  %d hues (%.0f%% dominant)  %s" % [
		mean_luminance,
		dark_fraction * 100.0,
		bright_fraction * 100.0,
		hue_count,
		dominant_hue_share * 100.0,
		subject,
	]


static func _hue_bucket(red: int, green: int, blue: int, high: int, low: int) -> int:
	var delta := float(high - low)
	var hue: float = 0.0
	if high == red:
		hue = 60.0 * fposmod((green - blue) / delta, 6.0)
	elif high == green:
		hue = 60.0 * ((blue - red) / delta + 2.0)
	else:
		hue = 60.0 * ((red - green) / delta + 4.0)
	return clampi(int(hue / HUE_BUCKET_DEGREES), 0, int(360.0 / HUE_BUCKET_DEGREES) - 1)


static func _percentile(buckets: PackedInt32Array, total: int, fraction: float) -> float:
	if total <= 0:
		return 0.0
	var wanted := int(fraction * total)
	var seen := 0
	for index in buckets.size():
		seen += buckets[index]
		if seen >= wanted:
			return float(index) / float(buckets.size() - 1)
	return 1.0


## sRGB byte to linear, precomputed.
##
## The conversion is a `pow` per channel, and a 480x270 frame is 390,000 of
## them. There are only 256 possible inputs.
static var _table: PackedFloat64Array


static func _srgb_table() -> PackedFloat64Array:
	if not _table.is_empty():
		return _table
	var built := PackedFloat64Array()
	built.resize(256)
	for value in 256:
		var channel := value / 255.0
		built[value] = (
			channel / 12.92 if channel <= 0.04045 else pow((channel + 0.055) / 1.055, 2.4)
		)
	_table = built
	return _table
