extends TestCase
## The clock, the sun's arc, and the light it casts.

var _config: DayNightConfig


func before_each() -> void:
	_config = DayNightConfig.new()
	_config.day_length_seconds = 100.0
	_config.start_time = 0.0
	_config.sun_tilt_degrees = 20.0
	_config.twilight_band = 0.25
	_config.day_energy = 1.0
	_config.night_energy = 0.05


func _at(time: float) -> DayNightCycle:
	_config.start_time = time
	return DayNightCycle.new(_config)


func test_it_starts_where_the_config_says() -> void:
	assert_true(is_equal_approx(_at(0.3).time_of_day, 0.3))


func test_a_start_time_outside_the_day_is_wrapped() -> void:
	assert_true(is_equal_approx(_at(1.25).time_of_day, 0.25))
	assert_true(is_equal_approx(_at(-0.25).time_of_day, 0.75))


func test_a_full_day_returns_to_the_start() -> void:
	var cycle := _at(0.0)
	cycle.advance(_config.day_length_seconds)
	assert_true(is_zero_approx(cycle.time_of_day), "landed at %f" % cycle.time_of_day)


func test_the_clock_wraps_through_midnight() -> void:
	var cycle := _at(0.9)
	cycle.advance(_config.day_length_seconds * 0.2)
	assert_true(is_equal_approx(cycle.time_of_day, 0.1), "landed at %f" % cycle.time_of_day)


func test_advancing_is_frame_rate_independent() -> void:
	var coarse := _at(0.0)
	coarse.advance(10.0)

	var fine := _at(0.0)
	for _frame in 100:
		fine.advance(0.1)

	assert_true(is_equal_approx(coarse.time_of_day, fine.time_of_day))


## A frozen sun is a much easier bug to read than a NaN clock.
func test_a_zero_length_day_freezes_instead_of_dividing_by_zero() -> void:
	_config.day_length_seconds = 0.0
	var cycle := _at(0.4)
	cycle.advance(10.0)
	assert_true(is_equal_approx(cycle.time_of_day, 0.4))
	assert_false(is_nan(cycle.time_of_day))


func test_the_sun_rises_in_the_east_and_sets_in_the_west() -> void:
	var sunrise := _at(0.25).sun_position()
	assert_true(is_equal_approx(sunrise.x, 1.0), "sunrise was at %v" % sunrise)
	assert_true(is_zero_approx(sunrise.y), "sunrise was not on the horizon")

	var sunset := _at(0.75).sun_position()
	assert_true(is_equal_approx(sunset.x, -1.0), "sunset was at %v" % sunset)
	assert_true(is_zero_approx(sunset.y))


func test_the_sun_is_highest_at_noon_and_lowest_at_midnight() -> void:
	assert_true(_at(0.5).sun_elevation() > 0.9, "noon sun was low")
	assert_true(_at(0.0).sun_elevation() < -0.9, "midnight sun was up")


## Straight through the zenith leaves the basis that aims the light degenerate,
## and stamps midday shadows underfoot where they read as no shadow at all.
func test_the_sun_never_passes_exactly_overhead() -> void:
	for step in 200:
		var elevation := _at(float(step) / 200.0).sun_elevation()
		assert_true(elevation < 0.999, "the sun reached the zenith at %f" % elevation)


func test_the_arc_stays_on_the_unit_sphere() -> void:
	for step in 50:
		var length := _at(float(step) / 50.0).sun_position().length()
		assert_true(is_equal_approx(length, 1.0), "sun position had length %f" % length)


func test_light_travels_away_from_the_sun() -> void:
	var cycle := _at(0.5)
	assert_true(cycle.sun_direction().is_equal_approx(-cycle.sun_position()))


func test_it_is_day_between_sunrise_and_sunset() -> void:
	assert_true(_at(0.3).is_daytime())
	assert_true(_at(0.5).is_daytime())
	assert_true(_at(0.7).is_daytime())
	assert_false(_at(0.0).is_daytime())
	assert_false(_at(0.9).is_daytime())


func test_the_light_is_strongest_at_noon() -> void:
	assert_true(is_equal_approx(_at(0.5).light_energy(), _config.day_energy))


## A pitch-black night is not atmosphere, it is a bug report.
func test_the_night_keeps_a_little_light() -> void:
	var energy := _at(0.0).light_energy()
	assert_true(is_equal_approx(energy, _config.night_energy))
	assert_true(energy > 0.0)


func test_dawn_is_dimmer_than_morning() -> void:
	var dawn := _at(0.26).light_energy()
	var morning := _at(0.35).light_energy()
	assert_true(dawn < morning, "dawn %f, morning %f" % [dawn, morning])
	assert_true(dawn >= _config.night_energy)


func test_the_light_warms_toward_the_horizon() -> void:
	var noon := _at(0.5).light_color()
	var dusk := _at(0.74).light_color()
	assert_true(dusk.r - dusk.b > noon.r - noon.b, "dusk was no warmer than noon")


func test_night_has_its_own_colour() -> void:
	assert_eq(_at(0.0).light_color(), _config.night_color)


func test_the_clock_reads_as_hours_and_minutes() -> void:
	assert_eq(_at(0.0).time_string(), "00:00")
	assert_eq(_at(0.25).time_string(), "06:00")
	assert_eq(_at(0.5).time_string(), "12:00")
	assert_eq(_at(0.75).time_string(), "18:00")


## 23:59 plus a minute is midnight, not 24:00.
func test_the_clock_never_reads_twenty_four() -> void:
	var cycle := _at(0.0)
	cycle.time_of_day = 0.99999
	assert_eq(cycle.time_string(), "00:00")


func test_hours_run_from_zero_to_twenty_four() -> void:
	assert_true(is_equal_approx(_at(0.5).hours(), 12.0))


## A basis written out from computed axes is transposed as often as not, and a
## rolled sun is a diagonal horizon nobody notices until it is in a screenshot.
func test_the_basis_aims_the_light_along_its_direction() -> void:
	for time: float in [0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9]:
		var direction := _at(time).sun_direction()
		var basis := DayNightCycle.sun_basis(direction)
		# A light shines along its local -Z.
		assert_true(
			(-basis.z).is_equal_approx(direction.normalized()),
			"at %f the light pointed %v instead of %v" % [time, -basis.z, direction]
		)


func test_the_basis_is_not_skewed() -> void:
	var basis := DayNightCycle.sun_basis(_at(0.4).sun_direction())
	assert_true(is_equal_approx(basis.x.length(), 1.0))
	assert_true(is_equal_approx(basis.y.length(), 1.0))
	assert_true(is_zero_approx(basis.x.dot(basis.y)))


func test_a_vertical_direction_still_produces_a_usable_basis() -> void:
	# Not reachable through a tilted arc, but a config is free to be edited.
	var basis := DayNightCycle.sun_basis(Vector3.DOWN)
	assert_true((-basis.z).is_equal_approx(Vector3.DOWN))
	assert_false(is_nan(basis.x.x), "degenerate up vector produced a NaN basis")


func test_a_zero_direction_does_not_produce_a_nan_basis() -> void:
	var basis := DayNightCycle.sun_basis(Vector3.ZERO)
	assert_false(is_nan(basis.x.x))
