class_name Proximity
extends RefCounted
## Finds the nearest thing in reach.
##
## Extracted when the workbench needed exactly what [PickupCollector] already
## did. Two near-identical proximity searches is how a codebase ends up with
## one of them quietly using a different reach.
##
## Duck-typed on purpose: anything with `world_position()` and `is_available()`
## can be found, whether it is a pickup, a bench, or a door later. That is
## composition doing what it is for -- there is no base class and there does not
## need to be one.

## The closest available candidate within [param reach] of [param from], or
## null.
##
## Static and taking its candidates as an argument, so choosing between two
## things is a test with three positions in it: no scene, no physics frame, no
## collision layers to get wrong.
static func nearest(from: Vector3, candidates: Array, reach: float) -> Node:
	var best: Node = null
	# Squared throughout: the comparison is the same and there is no square root
	# per candidate per frame.
	var best_distance := reach * reach
	for candidate: Variant in candidates:
		var node := candidate as Node
		if node == null or not _is_available(node):
			continue
		var distance := from.distance_squared_to(node.call(&"world_position"))
		if distance <= best_distance:
			best_distance = distance
			best = node
	return best


static func _is_available(node: Node) -> bool:
	if not node.has_method(&"world_position") or not node.has_method(&"is_available"):
		return false
	return node.call(&"is_available")
