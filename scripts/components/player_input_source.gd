class_name PlayerInputSource
extends InputSource
## Intent from the local human: keyboard for movement, cursor for aim.
##
## The only place in the project that reads the [Input] singleton. Everything
## downstream sees an [InputState] and cannot tell a person from a bot.

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_MOVE_FORWARD: StringName = &"move_forward"
const ACTION_MOVE_BACK: StringName = &"move_back"
const ACTION_SPRINT: StringName = &"sprint"

## Every action this source depends on, so a test can assert the InputMap
## actually defines them.
const REQUIRED_ACTIONS: Array[StringName] = [
	ACTION_MOVE_LEFT,
	ACTION_MOVE_RIGHT,
	ACTION_MOVE_FORWARD,
	ACTION_MOVE_BACK,
	ACTION_SPRINT,
]

## Used to turn screen input into world directions. Without one, movement falls
## back to world axes and aim cannot resolve.
var camera: Camera3D

## Height of the plane the cursor is projected onto. Set this to the actor's
## foot height so aim stays level with them.
var aim_plane_height: float = 0.0


func _init(p_camera: Camera3D = null) -> void:
	camera = p_camera


func poll() -> InputState:
	var state := InputState.new()

	var raw := Input.get_vector(
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK
	)
	state.move = to_world_direction(raw, camera_yaw())
	state.sprint = Input.is_action_pressed(ACTION_SPRINT)

	var aim: Variant = resolve_aim()
	if aim != null:
		state.aim_point = aim
		state.has_aim = true

	return state


## Yaw the movement axes are rotated by. Zero (world-aligned) with no camera.
func camera_yaw() -> float:
	if not is_instance_valid(camera):
		return 0.0
	return yaw_from_basis(camera.global_transform.basis)


## Where the cursor meets the aim plane, or null if it never does.
func resolve_aim() -> Variant:
	if not is_instance_valid(camera):
		return null
	var viewport := camera.get_viewport()
	if viewport == null:
		return null
	var screen := viewport.get_mouse_position()
	return ground_intersection(
		camera.project_ray_origin(screen),
		camera.project_ray_normal(screen),
		aim_plane_height
	)


## Ground yaw a camera is looking along.
##
## A camera looks down its local -Z, so +Z points back toward where it sits.
static func yaw_from_basis(basis: Basis) -> float:
	return atan2(basis.z.x, basis.z.z)


## Rotates raw stick/key input into world space.
##
## [param raw] follows [method Input.get_vector]'s convention: +x is right and
## +y is *backwards*, because the forward action is the negative-y one.
static func to_world_direction(raw: Vector2, yaw: float) -> Vector2:
	# At yaw 0 the camera sits on +Z looking toward -Z, so "away from camera"
	# is -Z and "right" is +X.
	var forward := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	return right * raw.x + forward * -raw.y


## Where a ray meets a horizontal plane, or null if it is parallel or aimed away.
##
## A flat plane rather than a raycast against the terrain on purpose: with a
## raycast the cursor's world point jumps as it crosses a hill, and the actor
## snaps to face a hillside instead of the cursor. This is also cheaper, needs
## no physics query, and cannot miss.
static func ground_intersection(
	ray_origin: Vector3, ray_direction: Vector3, plane_height: float
) -> Variant:
	return Plane(Vector3.UP, plane_height).intersects_ray(ray_origin, ray_direction)
