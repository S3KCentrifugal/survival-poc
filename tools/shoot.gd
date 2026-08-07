extends SceneTree
## The screenshot and golden-image tool. Driven by `shots.sh`, not run directly.
##
##   shots.sh list                 what shots exist
##   shots.sh capture [name...]    render into .shots/, full size
##   shots.sh check  [name...]     render and compare against tests/golden/
##   shots.sh bless  [name...]     accept what is rendered as the new goldens
##
## `check` exits non-zero when a frame changed, which is what makes "improve the
## lighting" a safe operation: the shots that should not have changed are
## asserted not to have, and the ones that did are written out next to a
## difference image so the reason can be looked at rather than guessed.
##
## Not part of `run_tests.sh`. The suite is headless and headless cannot render
## -- `root.get_texture()` returns null and the error is a null parameter
## several frames later. The *logic* here is covered by the suite instead
## ([ImageDiff], [FrameStats], [RenderBudget], [ShotConfig]); only the rendering
## needs a display, and that is this tool.

## Full-resolution captures. Ignored by git: they are output, and a 1280x720 PNG
## per shot per run adds up faster than anything else in the repository.
const CAPTURE_DIR: String = "res://.shots"

const USAGE: String = "usage: shots.sh <list|capture|check|bless> [shot name...]"

var _started: bool = false


func _initialize() -> void:
	# Music and combat sounds during a tool run are startling and slow nothing
	# down; muted rather than disabled so nothing has to know it is a shot.
	var master := AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, true)


## Started here rather than in [method _initialize], because nodes added before
## the tree is live never enter it and their `_ready` never fires -- the trap
## that makes a scene test inspect an unbuilt node, and that makes a screenshot
## harness capture an empty world.
##
## Returns false explicitly and always. `_run()` is a coroutine: returning its
## value hands the SceneTree a [GDScriptFunctionState], which it reads as truthy
## and quits on before a single frame is drawn. That has cost two afternoons in
## this project, in two different throwaway scripts, which is most of why this
## file exists.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	var arguments := PackedStringArray(OS.get_cmdline_user_args())
	if arguments.is_empty():
		_fail(USAGE)
		return

	var command := arguments[0]
	var wanted := arguments.slice(1)
	var shots := _selected(wanted)
	if shots.is_empty():
		_fail("no shots matched %s" % ("everything" if wanted.is_empty() else str(wanted)))
		return

	if command == "list":
		for shot: ShotConfig in shots:
			print("%-22s %dx%d  %s" % [
				shot.shot_name, shot.resolution.x, shot.resolution.y, shot.description
			])
		quit(0)
		return

	if not ["capture", "check", "bless"].has(command):
		_fail(USAGE)
		return

	var runner := ShotRunner.new()
	root.add_child(runner)

	var failures: int = 0
	for shot: ShotConfig in shots:
		var result: ShotResult = await runner.take(shot)
		if not result.ok():
			print("%s: FAILED -- %s" % [shot.shot_name, result.error])
			failures += 1
			continue
		match command:
			"capture":
				failures += _capture(result)
			"bless":
				failures += _bless(result)
			_:
				failures += _check(result)

	runner.queue_free()
	quit(1 if failures > 0 else 0)


## Writes the frame at full size, for looking at.
func _capture(result: ShotResult) -> int:
	var path := "%s/%s.png" % [CAPTURE_DIR, result.shot.shot_name]
	if not _write(result.image, path):
		return 1
	print("%s  -> %s" % [_cost(result), ProjectSettings.globalize_path(path)])
	return 0


## Accepts the frame as the expected one.
func _bless(result: ShotResult) -> int:
	var golden := ImageDiff.to_golden(result.image, result.shot.golden_height)
	if not _write(golden, result.shot.golden_path()):
		return 1
	print("%s  blessed %dx%d" % [_cost(result), golden.get_width(), golden.get_height()])
	return 0


## Compares the frame against its golden and reports.
##
## A missing golden is a failure rather than an implicit bless. Blessing has to
## be somebody typing `bless`, or the first run after a regression quietly
## records the regression as correct.
func _check(result: ShotResult) -> int:
	var shot := result.shot
	var expected := _read(shot.golden_path())
	if expected == null:
		print("%s: no golden yet -- run `shots.sh bless %s`" % [shot.shot_name, shot.shot_name])
		return 1

	var actual := ImageDiff.to_golden(result.image, shot.golden_height)
	var diff := ImageDiff.compare(actual, expected)
	var budget_ok := result.within_budget()

	if diff.within(shot.mean_tolerance, shot.changed_tolerance) and budget_ok:
		print("%s  ok  %s" % [_cost(result), diff.summary()])
		return 0

	# Written next to each other on purpose: three files in one directory beats
	# a number in a log for working out whether a change was the intended one.
	_write(actual, "%s/%s.actual.png" % [CAPTURE_DIR, shot.shot_name])
	_write(expected, "%s/%s.expected.png" % [CAPTURE_DIR, shot.shot_name])
	_write(
		ImageDiff.difference_image(actual, expected),
		"%s/%s.diff.png" % [CAPTURE_DIR, shot.shot_name]
	)
	if not budget_ok:
		print("%s: OVER BUDGET -- %s" % [shot.shot_name, result.over_budget_reason()])
	if not diff.within(shot.mean_tolerance, shot.changed_tolerance):
		print("%s: CHANGED -- %s" % [shot.shot_name, diff.summary()])
	print("       see %s/%s.*.png" % [ProjectSettings.globalize_path(CAPTURE_DIR), shot.shot_name])
	return 1


## The frame cost, quoted with every line so a graphics change is never reported
## without what it cost.
##
## Draw calls and primitives, visible and shadow. No milliseconds: there is no
## timing on this machine that survived being checked, and a plausible number
## that means nothing is worse than no number, because somebody will quote it.
func _cost(result: ShotResult) -> String:
	return "%-22s %s" % [result.shot.shot_name, result.cost()]


func _selected(wanted: PackedStringArray) -> Array[ShotConfig]:
	var all := ShotConfig.all()
	if wanted.is_empty():
		return all
	var chosen: Array[ShotConfig] = []
	for shot: ShotConfig in all:
		if wanted.has(String(shot.shot_name)):
			chosen.append(shot)
	return chosen


## Godot's own file API cannot write into `res://` in every configuration, and
## the goldens are deliberately hidden from the importer by a `.gdignore` -- so
## everything here goes through absolute paths.
func _write(image: Image, path: String) -> bool:
	if image == null:
		return false
	var absolute := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var status := image.save_png(absolute)
	if status != OK:
		print("could not write %s (error %d)" % [absolute, status])
	return status == OK


func _read(path: String) -> Image:
	var absolute := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return null
	return Image.load_from_file(absolute)


func _fail(message: String) -> void:
	print(message)
	quit(2)
