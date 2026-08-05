class_name FollowComponent
extends Node
## Drives an actor to follow another one, going *round* things rather than into
## them.
##
## The route comes from a [NavigationAgent3D]; whether to be walking at all
## comes from [Follow]. Movement is the player's own [MovementComponent], which
## still cannot tell that the intent came from a path rather than a keyboard --
## the same claim feature 4 made and feature 20 first cashed in.
##
## Falls back to walking straight at the target when there is no navigation map
## to consult. A companion that refuses to move because a navmesh failed to bake
## is worse than one that occasionally walks into a wall.

@export var config: FollowConfig

## Who to follow.
@export var target: Node3D

## The body being steered. Assign in the scene.
@export var body: CharacterBody3D

## Told what to do.
@export var movement: MovementComponent

## Works out the route. Optional; without one this steers in a straight line.
@export var agent: NavigationAgent3D

## Stops while reeling from a hit, and for good once dead.
@export var hurt: HurtReaction

var _follow: Follow
var _source: ScriptedInputSource

## Counts down to the next path recalculation.
var _repath: Cooldown


func _ready() -> void:
	if config == null:
		push_warning("FollowComponent has no config; falling back to defaults")
	_ensure_ready()
	if movement != null:
		movement.input_source = _source


func _physics_process(delta: float) -> void:
	step(delta)


## Advances one tick and writes the result into the input source.
##
## Public so tests can walk an actor around without the physics clock.
func step(delta: float) -> void:
	_ensure_ready()
	if body == null or not is_instance_valid(target):
		_source.stop()
		return
	# Simulated by its owner only, like any other AI.
	if not NetworkAuthority.may_simulate(self):
		return

	if hurt != null and (hurt.is_reacting() or not hurt.is_alive()):
		_source.stop()
		_source.sprint(false)
		return

	var here := _ground(body.global_position)
	var there := _ground(target.global_position)
	var distance := here.distance_to(there)

	_follow.tick(distance, delta)
	if not _follow.is_moving():
		_source.stop()
		_source.sprint(false)
		return

	_repath.advance(delta)
	if _repath.is_ready():
		_aim_at(target.global_position)
		_repath.duration = config.repath_interval
		_repath.clear()
		_repath.use()

	_source.move_towards_direction(_direction_to(there))
	_source.sprint(_follow.should_sprint(distance))


## The intent this component produces.
func input_source() -> InputSource:
	_ensure_ready()
	return _source


func follow() -> Follow:
	_ensure_ready()
	return _follow


func is_following() -> bool:
	return follow().is_moving()


## How far away the thing being followed is, on the ground plane.
func distance_to_target() -> float:
	if body == null or not is_instance_valid(target):
		return 0.0
	return _ground(body.global_position).distance_to(_ground(target.global_position))


## Whether a route is actually being consulted, rather than a straight line.
##
## Worth being able to ask: "the companion walks into walls" and "the companion
## has no navmesh" look identical from the outside.
func is_pathfinding() -> bool:
	if agent == null or not agent.is_inside_tree():
		return false
	return agent.get_navigation_map().is_valid()


func _aim_at(destination: Vector3) -> void:
	if agent != null and agent.is_inside_tree():
		agent.target_position = destination


## Ground direction to walk this tick.
##
## The next corner of the path when there is one, the target itself when there
## is not.
func _direction_to(there: Vector2) -> Vector2:
	var here := _ground(body.global_position)
	if is_pathfinding() and not agent.is_navigation_finished():
		var corner := _ground(agent.get_next_path_position())
		if here.distance_to(corner) > 0.05:
			return (corner - here).normalized()
	if here.distance_to(there) <= 0.001:
		return Vector2.ZERO
	return (there - here).normalized()


static func _ground(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)


func _ensure_ready() -> void:
	if _source == null:
		_source = ScriptedInputSource.new()
	if config == null:
		config = FollowConfig.new()
	if _follow == null:
		_follow = Follow.new(config)
	if _repath == null:
		_repath = Cooldown.new(config.repath_interval)
