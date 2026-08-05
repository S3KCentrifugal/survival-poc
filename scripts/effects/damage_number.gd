class_name DamageNumber
extends Node3D
## A number that drifts up off whatever was just hit, then fades.
##
## Spawned into the world rather than onto the victim, for the same reason the
## explosion is: a number parented to something that is about to be freed dies
## with it, and the last hit -- the one that killed -- is exactly the one you
## most want to read.

@export var label: Label3D

## How long it lives, in seconds.
@export_range(0.1, 5.0, 0.05) var lifetime: float = 0.9

## How far it drifts upward over that life, in metres.
@export_range(0.0, 5.0, 0.1) var rise: float = 0.9

## Sideways scatter, so two hits in the same place do not print on top of each
## other and read as one.
@export_range(0.0, 2.0, 0.05) var scatter: float = 0.35

@export var normal_colour: Color = Color(1.0, 0.92, 0.6)

## Used when the hit was the one that finished them off.
@export var killing_colour: Color = Color(1.0, 0.45, 0.3)

var _age: float = 0.0
var _origin: Vector3
var _drift: Vector3 = Vector3.ZERO


func _ready() -> void:
	_origin = global_position


func _process(delta: float) -> void:
	_age += delta
	var through := clampf(_age / lifetime, 0.0, 1.0)

	global_position = _origin + Vector3.UP * rise * through + _drift * through
	if label != null:
		# Fades late rather than evenly: a number that starts disappearing
		# immediately is one you have to be already looking at.
		label.modulate.a = 1.0 - clampf((through - 0.55) / 0.45, 0.0, 1.0)

	if through >= 1.0:
		queue_free()


## Sets what it says and how it looks.
func show_damage(amount: float, killing: bool = false) -> void:
	if label == null:
		return
	label.text = str(roundi(amount))
	label.modulate = killing_colour if killing else normal_colour
	if killing:
		label.font_size = int(label.font_size * 1.4)


## Puts one in the world at [param where].
##
## [param spread] is a fixed sideways nudge -- passed in rather than rolled here
## so a test gets the same number twice.
static func pop(
	scene: PackedScene, parent: Node, where: Vector3, amount: float, killing: bool = false
) -> DamageNumber:
	if scene == null or parent == null or not parent.is_inside_tree():
		return null
	var number: DamageNumber = scene.instantiate()
	parent.add_child(number)
	number.global_position = where
	number._origin = where
	number._drift = Vector3(
		randf_range(-number.scatter, number.scatter),
		0.0,
		randf_range(-number.scatter, number.scatter)
	)
	number.show_damage(amount, killing)
	return number
