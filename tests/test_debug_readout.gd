extends TestCase
## The debug overlay's text, which is the thing most likely to be read at a
## glance while something else is on fire.


func test_an_empty_bar_is_all_dashes() -> void:
	assert_eq(DebugReadout.bar(0.0, 4), "[----]")


func test_a_full_bar_is_all_hashes() -> void:
	assert_eq(DebugReadout.bar(1.0, 4), "[####]")


func test_a_bar_fills_proportionally() -> void:
	assert_eq(DebugReadout.bar(0.5, 4), "[##--]")


func test_a_bar_is_always_its_full_width() -> void:
	for step in 21:
		var text := DebugReadout.bar(float(step) / 20.0, 10)
		assert_eq(text.length(), 12, "%f rendered as %s" % [float(step) / 20.0, text])


## The overlay is most useful in exactly the situation that produced the NaN.
func test_a_nan_fraction_reads_as_empty_rather_than_full() -> void:
	assert_eq(DebugReadout.bar(sqrt(-1.0), 4), "[----]")


func test_a_fraction_outside_the_range_is_clamped() -> void:
	assert_eq(DebugReadout.bar(5.0, 4), "[####]")
	assert_eq(DebugReadout.bar(-5.0, 4), "[----]")


func test_a_vital_shows_a_bar_and_its_numbers() -> void:
	var line := DebugReadout.vital("health", 50.0, 100.0)
	assert_true(line.begins_with("health"), "got %s" % line)
	assert_true(line.contains("[#####-----]"), "got %s" % line)
	assert_true(line.contains("50 / 100"), "got %s" % line)


func test_a_vital_with_no_maximum_does_not_divide_by_zero() -> void:
	var line := DebugReadout.vital("health", 0.0, 0.0)
	assert_true(line.contains("[----------]"), "got %s" % line)
	assert_false(line.contains("nan"), "got %s" % line)


## A falling actor reading 20 m/s tells you nothing about how fast it travels.
func test_speed_ignores_the_vertical() -> void:
	var line := DebugReadout.speed(Vector3(3.0, -40.0, 4.0), false)
	assert_true(line.contains("5.00 m/s"), "got %s" % line)


func test_sprinting_is_called_out() -> void:
	assert_true(DebugReadout.speed(Vector3.ZERO, true).contains("sprint"))
	assert_false(DebugReadout.speed(Vector3.ZERO, false).contains("sprint"))


func test_position_reads_as_three_numbers() -> void:
	var line := DebugReadout.position(Vector3(1.25, -2.0, 30.5))
	assert_true(line.contains("1.2, -2.0, 30.5"), "got %s" % line)


func test_the_clock_says_which_side_of_the_horizon_it_is() -> void:
	assert_true(DebugReadout.clock("12:00", true).contains("(day)"))
	assert_true(DebugReadout.clock("00:00", false).contains("(night)"))


## A line that disappears makes the panel jump, and you cannot tell "no such
## component" from "I forgot to add the line".
func test_something_unwatched_still_gets_a_line() -> void:
	var line := DebugReadout.absent("stamina")
	assert_true(line.begins_with("stamina"), "got %s" % line)
	assert_true(line.contains(DebugReadout.ABSENT))


func test_labels_line_up() -> void:
	var lines: PackedStringArray = [
		DebugReadout.frames_per_second(60),
		DebugReadout.clock("06:00", true),
		DebugReadout.position(Vector3.ZERO),
		DebugReadout.speed(Vector3.ZERO, false),
		DebugReadout.vital("health", 1.0, 1.0),
		DebugReadout.absent("stamina"),
	]
	for line: String in lines:
		var value_starts := line.find(" ", 0)
		assert_true(
			line.substr(0, DebugReadout.LABEL_WIDTH).length() == DebugReadout.LABEL_WIDTH,
			"short label in %s" % line
		)
		assert_true(value_starts <= DebugReadout.LABEL_WIDTH, "ragged label in %s" % line)
