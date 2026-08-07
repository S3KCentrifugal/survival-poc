class_name FrameStats
extends RefCounted
## A per-frame quantity, sampled over a run, and what may honestly be said
## about it.
##
## Used for the counts a shot reports -- draw calls, primitives, objects. They
## are not constant across a run: characters animate, mushrooms regrow, a
## wanderer walks behind a hill and stops being drawn. One frame's number is a
## sample, so the distribution is the measurement.
##
## [b]It is not milliseconds, and that was not the plan.[/b] Phase 0 set out to
## put a frame budget in milliseconds, on the reasoning that a per-viewport GPU
## timing from the renderer would be immune to the desktop -- the profiling that
## started this had produced 26 fps at 1080p, 43 at 720p, and 30 fps with the
## entire scene deleted, which is a measurement of X11 rather than of a game.
##
## [method RenderingServer.viewport_get_measured_render_time_gpu] turned out to
## be no better here. Rendering one shot at 640x360, 1280x720 and 3840x2160 --
## a 36-fold change in pixels -- produced 0.30 ms, 6.43 ms and 2.75 ms, with 4K
## reading *cheaper* than 720p; reversing the order changed every number and
## kept none of the ordering. Wall-clock time per frame sat at 19-29 ms whatever
## the resolution, because this machine cannot present a frame faster than that
## whatever is in it. Disabling vsync changed nothing, twice.
##
## So there is no millisecond figure on this desk that means anything, and a
## plausible number that means nothing is worse than no number -- somebody will
## quote it. Counts are exact, reproducible to the unit, independent of the
## machine, and they are what actually moves when geometry is added. They are
## also the thing Phase 3 needs, because dense foliage is a draw-call problem
## before it is anything else.

var _samples: PackedFloat64Array = PackedFloat64Array()

## Sorted lazily, because samples arrive one per frame and sorting each time
## would cost more than the thing being measured.
var _sorted: PackedFloat64Array = PackedFloat64Array()
var _sorted_is_stale: bool = true


## Records one frame's value.
##
## Zero is a real sample -- a shot with no shadow-casting geometry genuinely
## draws no shadows. Negative and non-finite are not; they mean the source did
## not answer, and averaging them in produces a number that looks like a very
## good frame.
func add(value: float) -> void:
	if value < 0.0 or not is_finite(value):
		return
	_samples.append(value)
	_sorted_is_stale = true


func count() -> int:
	return _samples.size()


func is_empty() -> bool:
	return _samples.is_empty()


func clear() -> void:
	_samples.clear()
	_sorted_is_stale = true


## The typical frame. Use this, not [method mean].
func median() -> float:
	return percentile(0.5)


## The value at [param fraction] through the sorted samples, 0 to 1.
##
## Nearest-rank rather than interpolated. With a few hundred samples the
## difference is noise, and a rank is a frame that actually happened -- which is
## easier to reason about than a number between two frames.
func percentile(fraction: float) -> float:
	if _samples.is_empty():
		return 0.0
	var ordered := _ordered()
	var rank := int(ceil(clampf(fraction, 0.0, 1.0) * ordered.size())) - 1
	return ordered[clampi(rank, 0, ordered.size() - 1)]


## Here to be compared against [method median], not to be quoted on its own. A
## mean well above the median is the signature of a spike.
func mean() -> float:
	if _samples.is_empty():
		return 0.0
	var total: float = 0.0
	for sample: float in _samples:
		total += sample
	return total / _samples.size()


func worst() -> float:
	return percentile(1.0)


## The 95th percentile over the median: how lumpy the run is.
##
## 1.0 is a perfectly even one. Past about 1.5 the numbers should not be quoted
## as a measurement of anything, because whatever is causing the spread is
## larger than most changes being measured.
func spread() -> float:
	var middle := median()
	return percentile(0.95) / middle if middle > 0.0 else 1.0


## Whether this set is worth drawing a conclusion from.
##
## Two ways to fail: too few frames, or too noisy. Both produce a number that
## looks authoritative, which is the danger -- a measurement nobody trusts gets
## re-run, and a measurement nobody *should* trust gets acted on.
func is_stable(minimum_samples: int = 30, maximum_spread: float = 1.5) -> bool:
	return count() >= minimum_samples and spread() <= maximum_spread


## Whether the typical frame fits [param budget]. A budget of 0 means none.
##
## Judged on the median rather than the worst frame. The alternative is a budget
## that fails whenever a wanderer happens to walk into shot, which is a test
## that fails for reasons nobody changed.
func within_budget(budget: float) -> bool:
	return budget <= 0.0 or median() <= budget


## "88 typical, 91 p95, 94 worst (120 frames)".
func summary(unit: String = "") -> String:
	if is_empty():
		return "no samples"
	var suffix := (" " + unit) if not unit.is_empty() else ""
	return "%.0f%s typical, %.0f p95, %.0f worst (%d frames)" % [
		median(), suffix, percentile(0.95), worst(), count()
	]


func _ordered() -> PackedFloat64Array:
	if _sorted_is_stale:
		_sorted = _samples.duplicate()
		_sorted.sort()
		_sorted_is_stale = false
	return _sorted
