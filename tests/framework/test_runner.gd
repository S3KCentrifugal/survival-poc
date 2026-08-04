extends SceneTree
## Headless test entry point.
##
##     godot --headless --path . --script tests/framework/test_runner.gd
##
## Discovers every `res://tests/test_*.gd`, runs each `test_*` method, and exits
## non-zero if any assertion failed so a shell or CI step can gate on it.

const TESTS_DIR: String = "res://tests"

## Suites run on the first processed frame rather than in `_initialize`.
## Nodes added to `root` before the tree is live never enter it, so `_ready`
## would not fire and any scene-level test would silently see an unbuilt UI.
var _has_run: bool = false

var _suites_run: int = 0
var _methods_run: int = 0
var _methods_failed: int = 0

## Suites that could not be loaded or instantiated at all. Counted separately
## from assertion failures because a suite that never runs would otherwise
## vanish from the totals and let a broken build report success.
var _suites_broken: int = 0

var _assertions: int = 0
var _failure_lines: PackedStringArray = []


func _process(_delta: float) -> bool:
	if _has_run:
		return true
	_has_run = true

	print_rich("[b]survival-poc test suite[/b]")
	var script_paths := _discover_suites()
	if script_paths.is_empty():
		push_error("No test suites found in %s" % TESTS_DIR)
		quit(1)
		return true

	for path: String in script_paths:
		_run_suite(path)

	_report()
	quit(1 if _methods_failed > 0 or _suites_broken > 0 else 0)
	return true


## Every `test_*.gd` directly inside [constant TESTS_DIR]. The framework itself
## lives in a subdirectory and is skipped by not recursing.
func _discover_suites() -> PackedStringArray:
	var paths: PackedStringArray = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		push_error("Cannot open %s: %s" % [TESTS_DIR, error_string(DirAccess.get_open_error())])
		return paths

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		# Exported builds rename scripts to .gd.remap; tolerate both so this
		# runner is not source-tree-only.
		var is_script := entry.ends_with(".gd") or entry.ends_with(".gd.remap")
		if not dir.current_is_dir() and entry.begins_with("test_") and is_script:
			paths.append("%s/%s" % [TESTS_DIR, entry.trim_suffix(".remap")])
		entry = dir.get_next()
	dir.list_dir_end()

	paths.sort()
	return paths


func _run_suite(path: String) -> void:
	var script: GDScript = load(path)
	if script == null:
		_break_suite(path.get_file(), "could not be loaded")
		return
	# A script with a parse error still loads, but cannot be instantiated --
	# calling new() on it would itself error out.
	if not script.can_instantiate():
		_break_suite(path.get_file(), "failed to compile (see the parse error above)")
		return

	var instance: Variant = script.new()
	if not (instance is TestCase):
		_break_suite(path.get_file(), "does not extend TestCase")
		return
	var suite: TestCase = instance

	_suites_run += 1
	var suite_name := path.get_file().trim_suffix(".gd")
	print("\n  %s" % suite_name)

	for method_name: String in suite.collect_test_methods():
		_run_method(suite, suite_name, method_name)

	_assertions += suite.assertion_count()


func _run_method(suite: TestCase, suite_name: String, method_name: String) -> void:
	_methods_run += 1
	suite.begin_method()
	suite.before_each()
	suite.call(method_name)
	suite.after_each()

	var failures := suite.failures()
	if failures.is_empty():
		print("    ok    %s" % method_name)
		return

	_methods_failed += 1
	print("    FAIL  %s" % method_name)
	for failure: String in failures:
		print("            %s" % failure)
		_record_failure(suite_name, method_name, failure)


func _record_failure(suite_name: String, method_name: String, text: String) -> void:
	_failure_lines.append("%s.%s: %s" % [suite_name, method_name, text])


## Records a suite that never ran. This must affect the exit code -- a suite
## that cannot load is a failure, not an absence.
func _break_suite(suite_name: String, reason: String) -> void:
	_suites_broken += 1
	print("\n  %s\n    BROKEN  %s" % [suite_name, reason])
	_failure_lines.append("%s: %s" % [suite_name, reason])


func _report() -> void:
	print("\n  %d suites, %d tests, %d assertions" % [_suites_run, _methods_run, _assertions])
	if _methods_failed == 0 and _suites_broken == 0:
		print("  all passing\n")
		return
	if _suites_broken > 0:
		print("  %d SUITE(S) COULD NOT RUN" % _suites_broken)
	print("  %d FAILING\n" % _methods_failed)
	for line: String in _failure_lines:
		print("    %s" % line)
	print("")
