class_name Interactor
extends Node
## Uses whatever the player is standing next to.
##
## The counterpart to [PickupCollector], and deliberately its twin: same reach
## check through [Proximity], same rising-edge input, same target-changed signal
## for a prompt. The difference is only which group it looks in and what it does
## when it finds something.
##
## They are separate components on a separate key because they are separate
## verbs -- F takes a thing away, E operates a thing that stays. Folding both
## behind one key means deciding what "press F" means when a mushroom is growing
## next to a bench, and that is a question with no good answer.

signal target_changed(interactable: WorkbenchComponent)

## Emitted when the player uses something.
signal used(interactable: WorkbenchComponent)

@export var body: Node3D

## How far the player can reach. Wider than a pickup's: a bench is a big thing
## and you should not have to stand on it.
@export_range(0.5, 8.0, 0.1) var reach: float = 2.6

## Where intent comes from, assigned by whoever assembles the actor.
var input_source: InputSource

var _use_held: bool = false
var _target: WorkbenchComponent


func _process(_delta: float) -> void:
	step()


## One tick: find what is in reach, and use it if asked.
func step() -> void:
	_set_target(find_target())
	if input_source == null:
		return

	var state := input_source.poll()
	var pressed := state.use and not _use_held
	_use_held = state.use
	if pressed:
		use()


## Uses whatever is in reach. Returns whether anything was used.
##
## Looks first, so calling this without a step() having run does the obvious
## thing rather than nothing -- the lesson from PickupCollector.collect().
func use() -> bool:
	_set_target(find_target())
	if _target == null:
		return false
	_target.use(body)
	used.emit(_target)
	return true


func find_target() -> WorkbenchComponent:
	if body == null or not is_inside_tree():
		return null
	return Proximity.nearest(
		body.global_position, get_tree().get_nodes_in_group(WorkbenchComponent.GROUP), reach
	) as WorkbenchComponent


func target() -> WorkbenchComponent:
	return _target


func _set_target(interactable: WorkbenchComponent) -> void:
	if interactable == _target:
		return
	_target = interactable
	target_changed.emit(interactable)
