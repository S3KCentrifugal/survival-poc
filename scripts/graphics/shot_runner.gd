class_name ShotRunner
extends Node
## Takes a [ShotConfig] and gives back a frame and what it cost.
##
## The committed replacement for "write a throwaway script that adds the scene,
## counts to thirty and saves a PNG". Four things it does that the throwaway
## scripts kept getting wrong:
##
## [b]It renders into its own viewport.[/b] A [SubViewport] at the shot's
## resolution, with its own [World3D], so a capture is the size it says it is
## whatever the desktop is doing. On the machine this was written for -- a
## 6144x3456 screen -- every previous screenshot came back at 21 megapixels
## because the game renders at whatever the display is.
##
## [b]It waits in physics frames.[/b] Idle frames run at whatever rate the
## machine feels like, so counting `_process` calls times nothing. This is the
## trap already in CLAUDE.md and it caused two lost captures in one afternoon.
##
## [b]It freezes the world.[/b] Time of day set and the clock stopped, the RNG
## seeded before anything is built, the settings file pointed somewhere empty so
## a saved fullscreen preference cannot resize anything. A shot whose lighting
## is a different colour every run cannot be compared with itself.
##
## [b]It counts the frame rather than timing it.[/b] Draw calls and primitives,
## visible and shadow, sampled every measured frame. Timing it was the plan and
## it did not survive contact -- [FrameStats] records the three separate ways
## that was established, including a 36-fold resolution change that the
## renderer's own GPU timer reported as getting *cheaper*.
##
## Run it with `--fixed-fps 60`, which `shots.sh` does. Without it, idle delta is
## real elapsed time and animation lands on a different frame on a busy machine.

const WORLD_SCENE: String = "res://scenes/main.tscn"

## Where the world's settings are read from during a shot.
##
## Deliberately a path that does not exist: [SettingsStore] falls back to
## defaults, so the player's saved fullscreen preference cannot reach the window
## and a shot taken on this desk matches one taken in CI.
const NEUTRAL_SETTINGS: String = "user://shot-neutral-settings.cfg"

## Shots are always taken at this quality, regardless of anyone's settings.
##
## Fixed rather than configurable because a golden compared against a capture at
## a different antialiasing level differs on every edge in the frame, which reads
## as "everything changed" and says nothing.
const SHOT_MSAA: Viewport.MSAA = Viewport.MSAA_4X

## Never drawn in a shot, however the shot is configured. See [method freeze].
const DEVELOPER_LAYERS: Array[StringName] = [&"DebugOverlay", &"DevConsole"]

var _viewport: SubViewport
var _world: Node
var _camera: Camera3D


## Renders [param shot] and returns what came back.
##
## Awaits. Call it from a coroutine that is itself inside the tree -- the entry
## point in `tools/shoot.gd` does this from `_process`, never from
## `_initialize`, because nodes added before the tree is live never enter it and
## `_ready` never fires.
func take(shot: ShotConfig) -> ShotResult:
	var result := ShotResult.new()
	result.shot = shot

	var problems := shot.problems() if shot != null else PackedStringArray(["no shot given"])
	if not problems.is_empty():
		result.error = ", ".join(problems)
		return result

	_build_viewport(shot)
	var failure := _build_world(shot)
	if not failure.is_empty():
		result.error = failure
		_tear_down()
		return result

	await _settle(shot.settle_frames)
	await _measure(shot.measure_frames, result)

	# One more full frame, then read back. Without the wait the texture holds the
	# frame *before* the one just requested -- which at these frame rates is a
	# visible difference, and is how a capture ends up showing damage numbers
	# that had already faded.
	await RenderingServer.frame_post_draw
	var texture := _viewport.get_texture()
	if texture == null:
		# The one thing that cannot be worked around: --headless has no
		# rendering device at all, and the failure is otherwise a null
		# dereference several lines later.
		result.error = "the viewport produced no texture -- is this a --headless run?"
	else:
		result.image = texture.get_image()

	_tear_down()
	return result


## Everything a shot needs the world not to do.
##
## Public and separate so a test can assert the neutering happened without
## needing a renderer: this is the part that goes quietly wrong, because a world
## that is still running its clock still produces a picture.
static func freeze(world: Node, shot: ShotConfig) -> void:
	var clock := world.get_node_or_null("DayNight") as DayNightComponent
	if clock != null:
		clock.set_time_of_day(shot.time_of_day)
		# Stopped, not slowed. The clock runs on the idle clock so that the sun
		# sweeps smoothly, which is right for the game and fatal for a shot.
		clock.set_process(false)

	var world_root := world as WorldRoot
	if world_root != null:
		# The world grabs the cursor as it loads. A tool that steals the mouse
		# and then exits leaves the desktop without one.
		world_root.set_mouse_captured(false)
		world_root.set_input_suspended(true)

	for child: Node in world.get_children():
		var layer := child as CanvasLayer
		if layer == null:
			continue
		# Developer tools are hidden in every shot, whatever the shot asked for.
		# The debug overlay draws a live frame counter, so a shot containing it
		# has a number in the corner that is different on every run -- which
		# fails a golden for a reason that has nothing to do with the picture.
		# They are also not the game: UI.md already exempts them from the design
		# system for the same reason.
		if DEVELOPER_LAYERS.has(child.name):
			layer.visible = false
		elif not shot.show_interface:
			layer.visible = false


func _build_viewport(shot: ShotConfig) -> void:
	_viewport = SubViewport.new()
	_viewport.size = shot.resolution
	# Its own world, or the shot shares lighting and environment with whatever
	# else the tool happens to have in the tree.
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = SHOT_MSAA
	# Never scaled. The render-scale ladder is a policy for players on large
	# displays; a shot that quietly rendered at 70% would be compared against a
	# golden that did not.
	_viewport.scaling_3d_scale = 1.0
	add_child(_viewport)


func _build_world(shot: ShotConfig) -> String:
	# Seeded before the scene is instantiated, not after: mushrooms, wanderers
	# and merchants are scattered in their `_ready`, which runs the moment the
	# node enters the tree.
	seed(shot.rng_seed)

	var packed := load(WORLD_SCENE) as PackedScene
	if packed == null:
		return "could not load %s" % WORLD_SCENE
	_world = packed.instantiate()

	# Before add_child, so it lands before any `_ready` runs. A child is ready
	# before its parent, so a setting pushed afterwards arrives too late -- the
	# same ordering that broke the settings test in devblog 034.
	var pause := _world.get_node_or_null("PauseMenu") as PauseMenu
	if pause != null:
		pause.settings_path = NEUTRAL_SETTINGS
	var world_root := _world as WorldRoot
	if world_root != null:
		world_root.spawn_point = shot.player_position

	_viewport.add_child(_world)
	freeze(_world, shot)
	_take_over_camera(shot)

	# Asked after the camera is placed, and it is the only check that can catch a
	# shot which framed the wrong part of a valid world. See
	# [member ShotConfig.must_show_player].
	if shot.must_show_player and not _player_is_in_frame():
		return "the player is not in frame -- the camera is looking somewhere else"
	return ""


## Whether the player is inside the camera's frustum.
##
## Tested at chest height rather than at the origin, because the origin is
## between the feet: a camera that clips the ground away would report a player
## standing on visible terrain as absent.
func _player_is_in_frame() -> bool:
	var player := _world.get_node_or_null("Player") as Node3D
	if player == null or _camera == null:
		return true
	return _camera.is_position_in_frustum(player.global_position + Vector3.UP)


## Puts a camera of our own in charge.
##
## The game's own camera orbits the player and eases towards them, so a shot
## framed through it depends on how many frames have passed -- which is the
## thing being removed. This one is placed once, points where the shot says, and
## does not move.
func _take_over_camera(shot: ShotConfig) -> void:
	var follower := _world.get_node_or_null("PlayerCamera") as CameraController
	if follower != null:
		follower.set_process(false)
		follower.current = false

	# Where the player actually ended up, which is a terrain height rather than
	# the ground plane the shot names.
	var player := _world.get_node_or_null("Player") as Node3D
	var stood := player.global_position if player != null else Vector3.ZERO

	_camera = Camera3D.new()
	_camera.fov = shot.fov
	_world.add_child(_camera)
	_camera.global_position = shot.camera_at(stood)
	# look_at rather than a hand-built basis: a Transform3D assembled from axis
	# vectors in this project has come out transposed before, and the tell is a
	# diagonal horizon in a frame nobody looks at closely.
	_camera.look_at(shot.target_at(stood), Vector3.UP)
	_camera.current = true


func _settle(frames: int) -> void:
	var until := Engine.get_physics_frames() + frames
	while Engine.get_physics_frames() < until:
		await get_tree().physics_frame


## Counts what the renderer drew, once per frame, for [param frames] frames.
##
## Sampled over many frames rather than read once, because the counts move
## within a run: a character animates, a wanderer walks behind a hill and stops
## being drawn, a mushroom regrows. One frame's number is a sample.
func _measure(frames: int, result: ShotResult) -> void:
	var rid := _viewport.get_viewport_rid()
	var seen := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE
	var shadowed := RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW
	var draws := RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	var prims := RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME
	var objs := RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME
	for _index in frames:
		await RenderingServer.frame_post_draw
		result.draw_calls.add(RenderingServer.viewport_get_render_info(rid, seen, draws))
		result.primitives.add(RenderingServer.viewport_get_render_info(rid, seen, prims))
		result.objects.add(RenderingServer.viewport_get_render_info(rid, seen, objs))
		result.shadow_draw_calls.add(
			RenderingServer.viewport_get_render_info(rid, shadowed, draws)
		)
		result.shadow_primitives.add(
			RenderingServer.viewport_get_render_info(rid, shadowed, prims)
		)


func _tear_down() -> void:
	# free(), not queue_free(): the runner takes the next shot immediately, and
	# two worlds alive at once means two of everything that registers itself
	# globally -- and twice the memory, at a resolution chosen to be large.
	if is_instance_valid(_world):
		_world.free()
	if is_instance_valid(_viewport):
		_viewport.free()
	_world = null
	_viewport = null
	_camera = null
