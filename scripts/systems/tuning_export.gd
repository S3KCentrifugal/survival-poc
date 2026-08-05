class_name TuningExport
extends RefCounted
## Writes every tuning `.tres` out as JSON.
##
## A Rust server has to agree with the client on how fast a player moves and how
## hard a punch hits, and it cannot parse `.tres` -- that format is Godot's, and
## reimplementing it is not a reasonable thing to ask of a server.
##
## So the `.tres` files stay the single source of truth, edited in the Godot
## inspector where they belong, and this dumps them into something anything can
## read. Exported rather than hand-maintained, because two hand-maintained
## copies of the same number are two numbers.

const RESOURCES_DIR: String = "res://resources"
const DEFAULT_OUTPUT: String = "user://tuning.json"

## Properties every Resource has and nobody needs on a server.
const SKIPPED: PackedStringArray = ["script", "resource_local_to_scene", "resource_name",
	"resource_path", "resource_scene_unique_id"]


## Every tuning resource, as nested dictionaries: folder -> file -> values.
static func collect(from: String = RESOURCES_DIR) -> Dictionary:
	var tuning: Dictionary = {}
	for folder: String in _folders(from):
		var group: Dictionary = {}
		for file: String in _files("%s/%s" % [from, folder]):
			var resource: Resource = load("%s/%s/%s" % [from, folder, file])
			if resource == null:
				continue
			group[file.trim_suffix(".tres")] = values_of(resource)
		if not group.is_empty():
			tuning[folder] = group
	return tuning


## The exported properties of one resource, as plain values.
##
## Godot types are unwrapped rather than stringified: a `Vector2i` becomes two
## named numbers, because `"(1600, 900)"` is a thing a server would have to
## parse and `{"x": 1600, "y": 900}` is not.
static func values_of(resource: Resource) -> Dictionary:
	var values: Dictionary = {}
	for property: Dictionary in resource.get_property_list():
		if (property["usage"] & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var name: String = property["name"]
		if SKIPPED.has(name):
			continue
		values[name] = _plain(resource.get(name))
	return values


## Writes the export, returning whether it worked.
static func write(path: String = DEFAULT_OUTPUT, from: String = RESOURCES_DIR) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write tuning to %s" % path)
		return false
	file.store_string(JSON.stringify(collect(from), "  ", true))
	file.close()
	return true


## How many resources an export would carry, for a console command to report.
static func count(from: String = RESOURCES_DIR) -> int:
	var total := 0
	for group: Dictionary in collect(from).values():
		total += group.size()
	return total


static func _plain(value: Variant) -> Variant:
	if value is Vector2 or value is Vector2i:
		return {"x": value.x, "y": value.y}
	if value is Vector3 or value is Vector3i:
		return {"x": value.x, "y": value.y, "z": value.z}
	if value is Color:
		return {"r": value.r, "g": value.g, "b": value.b, "a": value.a}
	if value is StringName:
		return String(value)
	# A nested resource -- a material on a config -- is a reference to something
	# the server does not simulate, so it is named rather than followed.
	if value is Resource:
		return (value as Resource).resource_path
	return value


static func _folders(from: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(from)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if dir.current_is_dir() and not entry.begins_with("."):
			found.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found


static func _files(from: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(from)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		# Exported builds rename resources to .remap; tolerate both.
		if not dir.current_is_dir() and entry.trim_suffix(".remap").ends_with(".tres"):
			found.append(entry.trim_suffix(".remap"))
		entry = dir.get_next()
	dir.list_dir_end()
	found.sort()
	return found
