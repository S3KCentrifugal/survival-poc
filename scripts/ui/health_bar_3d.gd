class_name HealthBar3D
extends Node3D
## A health bar floating above an actor's head.
##
## Shown when the actor is hurt and hidden again once it has been quiet for a
## while. Always-on bars over everyone turn a landscape into a spreadsheet; a
## bar that appears when you hit something answers the only question you were
## asking, which is whether that one is nearly done.
##
## Built from two billboarded quads rather than a viewport with a real
## [ProgressBar] in it: a SubViewport per actor is a render target per actor,
## and this needs to work when six of them are on screen.

@export var health: HealthComponent

## Scaled along x to show the fraction. Its own origin is the bar's left edge,
## so it shrinks toward the left rather than from the middle.
@export var fill_pivot: Node3D

@export var fill: MeshInstance3D
@export var background: MeshInstance3D

## Seconds of quiet before it hides again. Zero keeps it up forever.
@export_range(0.0, 30.0, 0.5) var hide_after: float = 4.0

## Hidden until something happens, unless the actor is already hurt.
@export var start_hidden: bool = true

@export var healthy_colour: Color = Color(0.35, 0.75, 0.3)
@export var hurt_colour: Color = Color(0.85, 0.25, 0.2)

## Below this fraction the bar turns urgent, matching the player's HUD.
@export_range(0.0, 1.0, 0.05) var low_fraction: float = 0.3

var _idle: Cooldown


func _ready() -> void:
	_idle = Cooldown.new(hide_after)
	if health != null:
		health.changed.connect(_on_changed)
		health.died.connect(_on_died)
	refresh()
	if start_hidden and health != null and health.fraction() >= 1.0:
		visible = false


func _process(delta: float) -> void:
	if hide_after <= 0.0 or _idle.is_ready():
		return
	_idle.advance(delta)
	if _idle.is_ready():
		visible = false


## Redraws from the health component.
func refresh() -> void:
	if health == null:
		return
	set_fraction(health.fraction())


## Shows [param value], 0 to 1.
func set_fraction(value: float) -> void:
	var safe := 0.0 if is_nan(value) else clampf(value, 0.0, 1.0)
	if fill_pivot != null:
		# Never exactly zero: a scale of 0 collapses the basis, and Godot warns
		# about a non-invertible transform every frame it is on screen.
		fill_pivot.scale.x = maxf(safe, 0.0001)
	if fill != null:
		_tint(fill, hurt_colour if safe <= low_fraction else healthy_colour)


func fraction() -> float:
	return 0.0 if fill_pivot == null else fill_pivot.scale.x


## Brings it up and restarts the quiet timer.
func show_now() -> void:
	visible = true
	if hide_after > 0.0:
		_idle.duration = hide_after
		_idle.clear()
		_idle.use()


func _on_changed(_current: float, _maximum: float) -> void:
	refresh()
	show_now()


func _on_died() -> void:
	set_fraction(0.0)
	visible = false


func _tint(mesh: MeshInstance3D, colour: Color) -> void:
	var material := mesh.material_override as StandardMaterial3D
	if material == null:
		return
	if material.albedo_color != colour:
		# Duplicated once, then reused: sharing the material would recolour
		# every bar in the world at the same time.
		var own := material.duplicate() as StandardMaterial3D
		own.albedo_color = colour
		mesh.material_override = own
