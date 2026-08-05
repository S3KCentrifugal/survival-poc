class_name AnimationComponent
extends Node
## Runs an actor's [AnimationStateMachine] and plays the result.
##
## Reads motion from an explicit body reference rather than looking around for
## one, and drives an [AnimationPlayer] only if it is given one. The player
## character is a capsule today, so the state machine runs with nothing attached
## to it -- which is the point: the rig can arrive later without this changing.

## Emitted on a transition, never on a repeat. Values are
## [enum AnimationStateMachine.State].
signal state_changed(state: int)

## The body whose motion decides the state. Assign in the scene.
@export var body: CharacterBody3D

## Where sprinting is read from. Optional -- without it an actor walks and runs
## purely on speed, which is all a rigless placeholder needs.
@export var movement: MovementComponent

## The rig to drive. Optional, and absent until there is a character model.
@export var animation_player: AnimationPlayer

@export var config: AnimationConfig

var _machine: AnimationStateMachine


func _ready() -> void:
	if config == null:
		push_warning("AnimationComponent has no config; falling back to defaults")
	if body == null:
		push_warning("AnimationComponent has no body; it will never leave idle")
	_ensure_machine()
	_play(state())


func _physics_process(_delta: float) -> void:
	step()


## Recomputes the state from the body's current motion.
##
## Public so tests and tools can drive it a tick at a time rather than waiting
## on the physics clock.
func step() -> void:
	_ensure_machine()
	if body == null:
		return

	var previous := _machine.state()
	var next := _machine.update(ground_speed(), is_sprinting(), on_floor(), vertical_speed())
	if next == previous:
		return

	_play(next)
	state_changed.emit(next)


## Horizontal speed of the body. Vertical motion is excluded on purpose -- an
## actor falling straight down is not walking.
func ground_speed() -> float:
	return 0.0 if body == null else Vector2(body.velocity.x, body.velocity.z).length()


## Vertical speed of the body, positive upwards. Separates a jump from a fall.
func vertical_speed() -> float:
	return 0.0 if body == null else body.velocity.y


## Whether the body is standing on something.
##
## A method rather than an inline call so a test can substitute it: a body that
## has never been through [method CharacterBody3D.move_and_slide] reports
## airborne, which would pin every test to the falling state.
func on_floor() -> bool:
	return body != null and body.is_on_floor()


func state() -> AnimationStateMachine.State:
	_ensure_machine()
	return _machine.state()


## The current state as a word, for the debug overlay.
func state_name() -> StringName:
	return AnimationStateMachine.state_name(state())


func is_sprinting() -> bool:
	return movement != null and movement.is_sprinting()


## Starts the clip for [param state_value], if there is a rig and it has one.
##
## A missing clip is not an error worth stopping for: a placeholder rig that
## only has an idle should still idle rather than spam the log every transition.
func _play(state_value: AnimationStateMachine.State) -> void:
	if animation_player == null:
		return
	var clip := _machine.animation_for(state_value)
	if not animation_player.has_animation(clip):
		return
	animation_player.play(clip, config.transition_time)


func _ensure_machine() -> void:
	if _machine != null:
		return
	if config == null:
		config = AnimationConfig.new()
	_machine = AnimationStateMachine.new(config)
