class_name DevConsoleUI
extends CanvasLayer
## The panel you drop down with the backtick key.
##
## Owns the text box and the keys; [DevConsole] owns what the commands mean and
## [GameCommands] owns what they do. This file should stay boring.

## Emitted after a line runs, carrying what was printed. Mostly for tests.
signal line_run(line: String, output: String)

## Drops the console down. Backtick by convention, and because no game binds it
## to anything else.
##
## Handled in [method _input] rather than [method _unhandled_key_input]: the
## text box has focus while the console is open and would otherwise type the
## key that is meant to close it.
@export var toggle_key: Key = KEY_QUOTELEFT

## Freezes the world while the console is open.
##
## On by default. Without it the player keeps walking as you type, because
## [PlayerInputSource] reads the [Input] singleton, and a focused text box does
## nothing to that.
@export var pause_while_open: bool = true

## How many lines of output to keep.
@export_range(20, 2000, 10) var scrollback: int = 400

@export var output: RichTextLabel
@export var entry: LineEdit

## Asked to release the cursor while the console is open. A console you cannot
## click into is not much of a console.
@export var world_root: WorldRoot

@export_group("Watching")
@export var player: CharacterBody3D
@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var movement: MovementComponent
@export var day_night: DayNightComponent
@export var terrain: Terrain

var _console: DevConsole

## Held, not just used. A [Callable] stores an object *id*, not a reference, so
## letting the [GameCommands] that owns every command's method go out of scope
## frees it and quietly invalidates all of them -- the console then answers
## every command with "registered but does nothing".
var _commands: GameCommands

var _lines: PackedStringArray = []

## How far back through history the up arrow has walked.
var _recall_depth: int = 0


func _ready() -> void:
	# The console has to keep running when it has paused everything else.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_console()
	if entry != null:
		entry.text_submitted.connect(_on_submitted)
	print_line("survival-poc console. `help` lists commands, ` closes.")


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return

	if key.keycode == toggle_key:
		set_open(not visible)
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	match key.keycode:
		KEY_ESCAPE:
			set_open(false)
		KEY_UP:
			_recall(_recall_depth + 1)
		KEY_DOWN:
			_recall(_recall_depth - 1)
		KEY_TAB:
			_complete()
		_:
			return
	get_viewport().set_input_as_handled()


## The registry, so a test can ask what is installed.
func console() -> DevConsole:
	return _console


func set_open(open: bool) -> void:
	visible = open
	if pause_while_open:
		get_tree().paused = open
	if world_root != null:
		world_root.set_mouse_captured(not open)
	if entry == null:
		return
	if open:
		entry.clear()
		entry.grab_focus()
		_recall_depth = 0
	else:
		entry.release_focus()


## Runs [param line] as if it had been typed.
func submit(line: String) -> String:
	# Echo before running, not after: `clear` has to be able to clear its own
	# echo, and you want to see what you typed above the answer regardless.
	var trimmed := line.strip_edges()
	if not trimmed.is_empty():
		print_line("> " + trimmed)
	var result := _console.run(line)
	if not result.is_empty():
		print_line(result)
	_recall_depth = 0
	line_run.emit(line, result)
	return result


## Adds a line to the scrollback.
func print_line(text: String) -> void:
	_lines.append(text)
	if _lines.size() > scrollback:
		_lines = _lines.slice(_lines.size() - scrollback)
	if output != null:
		output.text = "\n".join(_lines)


func lines() -> PackedStringArray:
	return _lines.duplicate()


func _build_console() -> void:
	_console = DevConsole.new()

	_commands = GameCommands.new()
	_commands.player = player
	_commands.health = health
	_commands.stamina = stamina
	_commands.movement = movement
	_commands.day_night = day_night
	_commands.terrain = terrain
	_commands.tree = get_tree()
	_commands.install(_console)

	# Owned here rather than by GameCommands: clearing the scrollback is the
	# panel's business, not the game's.
	_console.register(
		DevCommand.new(&"clear", "clear", "empty the console", 0, 0, _clear)
	)


func _clear(_arguments: PackedStringArray) -> String:
	_lines.clear()
	if output != null:
		output.text = ""
	return ""


func _on_submitted(line: String) -> void:
	submit(line)
	if entry != null:
		entry.clear()


func _recall(depth: int) -> void:
	if entry == null:
		return
	_recall_depth = maxi(depth, 0)
	entry.text = _console.recall(_recall_depth)
	entry.caret_column = entry.text.length()


## Completes to the one match, or lists them all if there is more than one --
## the same bargain a shell makes.
func _complete() -> void:
	if entry == null:
		return
	var matches := _console.complete(entry.text)
	if matches.is_empty():
		return
	if matches.size() == 1:
		entry.text = matches[0] + " "
		entry.caret_column = entry.text.length()
		return
	print_line("  ".join(matches))
