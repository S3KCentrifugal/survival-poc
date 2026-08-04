class_name DevConsole
extends RefCounted
## The developer console's registry, parser and history.
##
## No scene, no input, no text box -- it takes a line and gives back what to
## print. That is what lets every command be exercised in a test rather than by
## typing it and watching, which is exactly the workflow a dev console exists to
## replace.

## What a line that does not name a command gets back.
const UNKNOWN: String = "unknown command: %s (try `help`)"

var _commands: Dictionary[StringName, DevCommand] = {}
var _history: PackedStringArray = []


func _init() -> void:
	# `help` is about the registry, so the registry owns it. It also must not be
	# a command that closes over the console: a bound argument is a strong
	# reference, so `_help.bind(self)` would make console -> command -> callable
	# -> console, and GDScript does not collect reference cycles.
	register(
		DevCommand.new(&"help", "help [command]", "list commands, or explain one", 0, 1, _help)
	)


## Lists every command, or explains one.
func _help(arguments: PackedStringArray) -> String:
	if arguments.is_empty():
		var lines: PackedStringArray = []
		for command: DevCommand in commands():
			lines.append("  %s  %s" % [String(command.name).rpad(9), command.summary])
		return "commands:\n" + "\n".join(lines)

	var found := find(StringName(arguments[0]))
	if found == null:
		return UNKNOWN % arguments[0]
	return "%s\n  %s" % [found.usage, found.summary]


## Adds [param command], replacing any earlier one of the same name.
func register(command: DevCommand) -> void:
	_commands[StringName(String(command.name).to_lower())] = command


func has(name: StringName) -> bool:
	return _commands.has(StringName(String(name).to_lower()))


func find(name: StringName) -> DevCommand:
	return _commands.get(StringName(String(name).to_lower()))


## Every command, in alphabetical order.
##
## Sorted through [String] because [StringName] compares by interned pointer
## rather than by text -- see the trap in CLAUDE.md.
func commands() -> Array[DevCommand]:
	var names: Array[StringName] = []
	names.assign(_commands.keys())
	names.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))

	var found: Array[DevCommand] = []
	for name: StringName in names:
		found.append(_commands[name])
	return found


## Runs [param line] and returns what should be printed.
##
## Never raises and never returns null: a console that can crash the game it is
## meant to be debugging is worse than no console.
func run(line: String) -> String:
	var tokens := _tokenise(line)
	if tokens.is_empty():
		return ""

	_history.append(line.strip_edges())

	var name := tokens[0]
	var command := find(StringName(name))
	if command == null:
		return UNKNOWN % name

	var arguments := tokens.slice(1)
	if not command.accepts(arguments.size()):
		return "usage: %s" % command.usage
	return command.run(arguments)


## Command names starting with [param prefix], for tab completion.
func complete(prefix: String) -> PackedStringArray:
	var lower := prefix.to_lower()
	var matches: PackedStringArray = []
	for command: DevCommand in commands():
		if String(command.name).to_lower().begins_with(lower):
			matches.append(String(command.name))
	return matches


## Lines entered so far, oldest first.
func history() -> PackedStringArray:
	return _history.duplicate()


## Walks back through history. [param steps] of 1 is the most recent line, 2 the
## one before it. Past the end it stays on the oldest rather than wrapping round
## to the newest, which is what every shell does and what fingers expect.
func recall(steps: int) -> String:
	if _history.is_empty() or steps <= 0:
		return ""
	var index := maxi(_history.size() - steps, 0)
	return _history[index]


func clear_history() -> void:
	_history.clear()


## Splits a line on whitespace, discarding the empties that double spaces and
## trailing returns leave behind.
static func _tokenise(line: String) -> PackedStringArray:
	var tokens: PackedStringArray = []
	for part: String in line.strip_edges().split(" ", false):
		var trimmed := part.strip_edges()
		if not trimmed.is_empty():
			tokens.append(trimmed)
	return tokens


## Parses [param text] as a number, or returns [param fallback] if it is not
## one. Guards every numeric command against `tp north` setting a position to
## zero and looking like a teleport that worked.
static func number(text: String, fallback: float = NAN) -> float:
	return text.to_float() if text.is_valid_float() else fallback
