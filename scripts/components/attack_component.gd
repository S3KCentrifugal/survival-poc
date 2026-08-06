class_name AttackComponent
extends Node
## Throws a punch when asked, and refuses to throw the next one too soon.
##
## **It hits nothing.** There is no hit detection, no damage and no target --
## that is combat, which the brief keeps out of this slice. This is the swing:
## an intent, a rate limit, and something for the animation to show. Whatever
## eventually deals damage will listen to [signal attacked] rather than
## replacing this.

## Emitted the moment a light punch is thrown. What a hitbox, a sound or a
## camera shake will hang off.
signal attacked

## Emitted the moment a heavy attack is thrown. A separate signal rather than a
## flag on [signal attacked], so nothing that already listens for a punch has to
## learn what a heavy is to keep working.
signal heavy_attacked

## Emitted when the cooldown expires and another punch is available.
signal ready_again

## Emitted once per body a swing lands on, before the damage is applied.
signal hit(target: Node3D, damage: float)

## Emitted when a blow takes something from alive to not.
##
## Here rather than on the victim, because the interesting question is *who*
## killed it -- and the attacker is the only one holding both ends of that.
signal killed(target: Node3D)

@export var config: AttackConfig

## Where the swing comes from and which way it points. Without one the punch is
## a gesture -- it still animates and still rate-limits, it just cannot connect.
@export var body: CharacterBody3D

## What a heavy attack spends. Optional -- without one it is free, which makes
## it strictly better than the light attack rather than a trade.
@export var stamina: StaminaComponent

## Where intent comes from. Shared with movement -- one source, so the key
## state cannot disagree with itself.
var input_source: InputSource

var _cooldown: Cooldown
var _heavy_cooldown: Cooldown

## Whether attack was held last tick. A held button is one punch, not one per
## frame; releasing is what arms the next.
var _held: bool = false
var _heavy_held: bool = false

## Which kind the swing currently showing is, so the animation knows which clip
## to play and the debug overlay knows what to say.
var _heavy_showing: bool = false


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
	_heavy_cooldown.advance(delta)
	if was_waiting and _cooldown.is_ready():
		ready_again.emit()

	if input_source == null:
		return
	var state := input_source.poll()

	# Heavy first. Holding both buttons should throw the one that costs
	# something, not the one that happens to be checked first.
	var heavy_wanted := state.heavy_attack
	var heavy_pressed := heavy_wanted and not _heavy_held
	_heavy_held = heavy_wanted
	if heavy_pressed:
		heavy_punch()
		return

	var wanted := state.attack
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
	# A light punch during a heavy's recovery would let you cancel the cost of
	# the heavy by throwing a jab, which is the standard way this gets broken.
	if not _heavy_cooldown.is_ready() or not _cooldown.use():
		return false
	_heavy_showing = false
	attacked.emit()
	# The swing is local -- you see your own punch immediately. Whether it *hit*
	# is the server's to say, and today this process is always the server. See
	# MULTIPLAYER.md: the client will eventually ask rather than decide.
	if not NetworkAuthority.may_simulate(self):
		return true
	_land(reachable_targets(), config.damage)
	return true


## Throws a heavy attack: slower, further, narrower, and much harder.
##
## Returns false when it is still on cooldown or there is not enough stamina to
## pay for it. Both are refusals rather than a weaker swing -- a heavy that
## quietly becomes a light one when you are tired is a heavy you cannot rely on.
func heavy_punch() -> bool:
	_ensure_cooldown()
	if not _heavy_cooldown.is_ready() or not _cooldown.is_ready():
		return false
	if not _can_pay_for_heavy():
		return false

	_heavy_cooldown.use()
	# The light cooldown is spent too, so a heavy is not immediately followed by
	# a free jab.
	_cooldown.use()
	_spend_heavy_stamina()
	_heavy_showing = true
	heavy_attacked.emit()

	if not NetworkAuthority.may_simulate(self):
		return true
	_land(heavy_targets(), config.heavy_damage)
	return true


## Everything a heavy attack would land on: further out and in a narrower arc.
func heavy_targets() -> Array[Node3D]:
	return _targets(config.heavy_reach, config.heavy_arc_radians())


## Whether a heavy attack could be thrown right now.
func can_heavy_attack() -> bool:
	_ensure_cooldown()
	return _heavy_cooldown.is_ready() and _cooldown.is_ready() and _can_pay_for_heavy()


## Whether the swing currently showing is a heavy one.
func is_heavy_attacking() -> bool:
	return _heavy_showing and is_attacking()


func _land(targets: Array[Node3D], damage: float) -> void:
	for target: Node3D in targets:
		hit.emit(target, damage)
		var health := MeleeSolver.health_of(target)
		if health == null:
			continue
		var was_alive := health.is_alive()
		health.take_damage(damage)
		# Asked either side of the blow rather than by listening to the victim:
		# the attacker is the only one who knows it was *their* blow.
		if was_alive and not health.is_alive():
			killed.emit(target)


func _can_pay_for_heavy() -> bool:
	if stamina == null or config.heavy_stamina_cost <= 0.0:
		return true
	return stamina.current() >= config.heavy_stamina_cost


func _spend_heavy_stamina() -> void:
	if stamina != null and config.heavy_stamina_cost > 0.0:
		stamina.spend(config.heavy_stamina_cost)


## Everything within reach and inside the arc, right now.
##
## A shape query rather than a list of every actor in the world: the physics
## server already knows what is near, and asking it scales with the crowd rather
## than with the map.
func reachable_targets() -> Array[Node3D]:
	return _targets(config.reach, config.arc_radians())


func _targets(reach: float, arc: float) -> Array[Node3D]:
	var found: Array[Node3D] = []
	if body == null or not body.is_inside_tree():
		return found

	var shape := SphereShape3D.new()
	shape.radius = reach

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
			body.global_position, forward, collider.global_position, reach, arc
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
	_heavy_cooldown = Cooldown.new(config.heavy_cooldown)
