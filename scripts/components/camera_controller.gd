class_name CameraController
extends Camera3D
## A fixed-angle camera that follows a target.
##
## Holds no framing maths of its own -- it asks [CameraFraming] where to be and
## goes there, smoothing the focus point so the view trails the target rather
## than snapping to it.
##
## The target is optional. With none set the camera frames [member
## fallback_focus], which is what keeps the world viewable before a player
## exists.

@export var config: CameraConfig

## Followed when set. Assign in the inspector, or call [method set_target] once
## the target is spawned.
@export var target_path: NodePath

## Framed when there is no target.
@export var fallback_focus: Vector3 = Vector3.ZERO

var _target: Node3D
var _focus: Vector3
var _focus_valid: bool = false


func _ready() -> void:
	if config == null:
		push_warning("CameraController has no config; falling back to defaults")
		config = CameraConfig.new()

	apply_projection()
	if not target_path.is_empty():
		set_target(get_node_or_null(target_path) as Node3D)
	snap_to_target()


func _process(delta: float) -> void:
	update_follow(delta)


## Follows [param node] from now on. Pass null to fall back to [member
## fallback_focus]. Does not snap -- the camera eases across.
func set_target(node: Node3D) -> void:
	_target = node


func target() -> Node3D:
	return _target


## Where the camera wants to be looking right now, ignoring smoothing.
func focus_goal() -> Vector3:
	if is_instance_valid(_target):
		return _target.global_position
	return fallback_focus


## Jumps straight to the target, skipping the ease. Use on spawn and on
## teleport, where easing across the world would look like a mistake.
func snap_to_target() -> void:
	_focus = focus_goal()
	_focus_valid = true
	_apply_transform()


## Advances the follow by [param delta].
##
## Public and driven by [method _process] so tests can step the camera
## deterministically instead of waiting on frames.
func update_follow(delta: float) -> void:
	if not _focus_valid:
		snap_to_target()
		return
	var weight := CameraFraming.smoothing_weight(config.follow_speed, delta)
	_focus = _focus.lerp(focus_goal(), weight)
	_apply_transform()


## Pushes projection settings from the config onto the camera.
func apply_projection() -> void:
	if config.orthographic:
		projection = PROJECTION_ORTHOGONAL
		size = config.orthographic_size
	else:
		projection = PROJECTION_PERSPECTIVE
		fov = config.fov


## The smoothed point currently framed.
func focus() -> Vector3:
	return _focus


func _apply_transform() -> void:
	global_transform = CameraFraming.transform_for(_focus, config)
