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
it** — render a frame and inspect the image rather than assuming. If you added a
feature or component, write its dev blog post in the same commit.

## Dev blog

`devblog/` is the narrative record: why a thing was built the way it was, what
went wrong, and what the next person needs to know. Every major feature or
component gets a post, written **in the same commit as the feature**, while the
reasoning is still in your head — not reconstructed from a diff later.

- **Markdown only.** No HTML, no other formats.
- **`NNN-slug.md`** — zero-padded three-digit sequence, kebab-case slug. Numbers
  are never reused and never renumbered, so a link to post 007 means post 007
  forever.
- Every post opens with a metadata line: the date, and the commits it covers.
- `devblog/README.md` is the index. Add the post to its table, and link the next
  post from the end of the previous one.
- Write what a reader **cannot get from the diff**: the alternative that was
  rejected, the trap that cost an afternoon, the number that turned out to be
  wrong when it was finally rendered. A post that only restates what the code
  does is not worth the file.
- **Posts are a record of a moment and are not rewritten.** When something in an
  old post turns out to be wrong, correct it in a new post; do not edit history.

Do not duplicate `PROGRESS.md`. That file is the *current* state — kept accurate
and rewritten as things change. The dev blog is the *history* — appended to and
then left alone.

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
- **Exported node references need `node_paths` in a hand-written `.tscn`.**
  `@export var body: CharacterBody3D` serialises as `body = NodePath("..")`, but
  Godot only resolves it into a node if the node declaration also lists it:
  `[node name="Movement" type="Node" parent="." node_paths=PackedStringArray("body")]`.
  Without it the property is silently null at runtime — no error, the component
  just does nothing. The editor writes this automatically; you must not forget it.
- **Idle frames and physics ticks are not the same clock.** Counting
  `_process` calls to time a test is wrong — headless runs idle frames
  unbounded while physics stays at 60 Hz, so a "120 frame" wait can be any
  amount of simulated time. Use `Engine.get_physics_frames()`.
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
- **The glTF importer eats a `-loop` suffix on animation names.** A clip
  authored as `Idle-loop` arrives in the engine as `Idle`, with its loop mode
  set — the suffix is an instruction to the importer, not part of the name.
  Read the names off the imported `AnimationPlayer`, never off the source file.
  A clip name that does not exist is not an error: the character simply stands
  still while sliding along the ground, which reads as a physics bug.
- **A `Callable` does not keep its object alive, but a bound argument does.**
  Two failures from one asymmetry. `Callable` stores an object *id*, so a
  `RefCounted` whose methods you registered somewhere is freed the moment your
  last reference goes out of scope — and every callable into it silently turns
  invalid rather than erroring. Meanwhile `bind()` stores its arguments as
  Variants, which *are* strong references, so binding an object into a callable
  it is reachable from makes a cycle GDScript never collects. Hold the owner in
  a member; do not bind a collection into the things it collects.
- **Godot installs an `OfflineMultiplayerPeer` by default.** In single-player
  `multiplayer_peer` is not null and `has_multiplayer_peer()` returns true, so
  a "is anyone connected?" check written either way is always true and never
  fires. Test `multiplayer_peer is OfflineMultiplayerPeer` instead. The offline
  peer reports id 1 and `is_server() == true`, which is correct for authority
  questions and wrong for connectivity ones.
- **Navmesh bakes round `agent_radius` up to whole cells, silently.** Ask for
  0.55 with 0.25 m cells and you get 0.75, eroded from every surface -- which
  can close a doorway entirely and leave the inside of a building an island
  nothing can path out of. The failure looks exactly like a working agent that
  chose not to go that way: valid map, reachable nearby targets, confident
  straight-line steering, no error. Godot warns, so do not filter navigation
  warnings; fix the cell-size mismatch that makes them noisy instead.
- **`Vector2`/`Vector3` hold 32-bit floats, so trig on them is 32-bit.**
  `Vector2(0, -1).angle_to(Vector2(0, 1))` returns `3.14159274`, which is
  *larger* than double-precision `PI` — so `angle <= PI` is false and a
  180-degree half-arc misses the thing directly behind. Compare angles with a
  small tolerance, never exactly. The symptom is a check that works everywhere
  except at the boundary, which is exactly where the test is.
- **`StringName` comparison sorts by interned pointer, not by text.** `<`, `>`
  and therefore `Array.sort()` return allocation order, which is stable within a
  run and changes the moment an unrelated system interns a new name — so a test
  asserting sorted output passes by luck until someone edits a different file.
  Sort with `sort_custom` through `String` when the order is meant to be
  alphabetical.

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
