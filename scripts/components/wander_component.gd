class_name WanderComponent
extends Node
## Drives an actor's [MovementComponent] from a [Wander].
##
## This is what the input abstraction was for. The wanderer runs the *player's*
## movement code -- same acceleration, same turning, same collision -- and
## movement cannot tell that the intent came from a state machine rather than
## from a keyboard.
##
## The [Wander] is ticked here, and [method InputSource.poll] only reports what
## the last tick decided. Polling must not advance anything: post 016 learned
## that the hard way, and two components sharing one source would otherwise run
## the wanderer's clock twice.

@export var config: WanderConfig

## The body whose position decides whether it has arrived. Assign in the scene.
@export var body: CharacterBody3D

## Told what to do. Assign in the scene; without it this decides in private.
@export var movement: MovementComponent

## Stops the actor while it reels from a hit, and for good once it is dead.
## Optional -- without one it wanders through anything that happens to it.
@export var hurt: HurtReaction

## Different per actor, or every wanderer in the world walks in step.
@export var seed_value: int = 0

var _wander: Wander
var _source: ScriptedInputSource


func _ready() -> void:
	if config == null:
		push_warning("WanderComponent has no config; falling back to defaults")
	if body == null:
		push_warning("WanderComponent has no body; it cannot tell when it arrives")
	_ensure_wander()
	if movement != null:
		movement.input_source = _source


func _physics_process(delta: float) -> void:
	step(delta)


## Advances one tick and writes the result into the input source.
##
## Public so tests can walk an actor around without the physics clock.
func step(delta: float) -> void:
	_ensure_wander()
	if body == null:
		return

	# Reeling from a hit, or dead. Either way it is not going anywhere, and the
	# wander clock keeps running so it does not resume mid-stride.
	if hurt != null and (hurt.is_reacting() or not hurt.is_alive()):
		_source.stop()
		return

	var here := Vector2(body.global_position.x, body.global_position.z)
	_source.move_towards_direction(_wander.tick(here, delta))


## The intent this component produces. Hand it to a [MovementComponent].
func input_source() -> InputSource:
	_ensure_wander()
	return _source


func wander() -> Wander:
	_ensure_wander()
	return _wander


## Where it is heading, for a test or a debug draw.
func destination() -> Vector2:
	return wander().destination()


func is_paused() -> bool:
	return wander().is_paused()


## Sets the point it strays from. Call before the first tick -- at spawn, from
## whoever placed it, since the actor knows where it is but not where it
## belongs.
func set_home(home: Vector2, actor_seed: int) -> void:
	seed_value = actor_seed
	if config == null:
		config = WanderConfig.new()
	_wander = Wander.new(config, home, actor_seed)
	_ensure_source()


func _ensure_wander() -> void:
	_ensure_source()
	if _wander != null:
		return
	if config == null:
		config = WanderConfig.new()
	var home := Vector2.ZERO
	if body != null:
		home = Vector2(body.global_position.x, body.global_position.z)
	_wander = Wander.new(config, home, seed_value)


func _ensure_source() -> void:
	if _source == null:
		_source = ScriptedInputSource.new()
