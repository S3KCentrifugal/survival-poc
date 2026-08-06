class_name TestCase
extends RefCounted
## Base class for a test suite.
##
## Godot ships no test framework, and the usual addons (GUT, GdUnit4) are a
## network dependency this project does not otherwise have -- so suites are
## plain scripts and the runner finds their `test_*` methods by reflection.
##
## Subclass, add methods named `test_something`, and assert. Override
## [method before_each] / [method after_each] for shared fixtures.

## Failure messages recorded during the method currently running.
## Nodes mounted through [method mount], freed after every test method.
##
## Here rather than in each suite because thirty-seven of them had copied the
## same five lines, and a suite that forgets them leaks into the next one --
## which shows up as an unrelated test failing for reasons its own file cannot
## explain.
var _mounted: Array[Node] = []

var _failures: PackedStringArray = []
var _assertion_count: int = 0


## Runs before every test method.
func before_each() -> void:
	pass


## Runs after every test method, even if it failed.
## The live tree. Every scene test needs it and every suite was casting for it.
func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## Adds [param node] to the tree and frees it after this test method.
##
## Returns what it was given, so it reads inline:
## [code]var world := mount(load(MAIN_SCENE).instantiate())[/code].
func mount(node: Node) -> Node:
	if node != null:
		tree().root.add_child(node)
		_mounted.append(node)
	return node


## Frees everything mounted. Called by the runner *after* [method after_each],
## not from it -- a suite that overrides after_each without calling super would
## otherwise silently stop cleaning up, which is exactly the kind of quiet
## breakage this is here to prevent.
func release_mounted() -> void:
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()


func after_each() -> void:
	pass


## Names of every `test_*` method on this suite, sorted for stable output.
##
## Deliberately not named `test_...` itself, or it would match its own filter
## and be run as a test in every suite.
func collect_test_methods() -> PackedStringArray:
	var names: PackedStringArray = []
	for method: Dictionary in get_method_list():
		var method_name: String = method["name"]
		if method_name.begins_with("test_") and not names.has(method_name):
			names.append(method_name)
	names.sort()
	return names


## Clears recorded failures ahead of a single test method.
func begin_method() -> void:
	_failures = []


func failures() -> PackedStringArray:
	return _failures


func assertion_count() -> int:
	return _assertion_count


func _fail(text: String, message: String) -> void:
	_failures.append(text if message.is_empty() else "%s -- %s" % [text, message])


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	_assertion_count += 1
	if actual != expected:
		_fail("expected %s, got %s" % [_show(expected), _show(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	_assertion_count += 1
	if actual == unexpected:
		_fail("expected anything but %s" % _show(unexpected), message)


func assert_true(value: bool, message: String = "") -> void:
	_assertion_count += 1
	if not value:
		_fail("expected true", message)


func assert_false(value: bool, message: String = "") -> void:
	_assertion_count += 1
	if value:
		_fail("expected false", message)


func assert_null(value: Variant, message: String = "") -> void:
	_assertion_count += 1
	if value != null:
		_fail("expected null, got %s" % _show(value), message)


func assert_not_null(value: Variant, message: String = "") -> void:
	_assertion_count += 1
	if value == null:
		_fail("expected non-null", message)


## Asserts [param value] lies within the inclusive range, which is how most of
## the die and board invariants are stated.
func assert_between(value: int, low: int, high: int, message: String = "") -> void:
	_assertion_count += 1
	if value < low or value > high:
		_fail("expected %d..%d, got %d" % [low, high, value], message)


func fail(message: String) -> void:
	_assertion_count += 1
	_fail("explicit failure", message)


func _show(value: Variant) -> String:
	return "\"%s\"" % value if value is String else str(value)
