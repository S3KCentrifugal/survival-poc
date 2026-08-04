class_name SaveRegistry
extends RefCounted
## Everything in a world that a save file can address, indexed by id.
##
## Built on demand rather than kept up to date: a live registry has to be told
## about every spawn and every free, and the one that is never told is the bug.
## Walking the group when a save actually happens cannot go stale.
##
## The duplicate check is the reason this exists as a class instead of a
## dictionary comprehension. Two objects sharing an id is not a crash -- it is a
## save where one of them quietly overwrites the other, discovered by a player
## a week later when their chest is empty.

var _by_id: Dictionary[StringName, SaveIdComponent] = {}
var _duplicates: Array[StringName] = []


func _init(components: Array[SaveIdComponent] = []) -> void:
	for component: SaveIdComponent in components:
		add(component)


## Indexes everything in the tree carrying a [SaveIdComponent].
##
## Warns about collisions rather than staying silent: whoever is about to write
## a save is the last person in a position to notice.
static func from_tree(tree: SceneTree) -> SaveRegistry:
	var components: Array[SaveIdComponent] = []
	for node: Node in tree.get_nodes_in_group(SaveIdComponent.GROUP):
		var component := node as SaveIdComponent
		if component != null:
			components.append(component)

	var registry := SaveRegistry.new(components)
	if registry.has_duplicates():
		push_warning(
			"Duplicate save ids, objects will overwrite each other: %s" % [registry.duplicates()]
		)
	return registry


## Indexes [param component], or reports the id as taken and leaves the first
## one in place. First come, first served -- an arbitrary rule, but a stable
## one, and the caller finds out either way.
func add(component: SaveIdComponent) -> bool:
	if component == null:
		return false
	var key := component.save_key()
	if _by_id.has(key):
		if not _duplicates.has(key):
			_duplicates.append(key)
		return false
	_by_id[key] = component
	return true


func find(id: StringName) -> SaveIdComponent:
	return _by_id.get(id)


func has(id: StringName) -> bool:
	return _by_id.has(id)


## Every indexed id, in alphabetical order.
##
## Sorted through [String] deliberately. [StringName]'s comparison operators
## compare the interned pointer rather than the text -- fast, and the whole
## point of the type -- so a plain sort returns whatever order the names
## happened to be allocated in. That is stable within a run and changes the
## moment an unrelated system interns a new name, which makes for a test that
## passes until someone edits something else entirely.
func ids() -> Array[StringName]:
	var keys: Array[StringName] = []
	keys.assign(_by_id.keys())
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return keys


func size() -> int:
	return _by_id.size()


## Ids that more than one object claimed.
func duplicates() -> Array[StringName]:
	return _duplicates.duplicate()


func has_duplicates() -> bool:
	return not _duplicates.is_empty()
