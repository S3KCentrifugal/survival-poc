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
const ACTION_JUMP: StringName = &"jump"
const ACTION_ATTACK: StringName = &"attack"
const ACTION_INTERACT: StringName = &"interact"
const ACTION_USE: StringName = &"use"

## Every action this source depends on, so a test can assert the InputMap
## actually defines them.
const REQUIRED_ACTIONS: Array[StringName] = [
	ACTION_MOVE_LEFT,
	ACTION_MOVE_RIGHT,
	ACTION_MOVE_FORWARD,
	ACTION_MOVE_BACK,
	ACTION_SPRINT,
	ACTION_JUMP,
	ACTION_ATTACK,
	ACTION_INTERACT,
	ACTION_USE,
]

## Used to turn screen input into world directions. Without one, movement falls
## back to world axes and aim cannot resolve.
var camera: Camera3D

## Height of the plane the cursor is projected onto. Set this to the actor's
## foot height so aim stays level with them.
var aim_plane_height: float = 0.0

## Whether the mouse turns the camera without a button held. Set from
## [member CameraConfig.mouse_look]; the source owns it because the mouse mode
## is part of how this device behaves, and this is the only file allowed to
## care about that.
var mouse_captured: bool = false

## Mouse movement and wheel notches since the last [method poll].
##
## Accumulated rather than sampled: motion arrives as events between frames, and
## reading "where is the mouse now" would drop everything but the last one.
var _look: Vector2 = Vector2.ZERO
var _zoom: float = 0.0

## Set when the cursor is captured, cleared when the attack button next comes
## up. The click that takes the cursor back after a menu or an alt-tab is aimed
## at the window, not at whatever is standing in front of you.
var _swallow_attack: bool = false


func _init(p_camera: Camera3D = null) -> void:
	camera = p_camera


func poll() -> InputState:
	var state := InputState.new()

	var raw := Input.get_vector(
		ACTION_MOVE_LEFT, ACTION_MOVE_RIGHT, ACTION_MOVE_FORWARD, ACTION_MOVE_BACK
	)
	state.move = to_world_direction(raw, camera_yaw())
	state.sprint = Input.is_action_pressed(ACTION_SPRINT)
	state.jump = Input.is_action_pressed(ACTION_JUMP)
	state.attack = _attack_intent()
	state.interact = Input.is_action_pressed(ACTION_INTERACT)
	state.use = Input.is_action_pressed(ACTION_USE)

	var aim: Variant = resolve_aim()
	if aim != null:
		state.aim_point = aim
		state.has_aim = true

	return state


## Whether the player is asking to swing, ignoring the click that recaptured
## the cursor.
func _attack_intent() -> bool:
	var pressed := Input.is_action_pressed(ACTION_ATTACK)
	if not pressed:
		_swallow_attack = false
	return pressed and not _swallow_attack


func consume_look() -> Vector2:
	var accumulated := _look
	_look = Vector2.ZERO
	return accumulated


func consume_zoom() -> float:
	var accumulated := _zoom
	_zoom = 0.0
	return accumulated


## Takes a raw event and remembers anything the camera will want.
##
## Called by whoever owns this source -- a [RefCounted] cannot receive input on
## its own. Everything device-shaped still happens in this file.
func handle_event(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		if mouse_captured or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_look += motion.relative
		return

	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		_zoom -= 1.0
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_zoom += 1.0


## Captures the cursor, or lets it go.
##
## Releasing has to be possible from outside -- a console you cannot click into
## and a window you cannot leave are the two ways mouse capture ruins an
## afternoon.
func capture_mouse(captured: bool) -> void:
	# Only on the way *in*. WorldRoot recaptures on every left click, so arming
	# the swallow on every call ate the punch that click was meant to throw --
	# which is to say, every punch.
	if captured and not mouse_captured:
		_swallow_attack = true
	mouse_captured = captured
	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	)


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
