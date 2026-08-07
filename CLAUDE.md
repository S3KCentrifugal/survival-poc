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
./shots.sh check  # render the named shots, compare against tests/golden/
./build.sh        # export Linux + Windows into <games-root>/exports/
gd                # open in the editor at the pinned version (toolkit wrapper)
```

All of them take `GODOT=/path/to/godot` to override the pinned engine, which is
how CI points them at one it downloaded itself.

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

## Shipping

**`DEPLOY.md` is the reasoning and the manual steps; this is the rule.** Testers
get the game through a **Steam Playtest**, built by GitHub Actions, with GitHub
Releases as the fallback that always works.

- **`build.sh` is the build.** CI is a thin wrapper around it, so a broken build
  is fixed locally rather than by pushing commits at a YAML file.
- **One Linux x86_64 binary covers desktop Linux, Steam Deck and Steam
  Machine.** All three are Linux on x86_64; they are not separate targets.
- **The executable bit is the thing that breaks silently.** Steam preserves the
  permissions it is given, and `upload-artifact` does not preserve any. A Linux
  build without it installs perfectly and then does nothing. It is set in
  `build.sh` *and* re-set in the Steam job; do not remove either.
- **Never commit Steam credentials.** `STEAM_USERNAME`, `STEAM_CONFIG_VDF` and
  `STEAM_APP_ID` are repository secrets. `STEAM_APP_ID` is the **playtest** app,
  not the base app — they are different ids and testers only own the playtest.
- **`SetLive` stays empty in `steam/app_build.vdf`.** Promoting a build is a
  deliberate click in Steamworks, not a side effect of running a script.
- **Export template downloads are 1.2 GB.** The CI cache is not an optimisation.

## Interface

**`UI.md` is the reasoning; this is the rule.** Every guideline there names its
source — Nielsen's heuristics, WCAG 2.2 AA, the Game Accessibility Guidelines,
Fitts's law — because a guideline you cannot trace is a preference.

- **The theme owns appearance; a scene owns arrangement.** Setting
  `theme_override_colors/*`, `fonts/*`, `font_sizes/*` or `styles/*` in a
  `.tscn` is a bug and a test fails on it. `theme_override_constants/separation`
  is fine: that is layout. Need a different look — add a **type variation** to
  the theme (`Title`, `Card`, `PrimaryButton`, `HealthBar`) and ask for it by
  name.
- **Every number comes from `UiTokens`.** Spacing is the 4 px scale, type is the
  six-step scale, colour is the palette. A literal size or colour in a UI script
  is the thing that produced 84 per-node overrides across 10 scenes.
- **The theme is generated, not hand-edited.** Change `UiTokens`, then rerun
  `UiThemeBuilder.save()` and commit `resources/ui/game_theme.tres`. Editing the
  `.tres` puts a second copy of a token where nobody will look for it.
- **Contrast is measured.** 4.5:1 body, 3:1 large and interactive boundaries,
  against **every** surface a colour can appear on — the first palette here
  passed on the panel and failed on the raised surface that buttons sit on.
  `UiTokens.contrast()` exists so this is a test, not an opinion.
- **Nothing is said in colour alone.** ~4% of players cannot separate red from
  green. A disabled control says *why* in its tooltip, next to itself.
- **Disabled keeps its border.** Without one it reads as a label and nobody
  knows there was anything to enable.
- **Focus must be visible and distinct from hover**, or a keyboard player is
  lost. It is also the thing most easily broken by a palette change.
- **Modals use `ModalPanel`.** Scrim, cursor released, gameplay input
  suspended, Escape and the opening key both close. They do **not** pause —
  pausing belongs to the pause menu alone.

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
- **Suspending an input source resets every rising edge.** A suspended
  [PlayerInputSource] reports every button released, so a key held across the
  suspension reads as a *fresh press* the moment it resumes — the key that
  opened a panel reopens it the instant the panel closes, forever. Swallow
  anything still held on resume, and only the edge-triggered actions: movement
  is asked "are you held", so swallowing it strands the player until they let
  go of W.
- **`_unhandled_input` is delivered in reverse tree order.** Which node wins a
  key is decided by a line in a `.tscn` that neither script mentions — the
  pause menu sits after the panels, so Escape opened the menu *over* an open
  shop that could then never be closed. A modal panel must take its close key
  in `_input`, which runs before all of `_unhandled_input` whatever the scene
  order is. Guard on `visible` and return immediately.
- **A script error inside a test does not fail the suite** — the runner cannot
  see it, because an aborted method and a completed one look identical from
  inside. `run_tests.sh` greps its own output for `SCRIPT ERROR`, parse errors
  and leaks and fails on any of them; do not weaken that check, and do not
  trust the count at the bottom on its own.
- **Never bound a check with "whichever enum value is currently last".**
  `if kind > Kind.DESPAWN: return NONE` was correct the day it was written and
  silently dropped every message of the next kind added -- with no error,
  because ignoring an unrecognised kind is the intended behaviour. Test
  membership (`Kind.values().has(x)`) and assert over every value of the enum,
  so growing the list cannot break the check.
- **A script that fails to compile is reported at its caller.** The message is
  `Invalid call. Nonexistent function 'new' in base 'GDScript'` and it names
  the file doing `Foo.new()`, not the broken file `Foo` lives in — an
  uncompiled script still resolves as a `GDScript` object, it just has no
  `new`. The real error is a `Parse Error` further up the log. Read upward
  before believing the line number.
- **`as` raises on built-in types and returns null on objects.**
  `data as Dictionary` where `data` is a String does not give null, it aborts
  with `Invalid cast`. So a guard written to reject foreign values is itself
  the thing that crashes on one. Check `typeof(x) != TYPE_DICTIONARY` first;
  `as` is only null-safe for `Object` subclasses.
- **Caching a resource that references you back never gets collected.** An
  `ItemDefinition` holding the `PackedScene` that holds the `ItemDefinition` is
  two `RefCounted`s pointing at each other, which GDScript cannot free. It
  surfaces only as `resources still in use at exit` on a green test run.
  `ResourceLoader` has its own cache, so `load()` on demand is cheap and does
  not build the cycle. Related: a `.tres` that exports a `PackedScene` which
  ext_resources that same `.tres` is a *load-time* cycle — hold a path instead.
- **`Control.set_drag_preview()` outside a real drag leaks the preview.**
  Calling `_get_drag_data()` from a test hands the viewport a node no drag will
  ever finish and nothing will ever free. Split the payload into a plain method
  and test that; leave the preview to the mouse.
- **Sub-resources are shared between instantiations of a scene.** A
  `[sub_resource]` in a `.tscn` looks private and is not: every instance of the
  scene gets the same object unless it carries
  `resource_local_to_scene = true`. Two worlds then write to one material, and
  one world's clock recolours the other's sky. Same family as the `load()`
  cache trap, which has now caught this project four times — a `MovementConfig`
  in a test, a HUD `StyleBox`, a health bar material, and the sky. If a scene
  mutates a resource at runtime, that resource must be local to the scene or
  `duplicate()`d.
- **A component nobody attached is silent.** Composition's cost: there is no
  base class whose contract went unfulfilled, so a missing node produces no
  error, no warning, and no null — the actor simply lacks a behaviour. The
  companion had health, took damage and reached zero with no `ExplodeOnDeath`,
  and because `FollowComponent` correctly stops following when dead, the
  symptom was "it stopped moving", pointing at the wrong system entirely. When
  adding an actor, diff its scene against the nearest existing one, and assert
  in a test that each capability is *present*, not just that it works.
- **A test double must replace what the code depends on, never what the code
  does.** `test_jump.gd` overrode `consume_jump` — the method under test —
  with a copy of the rule, so nine assertions checked the copy and stayed green
  while the real rule changed. If an override contains an `if`, that `if` is
  the thing you meant to test. Push the seam down to the dependency
  (`is_grounded()`), not to the behaviour.
- **`Window.size` does not update in the frame the window mode changes.**
  Setting `mode` to a fullscreen mode and reading `size` immediately after still
  reports the size it had as a window — so anything derived from "how big is the
  screen we are about to fill" is computed for a resolution the game is no longer
  at. Nothing errors: fullscreen works, the game runs, the number is merely
  wrong. Ask the settings which surface is about to be filled and only fall back
  to the window.
- **A renderer statistic that looks stable can still be measuring nothing.**
  `viewport_get_measured_render_time_gpu()` reported the same figure to a
  hundredth of a millisecond across runs and did not move with a 36-fold change
  in pixel count — 4K read *cheaper* than 720p. Reproducibility is not validity.
  Before trusting any performance number, change the thing it claims to measure
  by an order of magnitude and check that the number follows; if it does not, the
  number is worse than nothing, because somebody will quote it.
- **`StringName` comparison sorts by interned pointer, not by text.** `<`, `>`
  and therefore `Array.sort()` return allocation order, which is stable within a
  run and changes the moment an unrelated system interns a new name — so a test
  asserting sorted output passes by luck until someone edits a different file.
  Sort with `sort_custom` through `String` when the order is meant to be
  alphabetical.

### Rendering a frame to inspect

**Use `shots.sh`. Do not write a throwaway capture script.** There is a
committed harness, and the reason it exists is that the throwaway scripts kept
being wrong in ways that produced a plausible-looking picture — see devblog 042
for the bill.

```bash
./shots.sh list                 # what shots exist
./shots.sh capture world-noon   # render one into .shots/, full size
./shots.sh check                # compare every shot against its golden
./shots.sh bless world-noon     # accept what is rendered as the new golden
```

- **A shot is a `ShotConfig` in `resources/shots/`**: camera, target, field of
  view, time of day, RNG seed, where the player stands, whether the interface is
  drawn, frames to settle, frames to count. Need a new view — add a `.tres` and
  bless it. Do not add a camera argument to the tool.
- **`check` is not in `run_tests.sh` and cannot be.** `--headless` has no
  rendering device. The suite covers the logic — `ImageDiff`, `FrameStats`,
  `RenderBudget`, `ShotConfig.problems()`, `ShotRunner.freeze()` — and
  `shots.sh` covers the pixels. Run both before a visual change lands.
- **A frame's cost is counted, never timed.** Draw calls and primitives, visible
  and shadow. No millisecond figure on this machine survived being checked: a
  36× resolution change made the renderer's own GPU timer report 4K as *cheaper*
  than 720p, and wall-clock frame time is pinned at ~20 ms by the desktop
  whatever is on screen. Do not reintroduce one.
- **The shadow pass is the larger half** — every shot measured draws three to
  four times as many primitives into the shadow map as into the frame, because
  the sun renders the whole 256-metre heightfield wherever the camera points.
  Budget it separately, and never report a cost with it omitted.
- **Goldens live in `tests/golden/` at 480 × 270** behind a `.gdignore`, so the
  importer leaves them alone and they are read through
  `ProjectSettings.globalize_path`. They are committed; they are the assertion.

When checking camera framing or anything scale-dependent, add temporary 1.8 m
boxes **in the harness only** — an empty landscape gives the eye nothing to
judge against, and a frame of featureless green looks identical whether the
framing is right or badly wrong.

### Resolution is a policy, not a default

The 3D scene is rendered at a capped resolution and the interface at native.
`RenderBudget` picks the scale from the display; `GameSettings.render_scale_auto`
is on by default and is a bug fix, not a preference. Before it, fullscreen on a
6144×3456 display rendered 21 megapixels — ten times 1080p — with nothing
anywhere objecting. Anything that changes how much the renderer is asked to draw
goes through `RenderBudget`, and the ladder is coarse on purpose so two machines
can quote comparable numbers.

## Scope discipline

The vertical slice was deliberately narrow, and the game has grown past it —
there is now combat, a settings menu, a title screen and an inventory, because
each was asked for. The rule that has not changed: **build the feature asked
for and stop.** Do not add the "obvious next thing" unprompted. An inventory
does not imply crafting; mushrooms do not imply eating them.

Work one feature at a time: explain the design, implement only that feature,
say where every file belongs, then wait.
