class_name InputState
extends RefCounted
## One tick of intent, independent of where it came from.
##
## Deliberately plain data. A human at a keyboard, an enemy's AI, a replay, and
## eventually a packet from a client all produce one of these, and movement
## cannot tell the difference.

## Desired movement on the ground plane, as (x, z). Already rotated into world
## space, so a server never needs to know about the client's camera. Length is
## at most 1.
var move: Vector2 = Vector2.ZERO

var sprint: bool = false

## Whether the jump key is *held*, not whether it was just pressed.
##
## A state like [member sprint], not an event: the rising edge is spotted by
## whoever acts on it. That keeps this object a description of what the player
## is doing rather than a list of things that happened, which is what lets it be
## read twice, recorded, or eventually arrive from a network peer.
var jump: bool = false

## Point on the ground the actor wants to face.
var aim_point: Vector3 = Vector3.ZERO

## False when aim could not be resolved -- no camera, or the cursor pointing at
## the sky. Consumers must check this before turning toward [member aim_point].
var has_aim: bool = false


func is_moving() -> bool:
	return not move.is_zero_approx()


## Movement as a 3D direction on the ground plane.
func move_3d() -> Vector3:
	return Vector3(move.x, 0.0, move.y)


## An independent copy. Sources are free to reuse their state object between
## ticks, so anything that stores intent must copy it first.
func copy() -> InputState:
	var other := InputState.new()
	other.move = move
	other.sprint = sprint
	other.jump = jump
	other.aim_point = aim_point
	other.has_aim = has_aim
	return other


func clear() -> void:
	move = Vector2.ZERO
	sprint = false
	jump = false
	aim_point = Vector3.ZERO
	has_aim = false


func _to_string() -> String:
	return "<InputState move=%v sprint=%s jump=%s aim=%s>" % [
		move, sprint, jump, aim_point if has_aim else "none"
	]
