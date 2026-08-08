class_name ShotConfig
extends Resource
## One named, repeatable view of the game.
##
## Every screenshot in `devblog/`, every before-and-after comparison and every
## golden-image test comes from one of these. The point is that the same shot
## produces the same pixels on every run: nothing in it is left to the clock, the
## weather, the desktop resolution or where the player happened to be standing.
##
## The alternative is what this project did for its first forty-one features --
## a throwaway script per screenshot with a hand-tuned frame number in it -- and
## the cost showed up as soon as the shots mattered. Captures landed a frame
## early and caught damage numbers mid-fade, `await` inside `_process` quietly
## quit the tree twice, and a stray keypress on the desktop opened the pause menu
## over two of them. None of that is a graphics problem. All of it is what
## happens when the harness is written fresh each time.
##
## See [ShotRunner] for what consumes this, and GRAPHICS.md for why it is
## Phase 0.

## The file name of the golden, and how the shot is named on the command line.
@export var shot_name: StringName = &""

## What the shot is for, in one line. Read by whoever has to decide whether a
## difference is a regression or the improvement they just made.
@export_multiline var description: String = ""

## Render resolution, independent of the window and of the desktop.
##
## The shot renders into its own viewport, which is the other half of the fix for
## the 6K finding: a capture is the size it says it is, on any machine.
@export var resolution: Vector2i = Vector2i(1280, 720)

@export_group("View")
## Where the camera sits: world space, or an offset from the player when
## [member anchor_to_player] is set.
@export var camera_position: Vector3 = Vector3(6.0, 4.0, 6.0)

## What it points at. Built with [method Node3D.look_at] rather than a rotation,
## because a hand-written basis in this project has been transposed before --
## see CLAUDE.md.
@export var camera_target: Vector3 = Vector3.ZERO

## Read [member camera_position] and [member camera_target] as offsets from
## wherever the player ended up standing, rather than as world coordinates.
##
## Needed because the player is dropped onto the terrain, and the terrain is a
## heightfield: at the spawn point the ground is nowhere near y = 0. The first
## three close shots written with absolute coordinates put the camera
## underground, looking up through back-faced terrain at the sky -- and they were
## blessed as goldens, because a picture of the sky is not black and nothing in
## [method problems] could tell it was wrong.
##
## Off for vistas, which are framing the landscape rather than a character and
## are better off saying where they are.
@export var anchor_to_player: bool = false

## Fail the shot unless the player is actually inside the frame.
##
## The guard for the failure above. Everything else about those three shots was
## valid -- a real camera, a real target, a settled world, a plausible image --
## so the only check that could have caught it is asking the camera whether the
## thing the shot is about is in front of it.
@export var must_show_player: bool = false

## Vertical field of view, degrees.
@export_range(20.0, 110.0) var fov: float = 60.0

## Where the player is put, on the ground plane. Height comes from the terrain,
## the same way [WorldRoot] places them normally.
@export var player_position: Vector2 = Vector2.ZERO

@export_group("World state")
## Fraction of the day elapsed. 0.25 is dawn, 0.5 noon, 0.75 dusk.
##
## Set explicitly and then frozen. A shot taken "whenever" is a shot whose
## lighting is a different colour every run, which makes every comparison
## meaningless.
@export_range(0.0, 1.0) var time_of_day: float = 0.36

## Seeds the global RNG before the world is built, so scattered things --
## mushrooms, wanderers, merchants -- land in the same places every time.
@export var rng_seed: int = 20260807

## Items the player is given before the shot is taken, as resource paths.
##
## Needed because some things are only visible when the player has them -- a
## sword is in the hand or it is nowhere -- and a golden that cannot show the
## feature cannot guard it either. Paths rather than [ItemDefinition]s so a shot
## resource does not pull the whole item catalogue in behind it.
@export var give_player: Array[String] = []

## Whether the HUD, chat box and prompts are drawn.
##
## Off for shots about the world, on for shots about the interface. A lighting
## comparison with a health bar in the corner is a lighting comparison with a
## health bar's worth of pixels that can change for unrelated reasons.
@export var show_interface: bool = true

@export_group("Timing")
## Physics frames to run before capturing.
##
## Physics frames, never idle frames: a headless or unfocused run produces idle
## frames at whatever rate it likes while physics stays at 60 Hz, so counting
## `_process` calls times nothing at all. This is the trap from CLAUDE.md,
## spelled into the config so a shot cannot get it wrong.
@export var settle_frames: int = 45

## Frames to count over, after settling.
##
## Separate from settling because the counts are still moving while the world
## builds -- and sampled over many frames rather than read once, because they
## keep moving afterwards as characters animate and wanderers walk out of view.
@export var measure_frames: int = 120

@export_group("Budget")
## Visible draw calls this shot must not typically exceed. 0 means unbudgeted.
##
## Counts rather than milliseconds, and that was not the original plan: see
## [FrameStats] for the three separate ways timing was found to measure nothing
## on this machine. A count is exact, identical on every machine and in CI, and
## it is what actually moves when geometry is added -- which makes it the right
## budget for Phase 3, where dense foliage is a draw-call problem before it is
## anything else.
##
## Set from a measured figure with headroom, never invented. A budget guessed
## before the first measurement is a test that fails for being wrong rather than
## for the code being wrong.
@export var draw_call_budget: int = 0

## Visible primitives this shot must not typically exceed. 0 means unbudgeted.
@export var primitive_budget: int = 0

## The shadow pass, budgeted separately -- and it is the larger half.
##
## `terrain-detail` looks at bare ground and draws 131k primitives; the sun draws
## 525k for the same frame, because it renders the whole heightfield wherever the
## camera is pointing. Budgeting only what the camera can see would be budgeting
## a fifth of the work, and would let a change that quadrupled the sun through
## without a word.
@export var shadow_draw_call_budget: int = 0

@export var shadow_primitive_budget: int = 0

@export_group("Look")
## Most of the frame that may sit below [constant FrameLook.DARK]. 0 is no
## target.
##
## The night-readability rule from `ART.md`, as a number. Night is meant to look
## like night and still be playable; a frame that is almost entirely under this
## threshold is one the player is walking through blind.
@export var max_dark_fraction: float = 0.0

## Most distinct hues the frame may be built from. 0 is no target.
##
## Cohesion is most of what the art direction is asking for, and this is the
## countable part of it. A frame drawing on four hues reads as designed; one
## drawing on eleven reads as assembled from whatever was to hand.
@export var max_hue_count: int = 0

## Least luminance contrast between the player and what is behind them, as a
## ratio. 0 is no target.
##
## Only meaningful with [member must_show_player] set, since there is otherwise
## no subject to measure.
@export var min_subject_contrast: float = 0.0

@export_group("Golden")
## Height the golden is stored at. Width follows the aspect ratio.
@export var golden_height: int = 270

## Whole-frame tolerance before this shot counts as changed.
@export var mean_tolerance: float = ImageDiff.MEAN_TOLERANCE

## Share of pixels allowed to have moved.
@export var changed_tolerance: float = ImageDiff.CHANGED_TOLERANCE


## Everything wrong with this shot, in English, or an empty array.
##
## A test asserts this is empty for every committed shot. A shot with a zero
## resolution or a camera sitting on its own target does not error -- it produces
## a black PNG, which is then blessed as a golden and asserted against forever.
func problems() -> PackedStringArray:
	var found := PackedStringArray()
	if String(shot_name).strip_edges().is_empty():
		found.append("has no shot_name, so it has nowhere to store its golden")
	if resolution.x < 64 or resolution.y < 64:
		found.append("resolution %s is too small to judge anything by" % resolution)
	if camera_position.is_equal_approx(camera_target):
		found.append("the camera is standing on its target, so look_at has no direction")
	if settle_frames < 1:
		found.append("settles for %d frames, so it captures an unbuilt scene" % settle_frames)
	if golden_height < 32 or golden_height > resolution.y:
		found.append("golden_height %d is not a sane reduction of %d" % [
			golden_height, resolution.y
		])
	if mean_tolerance <= 0.0 or changed_tolerance <= 0.0:
		found.append("a zero tolerance demands pixel-exact equality, which no renderer gives")
	if min_subject_contrast > 0.0 and not must_show_player:
		found.append(
			"asks how far the player stands out without asking for them to be in frame"
		)
	return found


## Where the camera goes, given where the player ended up.
##
## Static and pure so the arithmetic is tested without a terrain, a window or a
## renderer -- which is the whole reason the anchoring lives here rather than in
## [ShotRunner].
func camera_at(player_world: Vector3) -> Vector3:
	return player_world + camera_position if anchor_to_player else camera_position


## What the camera looks at, given where the player ended up.
func target_at(player_world: Vector3) -> Vector3:
	return player_world + camera_target if anchor_to_player else camera_target


## Where this shot's golden lives.
func golden_path(directory: String = GOLDEN_DIR) -> String:
	return "%s/%s.png" % [directory.trim_suffix("/"), shot_name]


## The committed goldens. Under `tests/` because they are test fixtures: they are
## the expected values of the only assertion that can be made about a picture.
const GOLDEN_DIR: String = "res://tests/golden"

## Where the shots themselves are defined.
const SHOT_DIR: String = "res://resources/shots"


## Every committed shot, in a stable order.
##
## Sorted through [String], not by [StringName]: comparing StringNames sorts by
## interned pointer, which is allocation order and changes when an unrelated
## file interns a new name. That trap is in CLAUDE.md and it is exactly the kind
## of thing that makes a tool's output differ between two runs for no reason.
static func all(directory: String = SHOT_DIR) -> Array[ShotConfig]:
	var shots: Array[ShotConfig] = []
	var names := PackedStringArray(DirAccess.get_files_at(directory))
	var paths: Array[String] = []
	for name: String in names:
		# Exported projects rename .tres to .remap, and DirAccess reports the
		# renamed file -- so a tool that looks for ".tres" finds nothing in a
		# build and reports "no shots" rather than an error.
		if name.ends_with(".tres") or name.ends_with(".tres.remap"):
			paths.append("%s/%s" % [directory.trim_suffix("/"), name.trim_suffix(".remap")])
	paths.sort()
	for path: String in paths:
		var shot := ResourceLoader.load(path) as ShotConfig
		if shot != null:
			shots.append(shot)
	return shots


## The shot called [param wanted], or null.
static func named(wanted: StringName, directory: String = SHOT_DIR) -> ShotConfig:
	for shot: ShotConfig in all(directory):
		if shot.shot_name == wanted:
			return shot
	return null
