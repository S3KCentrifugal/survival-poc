# survival-poc

A 3D survival game in Godot 4, with a fixed isometric camera in the style of
V Rising or Diablo. Survival-focused rather than loot-focused.

**[PROGRESS.md](PROGRESS.md) is the status document** — project goals, what is
built, the decisions behind each system, and what comes next. Start there.

```bash
./run.sh        # play it
./run_tests.sh  # headless test suite
gd              # open in the editor (pinned version, see .godot-version)
```

Both scripts resolve Godot from `.godot-version` and import the project on
first run, so a fresh clone needs no setup step.

## Environment

**Godot 4.7.1 stable**, GDScript only. The version is pinned in
`.godot-version` — opening the project with a newer Godot rewrites scenes and
resources irreversibly, so launch through the scripts above rather than a
`godot` on `PATH`.

The repo sits inside a managed tree (`games-toolkit`), which keeps three heavy
things out of git: the regenerable `.godot/` cache, builds, and art masters.

| What | Where |
|---|---|
| Engine | `../../engine/4.7.1/godot` (`../../engine/current` → default) |
| Art/audio masters | `../../source/survival-poc` — not in git |
| Builds | `../../exports/survival-poc` — not in git |
| Shared assets | `../../library` — not in git |
| Toolkit | `../../toolkit` |

On a fresh machine, clone [games-toolkit][toolkit] and run its `bootstrap.sh`:
it installs the pinned Godot, restores this repo, and creates the surrounding
tree. `source/` and `library/` are deliberately not in git and come from
`toolkit/sync.sh pull` instead.

[toolkit]: https://github.com/S3KCentrifugal/games-toolkit

Working on this with Claude Code? `CLAUDE.md` has the conventions, the exact
engine invocations, and the traps worth knowing before touching a `.tscn`.

## Layout

```
scenes/       assembled scenes; main.tscn is the entry point
scripts/
  components/ reusable behaviour attached to any actor (health, stamina, ...)
  systems/    cross-cutting systems (day/night, save, ...)
resources/    .tres data -- tuning values, never code
ui/           HUD and menus
characters/   player and NPC scenes
enemies/      enemy scenes
items/        item scenes and data
world/        terrain, props, level pieces
audio/        music and sfx
shaders/      .gdshader
materials/    .tres materials
effects/      particles and visual effects
prefabs/      reusable composed scenes
tests/        suites, plus the runner in tests/framework/
```

## Architecture

The rule that shapes everything else: **gameplay logic does not touch the scene
tree where it can be avoided.** Logic that can be a plain object should be one,
so it can be tested without instantiating a world.

- Components are composed onto actors, not inherited from. A `Player` and a
  future `Enemy` share a health component rather than a common base class.
- Configuration lives in `Resource` files under `resources/`, not in constants
  buried in scripts.
- Components talk outward through signals. A component never reaches up to find
  its parent's siblings.
- Scripts stay under ~300 lines and do one thing.

## Testing

Godot ships no test framework, and the usual addons (GUT, GdUnit4) would be this
project's only external dependency — so `tests/framework/` is a small
reflection-based runner instead. Subclass `TestCase`, name methods `test_*`, and
they are found automatically.

```bash
./run_tests.sh   # exits non-zero on failure
```

Two things that will bite otherwise:

- **Godot must import the project before `class_name` globals resolve.**
  `run_tests.sh` does this on a fresh clone; without it every suite fails to
  compile with "Could not find type".
- **Suites run on the first processed frame, not in `_initialize`.** Nodes added
  to `root` before the tree is live never enter it, so `_ready` never fires and
  scene-level tests would silently inspect an unbuilt node.

## Status

Vertical slice in progress. Built so far:

- [x] Project bootstrap: folder hierarchy, test harness, empty 3D world
- [x] Terrain: noise heightfield, mesh and matching collision
- [x] Fixed isometric camera controller
- [x] Input abstraction
- [x] Movement (WASD, mouse rotation, collision)
- [ ] Health and stamina components
- [ ] Sprint
- [ ] Animation controller
- [ ] Day/night placeholder
- [ ] Debug overlay
- [ ] Save identifiers

The slice is playable: run `./run.sh` and walk around with WASD. The character
faces the cursor while it moves.

`WorldRoot` on `main.tscn` is the composition root — it spawns the player on the
terrain, builds the input source from the camera, and tells the camera what to
follow. Components never look each other up; they are introduced by whoever
owns them.

Sprint is read by the input layer but not yet consumed. It lands with stamina,
which is what gates it.
