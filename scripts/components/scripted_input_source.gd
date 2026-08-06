class_name ScriptedInputSource
extends InputSource
## Intent set directly in code rather than read from a device.
##
## This is what makes the abstraction worth having: an enemy walks by having
## its AI write to one of these, and a movement test drives a character with no
## keyboard and no frames. The same movement code runs in both cases.

var state: InputState = InputState.new()


func poll() -> InputState:
	return state


## Walks in a world-space ground direction. Normalised, so callers can pass an
## unnormalised vector toward a destination.
func move_towards_direction(direction: Vector2) -> void:
	state.move = direction.normalized() if not direction.is_zero_approx() else Vector2.ZERO


## Walks from [param from] toward [param to] on the ground plane.
func move_between(from: Vector3, to: Vector3) -> void:
	move_towards_direction(Vector2(to.x - from.x, to.z - from.z))


func stop() -> void:
	state.move = Vector2.ZERO


func sprint(enabled: bool) -> void:
	state.sprint = enabled


## Holds or releases jump. Held, not tapped -- releasing is what arms the next
## jump, exactly as it is for a human.
func jump(held: bool) -> void:
	state.jump = held


## Holds or releases the attack button.
func attack(held: bool) -> void:
	state.attack = held


## Holds or releases the heavy attack button.
func heavy_attack(held: bool) -> void:
	state.heavy_attack = held


## Holds or releases the interact key.
func interact(held: bool) -> void:
	state.interact = held


## Holds or releases the use key.
func use(held: bool) -> void:
	state.use = held


## Queues a mouse movement in pixels for the camera to consume.
var pending_look: Vector2 = Vector2.ZERO

## Queues wheel notches for the camera to consume. Positive pulls it out.
var pending_zoom: float = 0.0


func look(movement: Vector2) -> void:
	pending_look += movement


func zoom(notches: float) -> void:
	pending_zoom += notches


## Drained like the real thing, so a test cannot accidentally turn the camera
## every frame from one scripted flick.
func consume_look() -> Vector2:
	var queued := pending_look
	pending_look = Vector2.ZERO
	return queued


func consume_zoom() -> float:
	var queued := pending_zoom
	pending_zoom = 0.0
	return queued


func aim_at(point: Vector3) -> void:
	state.aim_point = point
	state.has_aim = true


func clear_aim() -> void:
	state.has_aim = false
