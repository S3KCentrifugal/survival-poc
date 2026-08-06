class_name InteractionRouter
extends Node
## Owns the interact key and decides what it meant.
##
## One search over one group, and whichever [InteractableComponent] is nearest
## wins. Before this there were three groups, three components each implementing
## the same three methods, and two dispatchers watching two keys -- so standing
## between a mushroom and a merchant could pick the mushroom up *and* open the
## shop, and adding a fourth kind of thing meant a fourth of everything.
##
## Each interactable carries its own [member InteractableComponent.reach],
## because a merchant is bigger than a mushroom and that difference belongs to
## the thing rather than to the person walking up to it. Nothing here has to
## know which is which.
##
## Routing is by signal, not by cast: the router calls `interact()` and whoever
## attached the behaviour has already connected to it. That is what keeps this
## file from growing a branch per feature.

## Emitted when what the key would act on changes, including to nothing. A
## prompt reads this rather than polling.
signal target_changed(target: InteractableComponent)

## Emitted after something is interacted with, for anything that wants to know
## without connecting to every interactable in the world.
signal interacted(target: InteractableComponent)

@export var body: Node3D

## Where intent comes from, assigned by whoever assembles the actor.
var input_source: InputSource

var _held: bool = false
var _target: InteractableComponent


func _process(_delta: float) -> void:
	step()


## One tick: work out what the key would do, and do it if asked.
func step() -> void:
	_set_target(find_target())
	if input_source == null:
		return

	var state := input_source.poll()
	var pressed := state.interact and not _held
	_held = state.interact
	if pressed:
		interact()


## Does whatever the key would do. Returns whether anything happened.
##
## Looks first, so calling this without a step() having run does the obvious
## thing rather than nothing -- the lesson from the first version of
## [method PickupCollector.collect].
func interact() -> bool:
	_set_target(find_target())
	if _target == null:
		return false
	_target.interact(body)
	interacted.emit(_target)
	return true


## The nearest interactable within its own reach, or null.
##
## Each candidate is measured against the reach *it* declares, which is why this
## is a loop rather than one call with a single radius. Squared throughout: the
## comparison is the same and there is no square root per candidate per frame.
func find_target() -> InteractableComponent:
	if body == null or not is_inside_tree():
		return null

	var here := body.global_position
	var best: InteractableComponent = null
	var best_distance := INF
	for node: Node in get_tree().get_nodes_in_group(InteractableComponent.GROUP):
		var candidate := node as InteractableComponent
		if candidate == null or not candidate.is_available():
			continue
		var distance := here.distance_squared_to(candidate.world_position())
		if distance <= candidate.reach * candidate.reach and distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func target() -> InteractableComponent:
	return _target


## What a prompt should read, or an empty string when there is nothing in reach.
func prompt_text() -> String:
	return "" if _target == null else _target.prompt_text()


func _set_target(node: InteractableComponent) -> void:
	if node == _target:
		return
	_target = node
	target_changed.emit(node)
