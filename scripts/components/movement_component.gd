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

## Emitted the moment the actor leaves the ground under its own power, for a
## sound or a puff of dust later. Not emitted for walking off a ledge.
signal jumped

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

## Whether jump was held on the previous tick, so a held key is not a jump on
## every frame. Releasing is what arms the next one.
var _jump_held: bool = false


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

	# After the velocity is solved, so gravity does not immediately undo the
	# launch, and before move_and_slide, so the actor leaves this same tick.
	var launching := consume_jump(state)
	if launching:
		body.velocity.y = MovementSolver.jump_velocity(config.jump_height, config.gravity)

	body.move_and_slide()
	apply_facing(state, delta)
	moved.emit(body.velocity)
	if launching:
		jumped.emit()


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


## Whether this tick launches a jump, and remembers the key for the next one.
##
## The rising edge is spotted here rather than in the input source, because
## "the key went down" is an event and [InputState] describes what is *held*.
## Holding the key therefore jumps once: you have to let go to jump again, which
## is what stops a held spacebar becoming a hover.
func consume_jump(state: InputState) -> bool:
	var pressed := state.jump and not _jump_held
	_jump_held = state.jump
	if not pressed or body == null:
		return false
	# Feet on the ground only. Air control and double jumps are decisions this
	# game has not made yet, and defaulting to "yes" would make them for it.
	return body.is_on_floor()


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
## Which candidate wins is [member MovementConfig.facing_mode], because it is a
## design decision rather than a detail. Standing still with nothing to face
## keeps the current heading rather than snapping to a default.
func facing_target(state: InputState) -> Variant:
	if config.facing_mode == MovementConfig.FacingMode.CURSOR:
		var aim: Variant = aim_yaw(state)
		if aim != null:
			return aim
	if state.is_moving():
		return MovementSolver.yaw_towards(state.move)
	return null


## Yaw toward what the actor is aiming at, or null if there is nothing usable.
##
## The cursor passes over the character constantly, and the direction to it is
## zero-length there -- which would otherwise produce a garbage yaw and a
## character that spins on the spot every time the mouse crosses it.
func aim_yaw(state: InputState) -> Variant:
	if not state.has_aim:
		return null
	var to_aim := MovementSolver.ground_direction(body.global_position, state.aim_point)
	if to_aim.is_zero_approx():
		return null
	return MovementSolver.yaw_towards(to_aim)
