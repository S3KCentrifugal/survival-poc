class_name CameraController
extends Camera3D
## A third-person camera that orbits a target.
##
## Sits behind and above whatever it follows, turns with the mouse, and zooms on
## the wheel. Holds no maths of its own: [CameraOrbit] owns where it is pointing
## from and [CameraFraming] turns that into a transform.
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

## Where look and zoom come from. Nothing turns the camera until this is set,
## which is deliberate: a cutscene camera has no business reading a mouse.
var input_source: InputSource

var _orbit: CameraOrbit
var _target: Node3D
var _focus: Vector3
var _focus_valid: bool = false


func _ready() -> void:
	if config == null:
		push_warning("CameraController has no config; falling back to defaults")
		config = CameraConfig.new()

	_orbit = CameraOrbit.new(config)
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


## Where the camera is pointing from.
func orbit() -> CameraOrbit:
	_ensure_orbit()
	return _orbit


## Where the camera wants to be looking right now, ignoring smoothing.
func focus_goal() -> Vector3:
	if is_instance_valid(_target):
		return _target.global_position
	return fallback_focus


## Jumps straight to the target, skipping the ease, and swings round to its
## back. Use on spawn and on teleport, where easing across the world would look
## like a mistake and facing the character head-on would look like a bug.
func snap_to_target() -> void:
	_ensure_orbit()
	_focus = focus_goal()
	_focus_valid = true
	if is_instance_valid(_target):
		_orbit.place_behind(_target.global_rotation.y)
	_orbit.settle()
	_apply_transform()


## Advances the follow by [param delta].
##
## Public and driven by [method _process] so tests can step the camera
## deterministically instead of waiting on frames.
func update_follow(delta: float) -> void:
	_ensure_orbit()
	if not _focus_valid:
		snap_to_target()
		return

	if input_source != null:
		_orbit.look(input_source.consume_look())
		var notches := input_source.consume_zoom()
		if not is_zero_approx(notches):
			_orbit.zoom(notches)
	_orbit.advance(delta)

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


## How far the camera actually sits from its aim point, after anything solid in
## the way has pushed it in.
##
## The player starts inside a building. A camera five metres behind them is five
## metres inside a wall, so without this the third-person view spends its first
## minute rendering the inside of the brickwork.
func clear_distance(from: Vector3, wanted: float) -> float:
	if not config.avoid_obstructions or wanted <= 0.0:
		return wanted
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	if space == null:
		return wanted

	var direction := CameraFraming.offset_from_focus(
		_orbit.yaw, _orbit.pitch, 1.0
	).normalized()
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * wanted)
	query.collision_mask = config.obstruction_mask
	# The player is a body too, and a camera that stops at their own back is a
	# camera pinned to their shoulder blades.
	if is_instance_valid(_target):
		query.exclude = [_target.get_rid()] if _target is CollisionObject3D else []

	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return wanted
	var hit_distance: float = from.distance_to(hit["position"])
	return CameraFraming.unobstructed_distance(wanted, hit_distance, config.obstruction_margin)


func _ensure_orbit() -> void:
	if _orbit == null:
		if config == null:
			config = CameraConfig.new()
		_orbit = CameraOrbit.new(config)


func _apply_transform() -> void:
	var aim := CameraFraming.aim_point(_focus, config.focus_height)
	var distance := clear_distance(aim, _orbit.distance)
	global_transform = CameraFraming.transform_for(
		_focus, config.focus_height, _orbit.yaw, _orbit.pitch, distance
	)
