extends TestCase
## The console's registry, parser and history — everything that can be checked
## without a text box.

var _console: DevConsole
var _calls: Array[PackedStringArray] = []


func before_each() -> void:
	_console = DevConsole.new()
	_calls = []


func _echo(arguments: PackedStringArray) -> String:
	_calls.append(arguments)
	return "ok %d" % arguments.size()


func _register(name: StringName, min_args: int = 0, max_args: int = -1) -> void:
	_console.register(
		DevCommand.new(name, "%s usage" % name, "does %s" % name, min_args, max_args, _echo)
	)


func test_a_registered_command_runs() -> void:
	_register(&"ping")
	assert_eq(_console.run("ping"), "ok 0")
	assert_eq(_calls.size(), 1)


func test_arguments_reach_the_command() -> void:
	_register(&"tp")
	_console.run("tp 3 -7")
	assert_eq(_calls[0], PackedStringArray(["3", "-7"]))


func test_extra_spaces_do_not_become_arguments() -> void:
	# Typing is sloppy; a double space must not read as an empty argument.
	_register(&"tp")
	_console.run("  tp   3    -7  ")
	assert_eq(_calls[0], PackedStringArray(["3", "-7"]))


func test_commands_are_case_insensitive() -> void:
	_register(&"heal")
	assert_eq(_console.run("HEAL"), "ok 0")
	assert_true(_console.has(&"Heal"))


func test_an_unknown_command_says_so_rather_than_failing_silently() -> void:
	var result := _console.run("frobnicate")
	assert_true(result.contains("frobnicate"), "got %s" % result)
	assert_true(result.contains("help"), "should point at help, got %s" % result)


func test_an_empty_line_does_nothing() -> void:
	_register(&"ping")
	assert_eq(_console.run(""), "")
	assert_eq(_console.run("   "), "")
	assert_true(_calls.is_empty())


func test_too_few_arguments_prints_the_usage() -> void:
	_register(&"tp", 2, 2)
	assert_eq(_console.run("tp 3"), "usage: tp usage")
	assert_true(_calls.is_empty(), "the command ran anyway")


func test_too_many_arguments_prints_the_usage() -> void:
	_register(&"kill", 0, 0)
	assert_eq(_console.run("kill everyone twice"), "usage: kill usage")


func test_a_command_can_take_any_number_of_arguments() -> void:
	_register(&"say", 0, -1)
	assert_eq(_console.run("say one two three four"), "ok 4")


## `help` is about the registry, so a bare console already has it.
func test_help_is_built_in() -> void:
	assert_true(_console.has(&"help"))
	assert_true(_console.run("help").contains("help"))


func test_registering_the_same_name_replaces_it() -> void:
	var before := _console.commands().size()
	_register(&"ping")
	_console.register(
		DevCommand.new(&"ping", "ping", "the new one", 0, 0, func(_a: PackedStringArray) -> String:
			return "replaced")
	)
	assert_eq(_console.run("ping"), "replaced")
	assert_eq(_console.commands().size(), before + 1, "the replacement was added alongside")


func test_commands_list_alphabetically() -> void:
	for name: StringName in [&"time", &"heal", &"where", &"kill"]:
		_register(name)
	var names: Array[String] = []
	for command: DevCommand in _console.commands():
		names.append(String(command.name))
	assert_eq(names, ["heal", "help", "kill", "time", "where"] as Array[String])


## A console that can crash the game it is meant to be debugging is worse than
## no console.
func test_a_command_with_no_action_does_not_crash() -> void:
	_console.register(DevCommand.new(&"broken", "broken", "", 0, 0, Callable()))
	assert_true(_console.run("broken").contains("broken"))


func test_history_records_what_was_typed() -> void:
	_register(&"ping")
	_console.run("ping")
	_console.run("ping again")
	assert_eq(_console.history(), PackedStringArray(["ping", "ping again"]))


func test_blank_lines_are_not_worth_recalling() -> void:
	_console.run("   ")
	assert_true(_console.history().is_empty())


func test_recall_walks_backwards_through_history() -> void:
	_register(&"a")
	_register(&"b")
	_console.run("a")
	_console.run("b")
	assert_eq(_console.recall(1), "b", "one step back should be the last line")
	assert_eq(_console.recall(2), "a")


## Every shell stops at the oldest line rather than wrapping round to the
## newest, and fingers expect it.
func test_recall_past_the_start_stays_on_the_oldest() -> void:
	_register(&"a")
	_console.run("a")
	assert_eq(_console.recall(99), "a")


func test_recall_of_nothing_is_empty() -> void:
	assert_eq(_console.recall(1), "")
	assert_eq(_console.recall(0), "")


func test_completion_finds_every_command_with_the_prefix() -> void:
	for name: StringName in [&"heal", &"help", &"hurt", &"time"]:
		_register(name)
	assert_eq(_console.complete("he"), PackedStringArray(["heal", "help"]))


func test_completion_is_case_insensitive() -> void:
	_register(&"hurt")
	assert_eq(_console.complete("HU"), PackedStringArray(["hurt"]))


func test_completing_nothing_offers_everything() -> void:
	var before := _console.commands().size()
	_register(&"heal")
	_register(&"time")
	assert_eq(_console.complete("").size(), before + 2)


## `tp north` must not silently read as zero and look like a teleport that
## worked.
func test_a_number_that_is_not_a_number_is_refused() -> void:
	assert_true(is_nan(DevConsole.number("north")))
	assert_true(is_nan(DevConsole.number("")))
	assert_eq(DevConsole.number("nope", 5.0), 5.0)


func test_numbers_parse() -> void:
	assert_eq(DevConsole.number("3"), 3.0)
	assert_eq(DevConsole.number("-7.5"), -7.5)
