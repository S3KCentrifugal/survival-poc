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
@export var camera: CameraController

## Where the player starts, on the ground plane. Height comes from the terrain.
@export var spawn_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	_place_player()
	_wire_input()
	_wire_camera()


## Drops the player onto the terrain surface rather than guessing a height or
## letting them fall from the sky on every load.
func _place_player() -> void:
	if player == null:
		return
	var position := Vector3(spawn_point.x, 0.0, spawn_point.y)
	if terrain != null:
		position.y = terrain.height_at_world(position)
	player.global_position = position


func _wire_input() -> void:
	if player_movement == null:
		return
	var source := PlayerInputSource.new(camera)
	# Aim on the plane the player stands on, so the cursor and the character
	# agree about where the ground is.
	source.aim_plane_height = player.global_position.y if player != null else 0.0
	player_movement.input_source = source


func _wire_camera() -> void:
	if camera == null:
		return
	camera.set_target(player)
	# Snap rather than ease, or the view sweeps in from the world origin on
	# every load.
	camera.snap_to_target()
