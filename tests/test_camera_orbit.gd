extends TestCase
## Where the camera points from, and the limits on where it may point.

var _config: CameraConfig


func before_each() -> void:
	_config = CameraConfig.new()
	_config.yaw_degrees = 0.0
	_config.pitch_degrees = 20.0
	_config.distance = 5.0
	_config.look_sensitivity = 0.25
	_config.min_pitch_degrees = 3.0
	_config.max_pitch_degrees = 75.0
	_config.min_distance = 1.5
	_config.max_distance = 14.0
	_config.zoom_step = 1.0
	_config.zoom_speed = 0.0  # snap, so zoom tests do not have to run frames


func _orbit() -> CameraOrbit:
	return CameraOrbit.new(_config)


func test_it_starts_where_the_config_says() -> void:
	var orbit := _orbit()
	assert_true(is_zero_approx(orbit.yaw))
	assert_true(is_equal_approx(orbit.pitch, deg_to_rad(20.0)))
	assert_true(is_equal_approx(orbit.distance, 5.0))


## Pushing the mouse right swings the camera right, which is the way round
## every third-person game does it.
func test_moving_the_mouse_right_turns_the_camera_right() -> void:
	var orbit := _orbit()
	orbit.look(Vector2(100.0, 0.0))
	# Turning right means the camera swings anticlockwise about +Y, so that the
	# world appears to move left.
	assert_true(orbit.yaw < 0.0, "yaw went %f" % orbit.yaw)
	assert_true(is_equal_approx(orbit.yaw, -deg_to_rad(25.0)))


func test_pulling_the_mouse_back_tips_the_view_down() -> void:
	var orbit := _orbit()
	var before := orbit.pitch
	orbit.look(Vector2(0.0, 40.0))
	assert_true(orbit.pitch > before, "pitch went from %f to %f" % [before, orbit.pitch])


func test_inverting_pitch_swaps_it() -> void:
	_config.invert_pitch = true
	var orbit := _orbit()
	var before := orbit.pitch
	orbit.look(Vector2(0.0, 40.0))
	assert_true(orbit.pitch < before)


func test_sensitivity_scales_the_turn() -> void:
	_config.look_sensitivity = 0.5
	var fast := _orbit()
	fast.look(Vector2(100.0, 0.0))
	_config.look_sensitivity = 0.25
	var slow := _orbit()
	slow.look(Vector2(100.0, 0.0))
	assert_true(is_equal_approx(fast.yaw, slow.yaw * 2.0))


func test_a_still_mouse_does_not_drift() -> void:
	var orbit := _orbit()
	orbit.look(Vector2.ZERO)
	assert_true(is_zero_approx(orbit.yaw))
	assert_true(is_equal_approx(orbit.pitch, deg_to_rad(20.0)))


## Yaw has to wrap, or spinning in one direction walks the number off toward
## the edge of what a float can say.
func test_yaw_wraps_rather_than_running_away() -> void:
	var orbit := _orbit()
	for _turn in 200:
		orbit.look(Vector2(100.0, 0.0))
	assert_true(absf(orbit.yaw) <= PI + 0.001, "yaw ran to %f" % orbit.yaw)


## Straight down is where looking_at is degenerate and the view spins; the
## horizon is where a third-person camera ends up staring at the ground.
func test_pitch_stops_short_of_both_ends() -> void:
	var orbit := _orbit()
	for _pull in 100:
		orbit.look(Vector2(0.0, 100.0))
	assert_true(orbit.pitch <= deg_to_rad(75.0) + 0.001, "tipped to %f" % rad_to_deg(orbit.pitch))

	for _push in 200:
		orbit.look(Vector2(0.0, -100.0))
	assert_true(orbit.pitch >= deg_to_rad(3.0) - 0.001, "tipped to %f" % rad_to_deg(orbit.pitch))


func test_a_backwards_pitch_range_is_straightened_out() -> void:
	_config.min_pitch_degrees = 70.0
	_config.max_pitch_degrees = 10.0
	var orbit := _orbit()
	orbit.look(Vector2(0.0, 1000.0))
	assert_true(orbit.pitch <= deg_to_rad(70.0) + 0.001)
	assert_true(orbit.pitch >= deg_to_rad(10.0) - 0.001)


func test_the_wheel_pulls_the_camera_out_and_in() -> void:
	var orbit := _orbit()
	orbit.zoom(1.0)
	orbit.advance(1.0)
	assert_true(is_equal_approx(orbit.distance, 6.0), "at %f" % orbit.distance)

	orbit.zoom(-2.0)
	orbit.advance(1.0)
	assert_true(is_equal_approx(orbit.distance, 4.0))


func test_zoom_stops_at_its_limits() -> void:
	var orbit := _orbit()
	for _notch in 50:
		orbit.zoom(1.0)
	orbit.advance(1.0)
	assert_true(is_equal_approx(orbit.distance, 14.0), "zoomed out to %f" % orbit.distance)

	for _notch in 50:
		orbit.zoom(-1.0)
	orbit.advance(1.0)
	assert_true(is_equal_approx(orbit.distance, 1.5), "zoomed in to %f" % orbit.distance)


## Snapping the whole way on each notch reads as a jolt, so the wheel sets a
## target and the camera slides to it.
func test_zoom_slides_rather_than_jumping() -> void:
	_config.zoom_speed = 10.0
	var orbit := _orbit()
	orbit.zoom(4.0)
	assert_true(is_equal_approx(orbit.distance, 5.0), "the wheel moved the camera immediately")
	assert_true(is_equal_approx(orbit.wanted_distance, 9.0))

	orbit.advance(1.0 / 60.0)
	assert_true(orbit.distance > 5.0 and orbit.distance < 9.0, "at %f" % orbit.distance)


func test_zoom_arrives_where_it_was_sent() -> void:
	_config.zoom_speed = 10.0
	var orbit := _orbit()
	orbit.zoom(3.0)
	for _frame in 300:
		orbit.advance(1.0 / 60.0)
	assert_true(is_equal_approx(orbit.distance, 8.0), "settled at %f" % orbit.distance)


func test_settling_skips_the_slide() -> void:
	_config.zoom_speed = 10.0
	var orbit := _orbit()
	orbit.zoom(3.0)
	orbit.settle()
	assert_true(is_equal_approx(orbit.distance, 8.0))


## A node faces its local -Z and the camera sits at +Z of its own yaw, so
## matching the two puts the camera at the target's back.
func test_placing_behind_matches_the_target_yaw() -> void:
	var orbit := _orbit()
	orbit.place_behind(deg_to_rad(90.0))
	assert_true(is_equal_approx(orbit.yaw, deg_to_rad(90.0)))

	var offset := CameraFraming.offset_from_focus(orbit.yaw, 0.0, 5.0)
	# Facing +90 degrees about Y means facing -X, so the camera belongs on +X.
	assert_true(offset.x > 4.9, "camera ended up at %v instead of behind" % offset)
