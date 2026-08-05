class_name Explosion
extends Node3D
## A burst of sparks that cleans up after itself.
##
## Spawned by whatever caused it, then forgotten. It must never be a child of
## the thing that died: freeing the corpse would take the explosion with it, and
## the effect would last exactly zero frames.

## Extra seconds to linger after the particles stop, so the last of them fade
## rather than vanishing mid-air.
@export_range(0.0, 10.0, 0.1) var linger: float = 0.6

@export var particles: GPUParticles3D
@export var flash: OmniLight3D

## How quickly the light flash fades, in energy per second.
@export_range(0.1, 100.0, 0.1) var flash_fade: float = 14.0

var _life: float = 0.0


func _ready() -> void:
	if particles != null:
		particles.emitting = true
		_life = particles.lifetime + linger
	else:
		_life = linger


func _process(delta: float) -> void:
	if flash != null and flash.light_energy > 0.0:
		flash.light_energy = maxf(flash.light_energy - flash_fade * delta, 0.0)

	_life -= delta
	if _life <= 0.0:
		queue_free()


## Puts one at [param where] under [param parent].
##
## A static helper because every caller does the same three things and the
## middle one -- parenting it to the world rather than to the corpse -- is the
## one that is easy to get wrong.
static func burst(scene: PackedScene, parent: Node, where: Vector3) -> Explosion:
	if scene == null or parent == null or not parent.is_inside_tree():
		return null
	var effect: Explosion = scene.instantiate()
	parent.add_child(effect)
	effect.global_position = where
	return effect
