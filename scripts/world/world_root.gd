class_name WorldRoot
extends Node3D
## Wires the scene together.
##
## The composition root for a level. Components are forbidden from reaching
## around the scene to find each other, so something has to introduce them --
## and that something is whoever owns them, which is this.
##
## The player never looks for a camera and the camera never looks for a player;
## this hands each what it needs.

@export var terrain: Terrain
@export var player: CharacterBody3D
@export var player_movement: MovementComponent

## Shares the player's input source, so a click means the same thing to the
## swing as W does to the legs.
@export var player_attack: AttackComponent
@export var camera: CameraController

## Where the player starts, on the ground plane. Height comes from the terrain.
@export var spawn_point: Vector2 = Vector2.ZERO

## The human's input, built here and shared by movement and the camera.
var _player_input: PlayerInputSource


func _ready() -> void:
	_place_player()
	_wire_input()
	_wire_camera()


## Mouse events reach the input source through here.
##
## A [RefCounted] cannot receive input on its own, and the rule that only
## [PlayerInputSource] may read a device is worth more than the convenience of
## letting the camera listen for itself -- so the composition root forwards, and
## the source still owns every decision about what an event means.
func _unhandled_input(event: InputEvent) -> void:
	if _player_input == null:
		return
	_player_input.handle_event(event)

	# Clicking takes the cursor back. Escape used to release it; the pause menu
	# owns that key now and releases the cursor as part of opening, which is the
	# same gesture doing one thing instead of two.
	if get_tree().paused:
		return
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		set_mouse_captured(true)


## Captures or releases the cursor, if the camera is configured to want it.
##
## Public because the dev console has to be able to release it: a console you
## cannot click into is not much of a console.
func set_mouse_captured(captured: bool) -> void:
	if _player_input == null:
		return
	if camera != null and camera.config != null:
		if camera.config.mouse_look != CameraConfig.MouseLook.CAPTURED:
			return
	_player_input.capture_mouse(captured)


## Drops the player onto the terrain surface rather than guessing a height or
## letting them fall from the sky on every load.
func _place_player() -> void:
	if player == null:
		return
	var position := Vector3(spawn_point.x, 0.0, spawn_point.y)
	if terrain != null:
		position.y = terrain.height_at_world(position)
	player.global_position = position


## Builds the human's input and hands it to everything that reads intent.
##
## One source, shared: movement asks it what is being held, the camera drains
## the mouse deltas out of it. Two sources would mean two sets of key state
## disagreeing about whether W is down.
func _wire_input() -> void:
	_player_input = PlayerInputSource.new(camera)
	# Aim on the plane the player stands on, so the cursor and the character
	# agree about where the ground is.
	_player_input.aim_plane_height = player.global_position.y if player != null else 0.0
	if player_movement != null:
		player_movement.input_source = _player_input
	if player_attack != null:
		player_attack.input_source = _player_input


func _wire_camera() -> void:
	if camera == null:
		return
	camera.set_target(player)
	camera.input_source = _player_input
	# Snap rather than ease, or the view sweeps in from the world origin on
	# every load -- and swing round behind the player while we are at it.
	camera.snap_to_target()
	set_mouse_captured(true)
