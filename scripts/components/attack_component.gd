class_name AttackComponent
extends Node
## Throws a punch when asked, and refuses to throw the next one too soon.
##
## **It hits nothing.** There is no hit detection, no damage and no target --
## that is combat, which the brief keeps out of this slice. This is the swing:
## an intent, a rate limit, and something for the animation to show. Whatever
## eventually deals damage will listen to [signal attacked] rather than
## replacing this.

## Emitted the moment a punch is thrown. What a hitbox, a sound or a camera
## shake will hang off.
signal attacked

## Emitted when the cooldown expires and another punch is available.
signal ready_again

## Emitted once per body a swing lands on, before the damage is applied.
signal hit(target: Node3D, damage: float)

@export var config: AttackConfig

## Where the swing comes from and which way it points. Without one the punch is
## a gesture -- it still animates and still rate-limits, it just cannot connect.
@export var body: CharacterBody3D

## Where intent comes from. Shared with movement -- one source, so the key
## state cannot disagree with itself.
var input_source: InputSource

var _cooldown: Cooldown

## Whether attack was held last tick. A held button is one punch, not one per
## frame; releasing is what arms the next.
var _held: bool = false


func _ready() -> void:
	if config == null:
		push_warning("AttackComponent has no config; falling back to defaults")
	_ensure_cooldown()


func _physics_process(delta: float) -> void:
	step(delta)


## Advances one tick: counts the cooldown down, then punches if asked and able.
##
## Public so tests can drive it without the physics clock.
func step(delta: float) -> void:
	_ensure_cooldown()
	var was_waiting := not _cooldown.is_ready()
	_cooldown.advance(delta)
	if was_waiting and _cooldown.is_ready():
		ready_again.emit()

	if input_source == null:
		return
	var wanted := input_source.poll().attack
	var pressed := wanted and not _held
	_held = wanted
	if pressed:
		punch()


## Throws a punch if the cooldown allows, and reports whether one was thrown.
##
## Public so a scripted actor -- or the dev console later -- can swing without
## pretending to press a button.
func punch() -> bool:
	_ensure_cooldown()
	if not _cooldown.use():
		return false
	attacked.emit()
	for target: Node3D in reachable_targets():
		hit.emit(target, config.damage)
		var health := MeleeSolver.health_of(target)
		if health != null:
			health.take_damage(config.damage)
	return true


## Everything within reach and inside the arc, right now.
##
## A shape query rather than a list of every actor in the world: the physics
## server already knows what is near, and asking it scales with the crowd rather
## than with the map.
func reachable_targets() -> Array[Node3D]:
	var found: Array[Node3D] = []
	if body == null or not body.is_inside_tree():
		return found

	var shape := SphereShape3D.new()
	shape.radius = config.reach

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, body.global_position + Vector3.UP)
	query.collision_mask = config.hit_mask
	query.exclude = [body.get_rid()]

	var forward := -body.global_transform.basis.z
	for contact: Dictionary in body.get_world_3d().direct_space_state.intersect_shape(
		query, config.max_targets
	):
		var collider := contact.get("collider") as Node3D
		if collider == null or found.has(collider):
			continue
		if MeleeSolver.can_reach(
			body.global_position,
			forward,
			collider.global_position,
			config.reach,
			config.arc_radians()
		):
			found.append(collider)
	return found


## Whether a punch is currently being thrown.
##
## Reads off the cooldown rather than a second timer, which is what keeps the
## visible swing and the rate limit from ever disagreeing.
func is_attacking() -> bool:
	_ensure_cooldown()
	return not _cooldown.is_ready()


func can_attack() -> bool:
	_ensure_cooldown()
	return _cooldown.is_ready()


## How far through the current swing, 1 at the moment of the punch down to 0.
func progress() -> float:
	_ensure_cooldown()
	return _cooldown.fraction()


func _ensure_cooldown() -> void:
	if _cooldown != null:
		return
	if config == null:
		config = AttackConfig.new()
	_cooldown = Cooldown.new(config.cooldown)
