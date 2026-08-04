extends TestCase
## The camera node: following, snapping and projection.

const CAMERA_SCENE: String = "res://prefabs/isometric_camera.tscn"
const CONFIG_RESOURCE: String = "res://resources/camera/default_camera.tres"

var _mounted: Array[Node] = []


func after_each() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func _mount(node: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(node)
	_mounted.append(node)
	return node


func _mount_camera() -> CameraController:
	return _mount(load(CAMERA_SCENE).instantiate()) as CameraController


## A stand-in for the player, which does not exist yet.
func _mount_target(at: Vector3) -> Node3D:
	var node := Node3D.new()
	_mount(node)
	node.global_position = at
	return node


func test_the_config_resource_loads() -> void:
	var config: CameraConfig = load(CONFIG_RESOURCE)
	assert_not_null(config, "%s missing or not a CameraConfig" % CONFIG_RESOURCE)
	assert_true(config.distance > 0.0)


func test_the_prefab_is_a_camera() -> void:
	var scene: PackedScene = load(CAMERA_SCENE)
	assert_not_null(scene, "%s is missing or malformed" % CAMERA_SCENE)
	var node: Node = scene.instantiate()
	assert_true(node is Camera3D, "the rig must actually be a camera")
	assert_true(node is CameraController)
	node.free()


func test_it_frames_the_fallback_when_there_is_no_target() -> void:
	# This is what keeps the world viewable before a player exists.
	var camera := _mount_camera()
	assert_null(camera.target())
	assert_eq(camera.focus(), camera.fallback_focus)
	assert_eq(camera.global_position, CameraFraming.position_for(Vector3.ZERO, camera.config))


func test_it_looks_at_what_it_frames() -> void:
	var camera := _mount_camera()
	var forward := -camera.global_transform.basis.z.normalized()
	var expected := (
		CameraFraming.aim_point(camera.focus(), camera.config) - camera.global_position
	).normalized()
	assert_true(forward.dot(expected) > 0.9999)


func test_snapping_jumps_straight_to_a_new_target() -> void:
	var camera := _mount_camera()
	var target := _mount_target(Vector3(30.0, 0.0, -12.0))
	camera.set_target(target)
	camera.snap_to_target()
	assert_eq(camera.focus(), target.global_position)


func test_following_eases_toward_the_target() -> void:
	var camera := _mount_camera()
	var target := _mount_target(Vector3(20.0, 0.0, 0.0))
	camera.set_target(target)

	# One frame must move part of the way, not all of it.
	camera.update_follow(1.0 / 60.0)
	assert_true(camera.focus().x > 0.0, "camera did not begin following")
	assert_true(camera.focus().x < target.global_position.x, "camera teleported instead of easing")


func test_following_converges_on_the_target() -> void:
	var camera := _mount_camera()
	var target := _mount_target(Vector3(20.0, 0.0, -5.0))
	camera.set_target(target)

	for _frame in 240:
		camera.update_follow(1.0 / 60.0)

	assert_true(
		camera.focus().distance_to(target.global_position) < 0.01,
		"camera never caught up (%f away)" % camera.focus().distance_to(target.global_position)
	)


func test_a_rigid_camera_arrives_in_one_frame() -> void:
	var camera := _mount_camera()
	camera.config = camera.config.duplicate()
	camera.config.follow_speed = 0.0
	var target := _mount_target(Vector3(7.0, 0.0, 3.0))
	camera.set_target(target)

	camera.update_follow(1.0 / 60.0)
	assert_eq(camera.focus(), target.global_position)


func test_clearing_the_target_returns_to_the_fallback() -> void:
	var camera := _mount_camera()
	var target := _mount_target(Vector3(50.0, 0.0, 50.0))
	camera.set_target(target)
	camera.snap_to_target()

	camera.set_target(null)
	assert_eq(camera.focus_goal(), camera.fallback_focus)


## A freed target must not crash the camera -- entities are despawned all the
## time, and the camera outlives them.
func test_a_freed_target_falls_back_instead_of_crashing() -> void:
	var camera := _mount_camera()
	var target := _mount_target(Vector3(9.0, 0.0, 9.0))
	camera.set_target(target)
	camera.snap_to_target()

	_mounted.erase(target)
	target.free()

	assert_eq(camera.focus_goal(), camera.fallback_focus)
	camera.update_follow(1.0 / 60.0)


func test_projection_follows_the_config() -> void:
	var camera := _mount_camera()
	camera.config = camera.config.duplicate()

	camera.config.orthographic = true
	camera.config.orthographic_size = 33.0
	camera.apply_projection()
	assert_eq(camera.projection, Camera3D.PROJECTION_ORTHOGONAL)
	assert_true(is_equal_approx(camera.size, 33.0))

	camera.config.orthographic = false
	camera.config.fov = 55.0
	camera.apply_projection()
	assert_eq(camera.projection, Camera3D.PROJECTION_PERSPECTIVE)
	assert_true(is_equal_approx(camera.fov, 55.0))
