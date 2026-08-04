# Working in this project

A long-lived 3D survival game in Godot 4. Optimise for the person reading this
in a year, not for finishing the current task quickly.

## Environment

**Engine: Godot 4.7.1 stable** (`4.7.1.stable.official.a13da4feb`), GDScript
only — no C#, no .NET build step.

The version is **pinned** in `.godot-version` and is not a suggestion. Opening
the project with a newer Godot rewrites scenes and resources in place, and the
rewrite is not reversible. Always launch through the wrappers below, which read
the pin, rather than invoking whatever `godot` happens to be on `PATH` — there
may not be one.

This repo lives inside a managed tree. The layout is what matters; the absolute
paths are what it resolves to on this machine:

| What | Path |
|---|---|
| Repo | `<games-root>/projects/survival-poc` → `/home/rob/games/projects/survival-poc` |
| Engine binary | `<games-root>/engine/<version>/godot` → `/home/rob/games/engine/4.7.1/godot` |
| Default engine | `<games-root>/engine/current` (symlink → `4.7.1`) |
| Art/audio masters | `<games-root>/source/survival-poc` — **outside the repo, not in git** |
| Builds | `<games-root>/exports/survival-poc` — **outside the repo, not in git** |
| Shared asset library | `<games-root>/library` — **outside the repo, not in git** |
| Toolkit | `<games-root>/toolkit` (`bootstrap.sh`, `snapshot.sh`, `gd`, `new-game`) |
| Remote | `git@github.com:S3KCentrifugal/survival-poc.git` |

`<games-root>` is the repo's `../..`, which is how `run.sh` and `run_tests.sh`
find the engine. It can be relocated via `GAMES_ROOT`, so prefer the wrappers
over hardcoding any of the absolute paths above.

Authoring files (`.blend`, `.psd`, `.aseprite`) belong in `source/`, **never**
in the repo — that separation is why the repo stays small. Copy what a scene
needs into `assets/` as an engine-ready format; do not symlink from `library/`,
because Godot's importer follows the link and writes `.import` metadata that
then disagrees across projects.

## Commands

```bash
./run_tests.sh    # headless suite; exits non-zero on failure
./run.sh          # play it (extra args pass through to Godot)
gd                # open in the editor at the pinned version (toolkit wrapper)
```

Both scripts import the project on first run — a fresh clone has no `.godot/`,
and without that pass every `class_name` global fails to resolve.

Direct invocation, when a wrapper will not do:

```bash
/home/rob/games/engine/current/godot --headless --path . --script <script.gd>
/home/rob/games/engine/current/godot --headless --editor --quit --path .   # import only
```

## Non-negotiables

- **Static typing everywhere.** Parameters, returns, and locals (`:=` counts).
  Typed collections: `Array[Player]`, `Dictionary[int, int]`.
- **Logic separate from presentation.** Anything that can be a plain
  `RefCounted` should be, so it is testable without a scene tree. Nodes read
  that state and draw it.
- **Composition over inheritance.** Components attach to actors. Do not grow a
  base-class hierarchy.
- **Signals outward, never reach upward.** A component must not call
  `get_parent()` to find collaborators.
- **Data in `Resource` files**, not constants scattered through scripts.
- **Never read the `Input` singleton outside `PlayerInputSource`.** Gameplay
  takes an [InputSource] and asks it for intent. That is what lets an enemy run
  the player's movement code, a test drive a character with no keyboard, and a
  server eventually receive intent from a client.
- **One responsibility per script**, under ~300 lines where practical.
- **Every feature testable in isolation.** New system, new suite in `tests/`.

## Before you finish

Run `./run_tests.sh`. It must exit 0. If a change is visual, **actually look at
it** — render a frame and inspect the image rather than assuming.

## Traps specific to this project

- **`class_name` globals only resolve after an import pass.** They live in
  `.godot/global_script_class_cache.cfg`. A fresh clone has no cache, and — the
  one that actually bites — a cache older than a script you just added does not
  know its `class_name`, failing as `Identifier "Foo" not declared`. The
  wrappers re-import whenever any `.gd` is newer than the cache, so prefer them
  over invoking Godot directly.
- **Test suites run on the first processed frame, not `_initialize`.** Nodes
  added to `root` before the tree is live never enter it, so `_ready` never
  fires and scene tests silently inspect an unbuilt node. See
  `tests/framework/test_runner.gd`.
- **`Transform3D(...)` literals in `.tscn` are basis ROWS, not axis columns.**
  Hand-writing one from computed axis vectors yields a transposed (rolled)
  transform — a diagonal horizon is the tell. To author a scene without the
  editor, build the nodes in a throwaway script, set transforms with
  `looking_at()`, and let `ResourceSaver.save()` serialize it: correct by
  construction.
- **Godot treats CLOCKWISE winding as front-facing.** A procedurally built
  surface wound the other way is back-face culled and simply invisible, which
  reads as "the mesh failed to build" rather than as a winding bug. Assert on
  `ARRAY_NORMAL` directions in a test — see `test_the_ground_faces_upwards`.
- **`HeightMapShape3D` samples are always one unit apart** and it has no
  spacing property. Any mesh resolution other than one vertex per metre forces
  a scaled `CollisionShape3D`, which scales the heights too and silently
  desynchronises collision from what you can see. Keep spacing at 1.
- **`--headless` does not render.** `root.get_texture()` returns null and you
  get `ERROR: Parameter "t" is null`. Omit the flag when capturing a frame;
  keep it for logic-only runs like the test suite.
- **A launched game dies when its spawning shell exits.** Use
  `setsid ./run.sh &` from a shell that will close. Godot reports this as a
  clean exit 0, not an error, so it looks like the app simply quit.

### Rendering a frame to inspect

```gdscript
extends SceneTree
var _frames: int = 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		root.add_child(load("res://scenes/main.tscn").instantiate())
		return false
	if _frames < 30:   # let the renderer settle
		return false
	await process_frame
	root.get_texture().get_image().save_png("/tmp/frame.png")
	return true
```

```bash
/home/rob/games/engine/current/godot --path . --resolution 1280x720 --script _shot.gd
```

Delete the throwaway script afterwards; it is a tool, not part of the project.

When checking camera framing or anything scale-dependent, add temporary 1.8 m
boxes **in the harness only** — an empty landscape gives the eye nothing to
judge against, and a frame of featureless green looks identical whether the
framing is right or badly wrong.

## Scope discipline

The vertical slice is deliberately narrow: no crafting, no inventory, no
combat, no enemies, no UI beyond a debug overlay. Build the feature asked for
and stop. Do not add the "obvious next thing" unprompted.

Work one feature at a time: explain the design, implement only that feature,
say where every file belongs, then wait.
