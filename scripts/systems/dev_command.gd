class_name DevCommand
extends RefCounted
## One thing the developer console can do.
##
## The command owns its own usage text and argument count, so [DevConsole] can
## reject a bad call and print how it should have been written without every
## command repeating that check.

## What you type. Matched case-insensitively.
var name: StringName

## How to write it, including arguments: [code]tp <x> <z>[/code].
var usage: String

## One line for the help listing.
var summary: String

## Fewest and most arguments accepted. A [param max_args] of -1 means any
## number.
var min_args: int
var max_args: int

## Takes the arguments, returns what to print. Returning an empty string prints
## nothing, which is what a command that speaks for itself should do.
var action: Callable


func _init(
	p_name: StringName,
	p_usage: String,
	p_summary: String,
	p_min_args: int,
	p_max_args: int,
	p_action: Callable
) -> void:
	name = p_name
	usage = p_usage
	summary = p_summary
	min_args = p_min_args
	max_args = p_max_args
	action = p_action


## Whether [param count] arguments is a call this command can answer.
func accepts(count: int) -> bool:
	if count < min_args:
		return false
	return max_args < 0 or count <= max_args


func run(arguments: PackedStringArray) -> String:
	if not action.is_valid():
		return "%s is registered but does nothing" % name
	var result: Variant = action.call(arguments)
	return "" if result == null else str(result)
