class_name MeleeSolver
extends RefCounted
## Whether a swing reaches something.
##
## Pure geometry over plain vectors, so "does a punch land on someone stood just
## behind your shoulder" is an assertion rather than a thing you discover by
## flailing at a character and watching.

## Slack on the arc comparison, in radians. See [method can_reach].
const ANGLE_TOLERANCE: float = 0.0001


## Whether [param target] is within [param reach] and inside the swing's arc.
##
## Measured on the ground plane. A melee swing that misses because the target is
## standing slightly downhill is worse than one that is generous about height.
static func can_reach(
	from: Vector3, forward: Vector3, target: Vector3, reach: float, arc: float
) -> bool:
	if reach <= 0.0:
		return false

	var to_target := Vector2(target.x - from.x, target.z - from.z)
	if to_target.length() > reach:
		return false
	# Standing inside someone has no direction to test, and is certainly a hit.
	if to_target.is_zero_approx():
		return true

	var facing := Vector2(forward.x, forward.z)
	if facing.is_zero_approx():
		return true
	# The tolerance is not decoration. Vector2 holds 32-bit floats, so angle_to
	# on an exact half-turn returns 3.14159274, which is *larger* than
	# double-precision pi -- and a 360-degree arc then fails to reach the thing
	# standing directly behind you. Six thousandths of a degree of slack.
	return absf(facing.angle_to(to_target)) <= arc * 0.5 + ANGLE_TOLERANCE


## The health of whatever was hit, or null if it has none.
##
## Searched by type rather than by node name: a hard-coded "Health" would work
## until the first actor that names it something else, and would fail silently
## when it did.
static func health_of(node: Node) -> HealthComponent:
	if node == null:
		return null
	var own := node as HealthComponent
	if own != null:
		return own
	for child: Node in node.get_children():
		var found := child as HealthComponent
		if found != null:
			return found
	return null
