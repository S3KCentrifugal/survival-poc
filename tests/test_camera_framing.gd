extends TestCase
## Camera framing maths.

const DISTANCE: float = 10.0

var yaw: float = 0.0
var pitch: float = deg_to_rad(45.0)


func before_each() -> void:
	yaw = 0.0
	pitch = deg_to_rad(45.0)


func _offset() -> Vector3:
	return CameraFraming.offset_from_focus(yaw, pitch, DISTANCE)


func _transform(focus: Vector3 = Vector3.ZERO, height: float = 0.0) -> Transform3D:
	return CameraFraming.transform_for(focus, height, yaw, pitch, DISTANCE)


func test_yaw_zero_puts_the_camera_on_positive_z() -> void:
	var offset := _offset()
	assert_true(is_zero_approx(offset.x), "expected no x offset at yaw 0, got %f" % offset.x)
	assert_true(offset.z > 0.0, "camera should sit on +Z at yaw 0")


func test_yaw_ninety_swings_the_camera_onto_positive_x() -> void:
	yaw = deg_to_rad(90.0)
	var offset := _offset()
	assert_true(offset.x > 0.0)
	assert_true(is_zero_approx(offset.z), "expected no z offset at yaw 90, got %f" % offset.z)


func test_distance_is_honoured_regardless_of_angle() -> void:
	for degrees_yaw: float in [0.0, 37.0, 90.0, 180.0, 315.0]:
		for degrees_pitch: float in [5.0, 30.0, 60.0, 89.0]:
			yaw = deg_to_rad(degrees_yaw)
			pitch = deg_to_rad(degrees_pitch)
			var offset := _offset()
			assert_true(
				is_equal_approx(offset.length(), DISTANCE),
				"yaw %f pitch %f gave distance %f" % [degrees_yaw, degrees_pitch, offset.length()]
			)


func test_a_steeper_pitch_raises_the_camera() -> void:
	pitch = deg_to_rad(20.0)
	var shallow := _offset().y
	pitch = deg_to_rad(70.0)
	var steep := _offset().y
	assert_true(steep > shallow, "70 degrees should sit higher than 20")


func test_focus_height_lifts_the_aim_point() -> void:
	var aim := CameraFraming.aim_point(Vector3(3.0, 0.0, -4.0), 2.5)
	assert_eq(aim, Vector3(3.0, 2.5, -4.0))


func test_the_camera_looks_at_the_focus() -> void:
	var focus := Vector3(5.0, 0.0, -2.0)
	var transform := _transform(focus)
	# A Camera3D looks down its local -Z.
	var forward := -transform.basis.z.normalized()
	var expected := (CameraFraming.aim_point(focus, 0.0) - transform.origin).normalized()
	assert_true(
		forward.dot(expected) > 0.9999,
		"camera is not aimed at its focus (dot %f)" % forward.dot(expected)
	)


func test_the_horizon_stays_level() -> void:
	# A rolled camera is the symptom of a transposed basis. The right vector
	# must stay horizontal at every angle.
	for degrees_yaw: float in [0.0, 45.0, 123.0, 270.0]:
		for degrees_pitch: float in [5.0, 45.0, 89.0]:
			yaw = deg_to_rad(degrees_yaw)
			pitch = deg_to_rad(degrees_pitch)
			var transform := _transform()
			assert_true(
				is_zero_approx(transform.basis.x.y),
				"rolled at yaw %f pitch %f (x.y = %f)"
				% [degrees_yaw, degrees_pitch, transform.basis.x.y]
			)


func test_framing_tracks_the_focus() -> void:
	var here := CameraFraming.position_for(Vector3.ZERO, 0.0, yaw, pitch, DISTANCE)
	var there := CameraFraming.position_for(Vector3(100.0, 0.0, 0.0), 0.0, yaw, pitch, DISTANCE)
	assert_true(is_equal_approx(there.x - here.x, 100.0), "camera did not move with the focus")


func test_pitch_cannot_reach_vertical() -> void:
	# At exactly 90 degrees looking_at is degenerate and the basis collapses.
	var config := CameraConfig.new()
	config.pitch_degrees = 90.0
	assert_true(config.pitch_degrees <= CameraConfig.MAX_PITCH_DEGREES)
	config.pitch_degrees = 1000.0
	assert_true(config.pitch_degrees <= CameraConfig.MAX_PITCH_DEGREES)
	pitch = config.pitch_radians()
	assert_true(_transform().basis.determinant() > 0.5, "basis collapsed near vertical")


func test_an_unobstructed_camera_keeps_its_distance() -> void:
	assert_true(is_equal_approx(CameraFraming.unobstructed_distance(5.0, 9.0, 0.25), 5.0))


func test_a_wall_pulls_the_camera_in_short_of_it() -> void:
	assert_true(is_equal_approx(CameraFraming.unobstructed_distance(5.0, 3.0, 0.25), 2.75))


## A camera pulled through its own focus ends up looking at the back of the
## character's head from inside it.
func test_a_wall_underfoot_cannot_push_the_camera_past_the_focus() -> void:
	assert_true(is_zero_approx(CameraFraming.unobstructed_distance(5.0, 0.1, 0.25)))
	assert_true(CameraFraming.unobstructed_distance(5.0, 0.0, 1.0) >= 0.0)


func test_smoothing_weight_is_bounded() -> void:
	assert_eq(CameraFraming.smoothing_weight(8.0, 0.0), 0.0, "no time, no movement")
	assert_true(CameraFraming.smoothing_weight(8.0, 1.0) < 1.0)
	assert_true(CameraFraming.smoothing_weight(8.0, 0.016) > 0.0)


func test_zero_speed_locks_the_camera_rigidly() -> void:
	assert_eq(CameraFraming.smoothing_weight(0.0, 0.016), 1.0)
	assert_eq(CameraFraming.smoothing_weight(-5.0, 0.016), 1.0)


## The reason the weight is exponential rather than `speed * delta`: two half
## steps must land exactly where one whole step does, or the camera behaves
## differently at 30 fps and 144 fps.
func test_smoothing_is_frame_rate_independent() -> void:
	var speed := 8.0
	var delta := 0.1

	var one_step := 1.0 * (1.0 - CameraFraming.smoothing_weight(speed, delta))

	var remaining := 1.0
	for _i in 2:
		remaining *= 1.0 - CameraFraming.smoothing_weight(speed, delta * 0.5)

	assert_true(
		is_equal_approx(one_step, remaining),
		"one step left %f, two half steps left %f" % [one_step, remaining]
	)
