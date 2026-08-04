class_name MovementComponent
extends Node
## Drives a [CharacterBody3D] from an [InputSource].
##
## Attach as a child of an actor and point [member body] at it. The body is an
## explicit reference rather than `get_parent()` so the component never assumes
## its position in a scene -- and so an enemy can hand it a different body.
##
## Holds no maths of its own; it asks [MovementSolver] and applies the answer.

signal moved(velocity: Vector3)

## The body this component walks. Assign in the scene.
@export var body: CharacterBody3D

@export var config: MovementConfig

## What sprinting spends. Optional -- an actor with no stamina component
## sprints for as long as it likes, which is what a deer should do.
@export var stamina: StaminaComponent

## Where intent comes from. Assign a [PlayerInputSource] for a human or a
## [ScriptedInputSource] for anything else. Nothing moves until this is set.
var input_source: InputSource

## Whether the last tick sprinted. Read by animation and the debug overlay;
## nothing here acts on it.
var _sprinting: bool = false


func _ready() -> void:
	if config == null:
		push_warning("MovementComponent has no config; falling back to defaults")
		config = MovementConfig.new()
	if body == null:
		push_warning("MovementComponent has no body; it will not move anything")


func _physics_process(delta: float) -> void:
	step(delta)


## Advances one physics step.
##
## Public so tests and tools can drive movement deterministically rather than
## waiting on the physics clock.
func step(delta: float) -> void:
	if body == null or input_source == null:
		return

	var state := input_source.poll()
	_sprinting = consume_sprint(state)
	body.velocity = solve_velocity(state, delta, _sprinting)
	body.move_and_slide()
	apply_facing(state, delta)
	moved.emit(body.velocity)


## Whether the actor sprinted on the last tick.
func is_sprinting() -> bool:
	return _sprinting


## Decides whether this tick sprints, and asks stamina to pay for it if so.
##
## Sprinting on the spot is not sprinting: without the movement check, holding
## the key while standing still drains the bar for nothing and the player
## arrives at the fight already tired.
##
## The request is a latch that [StaminaComponent] consumes on its own tick. In
## the player scene the stamina node sits after this one, so the cost lands the
## same frame; if it did not, it would land the next one, which nobody can see.
func consume_sprint(state: InputState) -> bool:
	if not state.sprint or not state.is_moving():
		return false
	if stamina == null:
		return true
	if not stamina.can_spend():
		return false
	stamina.request_drain()
	return true


## The velocity the actor should have after [param delta], given [param state].
##
## Separated from [method step] so it can be checked without a physics frame:
## [method CharacterBody3D.move_and_slide] needs the physics server, this does
## not.
func solve_velocity(state: InputState, delta: float, sprinting: bool = false) -> Vector3:
	var current := Vector2(body.velocity.x, body.velocity.z)
	var speed := MovementSolver.speed_for(config.walk_speed, config.sprint_multiplier, sprinting)
	var horizontal := MovementSolver.horizontal_velocity(
		current, state.move, speed, config.acceleration, config.deceleration, delta
	)
	var vertical := MovementSolver.apply_gravity(
		body.velocity.y, config.gravity, delta, body.is_on_floor()
	)
	return Vector3(horizontal.x, vertical, horizontal.y)


## Turns the body toward what it is aiming at, or toward where it is walking.
func apply_facing(state: InputState, delta: float) -> void:
	var target: Variant = facing_target(state)
	if target == null:
		return
	body.rotation.y = MovementSolver.turn_towards(
		body.rotation.y, target, config.turn_speed_radians() * delta
	)


## Yaw the actor wants to face, or null if it has no opinion.
##
## Aim wins over movement -- facing the cursor while strafing is the whole
## point of a top-down control scheme. Standing still with no aim keeps the
## current facing rather than snapping to a default.
func facing_target(state: InputState) -> Variant:
	if state.has_aim:
		var to_aim := MovementSolver.ground_direction(body.global_position, state.aim_point)
		if not to_aim.is_zero_approx():
			return MovementSolver.yaw_towards(to_aim)
	if state.is_moving():
		return MovementSolver.yaw_towards(state.move)
	return null
