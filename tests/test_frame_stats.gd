extends TestCase
## A per-frame quantity sampled over a run, and what may honestly be said about
## a set of samples.


func _run(samples: Array[float]) -> FrameStats:
	var stats := FrameStats.new()
	for sample: float in samples:
		stats.add(sample)
	return stats


## An even run with one spike in it -- a wanderer walking into shot. The mean
## says this is fine and the p95 says it is not, which is the argument for
## reporting a distribution rather than an average.
func _one_spike() -> FrameStats:
	var samples: Array[float] = []
	for _index in 99:
		samples.append(88.0)
	samples.append(400.0)
	return _run(samples)


func test_an_empty_set_reports_nothing_rather_than_zero() -> void:
	var stats := FrameStats.new()
	assert_true(stats.is_empty())
	assert_eq(stats.median(), 0.0)
	assert_eq(stats.summary(), "no samples")


## Zero is a real count: a shot with nothing casting a shadow genuinely draws no
## shadows, and dropping those frames would report the shadow pass as busier
## than it is.
func test_zero_is_a_real_sample() -> void:
	var stats := _run([0.0, 0.0, 4.0, 4.0])
	assert_eq(stats.count(), 4)
	assert_eq(stats.median(), 0.0)


func test_a_nonsense_reading_is_refused() -> void:
	var stats := FrameStats.new()
	stats.add(-1.0)
	stats.add(INF)
	stats.add(NAN)
	assert_eq(stats.count(), 0, "a nonsense reading became a measurement")


func test_the_median_is_the_typical_frame() -> void:
	assert_eq(_run([1.0, 2.0, 3.0, 4.0, 5.0]).median(), 3.0)


func test_the_median_ignores_the_order_samples_arrived_in() -> void:
	assert_eq(_run([5.0, 1.0, 4.0, 2.0, 3.0]).median(), 3.0)


func test_the_percentile_is_a_frame_that_actually_happened() -> void:
	# Nearest-rank rather than interpolated: a rank is easier to reason about
	# than a number sitting between two frames.
	var stats := _run([1.0, 2.0, 3.0, 4.0, 5.0])
	assert_eq(stats.percentile(0.0), 1.0)
	assert_eq(stats.percentile(1.0), 5.0)
	assert_eq(stats.worst(), 5.0)


func test_a_percentile_outside_the_range_is_clamped_rather_than_indexed() -> void:
	var stats := _run([1.0, 2.0, 3.0])
	assert_eq(stats.percentile(-5.0), 1.0)
	assert_eq(stats.percentile(9.0), 3.0)


## The point of the class, stated as an assertion: ninety-nine ordinary frames
## and one spike average out to something that looks fine.
func test_a_single_spike_is_invisible_in_the_mean_and_obvious_in_the_tail() -> void:
	var stats := _one_spike()
	assert_eq(stats.median(), 88.0)
	assert_true(stats.mean() < 92.0, "the mean was %f, so the spike was not hidden" % stats.mean())
	assert_eq(stats.worst(), 400.0, "the tail lost the spike")


func test_an_even_run_has_no_spread() -> void:
	assert_eq(_run([5.0, 5.0, 5.0, 5.0]).spread(), 1.0)


func test_a_lumpy_run_says_so() -> void:
	var stats := _run([4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 4.0, 40.0, 40.0])
	assert_true(stats.spread() > 1.5, "spread was %f on a run that doubles" % stats.spread())


## A run of all zeroes would divide by zero, and the natural answer -- "perfectly
## even" -- is also the correct one.
func test_a_run_of_nothing_at_all_does_not_divide_by_zero() -> void:
	assert_eq(_run([0.0, 0.0, 0.0]).spread(), 1.0)


## A measurement nobody should trust gets acted on, which is worse than one
## nobody trusts -- so the numbers come with a verdict on whether they are worth
## quoting.
func test_too_few_frames_is_not_a_measurement() -> void:
	assert_false(_run([4.0, 4.0, 4.0]).is_stable(), "three frames counted as stable")


func test_a_noisy_run_is_not_a_measurement_however_many_frames_it_has() -> void:
	var samples: Array[float] = []
	for index in 200:
		samples.append(4.0 if index % 2 == 0 else 40.0)
	assert_false(_run(samples).is_stable(), "a run alternating 10x counted as stable")


func test_a_long_even_run_is_a_measurement() -> void:
	var samples: Array[float] = []
	for _index in 200:
		samples.append(4.0)
	assert_true(_run(samples).is_stable())


## Judged on the median rather than the worst frame. The alternative is a budget
## that fails whenever a wanderer happens to walk into shot, which is a test
## that fails for reasons nobody changed.
func test_the_budget_is_judged_on_the_typical_frame_not_the_worst_one() -> void:
	assert_true(_one_spike().within_budget(100.0), "one spike failed a budget the run fits")


func test_a_run_that_is_simply_too_heavy_fails_its_budget() -> void:
	assert_false(_run([180.0, 180.0, 180.0]).within_budget(100.0))


func test_no_budget_is_always_met() -> void:
	assert_true(_run([5000.0]).within_budget(0.0))


func test_clearing_forgets_everything_including_the_sort() -> void:
	var stats := _run([1.0, 2.0, 3.0])
	stats.clear()
	stats.add(9.0)
	assert_eq(stats.median(), 9.0, "the cleared samples came back")


## Samples arrive one per frame, so the set is sorted lazily. A second read
## after a further sample must see the new one.
func test_a_sample_added_after_a_read_changes_the_answer() -> void:
	var stats := _run([1.0, 1.0, 1.0])
	assert_eq(stats.median(), 1.0)
	for _index in 10:
		stats.add(50.0)
	assert_eq(stats.median(), 50.0, "the stale sort survived a new sample")


func test_it_reports_itself_in_words() -> void:
	var text := _one_spike().summary("draws")
	assert_true(text.contains("88 draws typical"), text)
	assert_true(text.contains("100 frames"), text)
