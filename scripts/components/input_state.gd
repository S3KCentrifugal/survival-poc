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

## Whether the attack button is *held*. Like [member jump], a state rather than
## an event -- the rising edge belongs to whoever swings.
var attack: bool = false

## Whether the jump key is *held*, not whether it was just pressed.
##
## A state like [member sprint], not an event: the rising edge is spotted by
## whoever acts on it. That keeps this object a description of what the player
## is doing rather than a list of things that happened, which is what lets it be
## read twice, recorded, or eventually arrive from a network peer.
var jump: bool = false

## Whether the heavy attack button is *held*. Its own field rather than a
## modifier on [member attack], because they are two buttons and either can be
## held without the other.
var heavy_attack: bool = false

## Whether the interact key is *held*. A state like the rest; picking a
## mushroom up once per press is the collector's business, not this object's.
var interact: bool = false

## Whether the use key is *held*. Separate from [member interact] because they
## are separate verbs: interact takes a thing away, use operates a thing that
## stays where it is.
var use: bool = false

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
	other.attack = attack
	other.heavy_attack = heavy_attack
	other.interact = interact
	other.use = use
	other.aim_point = aim_point
	other.has_aim = has_aim
	return other


func clear() -> void:
	move = Vector2.ZERO
	sprint = false
	jump = false
	attack = false
	heavy_attack = false
	interact = false
	use = false
	aim_point = Vector3.ZERO
	has_aim = false


func _to_string() -> String:
	return "<InputState move=%v sprint=%s jump=%s aim=%s>" % [
		move, sprint, jump, aim_point if has_aim else "none"
	]
