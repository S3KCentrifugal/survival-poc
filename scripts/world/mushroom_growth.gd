class_name MushroomGrowth
extends Node3D
## Makes a mushroom grow out of the ground rather than appear.
##
## Scale only, and on the model rather than the pickup: a thing that pops into
## existence at full size reads as a spawner firing, and a thing that swells
## over a couple of seconds reads as something that was always going to be
## there. The difference is two seconds of lerp and it is most of what sells
## the word "grow".
##
## Collection does not wait for it. A half-grown mushroom is a real mushroom --
## making the player wait for an animation to finish is a rule nobody enjoys
## discovering.

## What is scaled. Defaults to the first child, which is the model.
@export var model: Node3D

## Seconds from sprout to full size.
@export_range(0.0, 30.0, 0.1) var grow_seconds: float = 2.5

## Size it starts at, as a fraction. Not zero: a mesh scaled to nothing has a
## degenerate basis, and Godot complains about it every frame.
@export_range(0.01, 1.0, 0.01) var start_scale: float = 0.08

var _age: float = 0.0
var _full: Vector3 = Vector3.ONE


func _ready() -> void:
	if model == null:
		model = get_child(0) as Node3D if get_child_count() > 0 else null
	if model == null:
		return
	_full = model.scale
	_apply()


func _process(delta: float) -> void:
	if model == null or _age >= grow_seconds:
		set_process(false)
		return
	_age += delta
	_apply()


## How grown it is, 0 to 1.
func maturity() -> float:
	if grow_seconds <= 0.0:
		return 1.0
	return clampf(_age / grow_seconds, 0.0, 1.0)


## Jumps to full size, for a test or a world that should start established
## rather than sprouting everything at once on the first frame.
func finish() -> void:
	_age = grow_seconds
	_apply()


func _apply() -> void:
	if model == null:
		return
	model.scale = _full * lerpf(start_scale, 1.0, maturity())
