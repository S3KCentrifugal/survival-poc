class_name Wander
extends RefCounted
## Deciding where to amble to next, and when to give up on getting there.
##
## Pure state and plain numbers -- no nodes, no physics, no navigation. It is
## handed a position and a delta, and answers with a direction. That is the same
## shape of answer a human's keyboard produces, which is what lets it drive the
## player's movement code without either side knowing.
##
## Seeded on purpose: an actor that wanders differently every run cannot be
## tested, and two actors sharing the global generator wander in step.

enum State { PAUSED, WALKING }

var _config: WanderConfig
var _rng: RandomNumberGenerator

## The point it strays from and returns near. Set once, at spawn.
var _home: Vector2

var _destination: Vector2
var _state: State = State.PAUSED

## Seconds left of the current pause, or spent on the current walk.
var _timer: float = 0.0


func _init(config: WanderConfig, home: Vector2, seed_value: int = 0) -> void:
	_config = config
	_home = home
	_destination = home
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_begin_pause()


## One tick. Returns the ground direction to walk, or zero to stand still.
##
## [param position] is where the actor actually is, which is the only way this
## can tell the difference between arriving and being stuck.
func tick(position: Vector2, delta: float) -> Vector2:
	_timer += delta if _state == State.WALKING else -delta

	if _state == State.PAUSED:
		if _timer <= 0.0:
			_begin_walk()
		return Vector2.ZERO

	var to_target := _destination - position
	if to_target.length() <= _config.arrival_distance:
		_begin_pause()
		return Vector2.ZERO

	# Wedged against a wall, or aiming at a spot inside a building. Stop trying
	# rather than leaning on it for the rest of the session.
	if _timer >= _config.give_up_seconds:
		_begin_pause()
		return Vector2.ZERO

	return to_target.normalized()


func state() -> State:
	return _state


func is_paused() -> bool:
	return _state == State.PAUSED


func destination() -> Vector2:
	return _destination


func home() -> Vector2:
	return _home


## Seconds spent walking toward the current destination, or left of the pause.
func timer() -> float:
	return absf(_timer)


func _begin_pause() -> void:
	_state = State.PAUSED
	var limits := _config.pause_range()
	_timer = _rng.randf_range(limits.x, limits.y)


## Picks somewhere inside the home radius.
##
## The radius is square-rooted so points spread evenly over the circle. Without
## it they bunch toward the middle, and a group of wanderers reads as a huddle
## rather than a scattering.
func _begin_walk() -> void:
	_state = State.WALKING
	_timer = 0.0
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _config.radius * sqrt(_rng.randf())
	_destination = _home + Vector2(cos(angle), sin(angle)) * distance
