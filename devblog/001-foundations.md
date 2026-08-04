# 001 — Foundations

*2026-08-03 · commits `8fba943`, `036ad98`, `5c15216`*

Three commits, no gameplay. This post covers everything that had to be decided
before the first feature could sensibly be written, and why each decision went
the way it did.

## What this is meant to become

A 3D survival game in Godot 4, fixed top-down/isometric camera in the style of
V Rising or Diablo, but with the focus on **survival rather than loot**. It is
meant to last years, not weeks.

That single sentence — "meant to last years" — is responsible for almost every
decision below. A project you expect to abandon in a month should be built
completely differently from one you expect to still be extending in 2029. The
priorities, in the order they break ties:

1. Clean, maintainable architecture
2. Data-driven systems
3. High performance
4. Multiplayer-friendly architecture — authoritative server later, single-player now
5. AI-assisted development: an agent should be able to understand and modify this easily
6. Minimal technical debt

Explicitly **not** a goal: cleverness.

Priority 5 is the unusual one and it shapes the others more than it looks. If an
agent is going to be reading this codebase cold, then conventions have to be
written down, structure has to be predictable, and the reasoning behind a
decision has to live next to the decision. A human can hold "we do it this way
because of that bug in 2026" in their head. Nothing else can. That is why
`CLAUDE.md` reads like a list of grievances, and why this folder now exists.

## The tree: why the repo stays small

The repo is not the project. It sits inside a managed tree:

| What | Where |
|---|---|
| Repo | `<games-root>/projects/survival-poc` |
| Engine binary | `<games-root>/engine/<version>/godot` |
| Art/audio masters | `<games-root>/source/survival-poc` — **not in git** |
| Builds | `<games-root>/exports/survival-poc` — **not in git** |
| Shared asset library | `<games-root>/library` — **not in git** |
| Toolkit | `<games-root>/toolkit` |

The rule that matters: **authoring files never enter the repo.** `.blend`,
`.psd`, `.aseprite` live in `source/`. What the game needs is copied into
`assets/` as an engine-ready format. `.gitignore` lists the authoring extensions
as a backstop in case one gets copied in by accident.

This is the difference between a repo you can clone in three seconds in year
three and one you cannot. Git stores every version of every binary forever; a
50 MB `.blend` saved two hundred times is 10 GB of history that no one can ever
delete without rewriting every hash in the project.

The related trap, learned the expensive way elsewhere: **do not symlink assets
in from a shared library.** Godot's importer follows the link and writes
`.import` metadata beside the original, which then disagrees with every other
project pointing at the same file. Copy. Disk is cheap; a corrupted shared
library is not.

## Pinning the engine, and meaning it

`.godot-version` contains `4.7.1`. This is not a suggestion, and the wrappers
(`run.sh`, `run_tests.sh`, the toolkit's `gd`) read the pin rather than
launching whatever `godot` happens to be on `PATH` — there may not even be one.

The reason is specific and one-way: **opening a project with a newer Godot
rewrites scenes and resources in place, and the rewrite is not reversible.**
There is no "open read-only". A stray double-click from a newer editor is a
migration you did not ask for, discovered when a diff shows every `.tscn` in the
project has changed.

Version in this session: `4.7.1.stable.official.a13da4feb`.

## GDScript only

No C#, no .NET build step, no third-party addons.

The addon decision is the one worth defending, because it costs something
immediately — see the next section. Every addon is a dependency on someone
else's upgrade schedule. When Godot 5 lands, a project with six addons upgrades
when the *slowest* of those six upgrades, which in practice means it does not
upgrade. For something intended to run for years across major engine versions,
that trade is not worth it for convenience.

The exception it would be worth breaking for: something genuinely enormous that
we would otherwise write badly ourselves. A test framework is not that.

## Rolling a test runner instead of installing one

Godot ships no test framework. The usual answers are GUT and GdUnit4, both good,
both addons — so per the rule above, neither.

What replaced them is about 250 lines in `tests/framework/`:

- `test_case.gd` — subclass it, name methods `test_*`, assert. `before_each` /
  `after_each` for fixtures. Assertions record failures rather than halting, so
  one bad assert does not hide the four after it.
- `test_runner.gd` — discovers every `res://tests/test_*.gd`, finds `test_*`
  methods by reflection, runs them, and exits non-zero if anything failed.

Two details that were not obvious and are the reason this is worth writing about
at all.

**A suite that cannot load must fail, not vanish.** A script with a parse error
still `load()`s successfully in Godot; it just cannot be instantiated. The naive
runner skips it and reports "all passing" while an entire suite silently does
not exist. Broken suites are therefore counted separately and force a non-zero
exit. A test that never runs is a failure, not an absence.

**Tests run on the first processed frame, not in `_initialize`.** This one cost
real time. `SceneTree._initialize` runs before the tree is live. Nodes added to
`root` at that point never enter the tree, so `_ready` never fires — and a scene
test happily inspects a node that was never built, asserts against defaults, and
passes. The suite runs from `_process` instead, on the first frame, when the
tree is real.

## A test that guards the folder structure

`tests/test_project_structure.gd` asserts every required directory exists.

This sounds like bureaucracy and is not. The folder hierarchy is part of the
architecture — systems are expected to live in predictable places so that a
person, or an agent, can find them without searching. And Git does not track
empty directories: a folder that was never committed and a folder that was
deleted look identical to a fresh clone. The `.gitkeep` files hold them, and the
test notices when one goes missing.

The same suite carries my favourite assertion in the project so far:

> An empty 3D scene with no camera or light renders black, which reads as a
> failed launch. Both are placeholders, but their absence is a real bug.

So the test asserts the main scene has a `Camera3D` and a `DirectionalLight3D`.
It is not testing that the game is *good*. It is testing that a black screen
means something is wrong, rather than meaning "this is what the game looks like
right now" — which is exactly the ambiguity that eats an hour.

## The rules written before the first feature

These went into `CLAUDE.md` before there was anything to apply them to, which is
the only time you can write rules honestly — nothing exists yet to grandfather
in:

- **Static typing everywhere**, including typed collections.
- **Logic separate from presentation.** Anything that can be a plain
  `RefCounted` should be, so it is testable without a scene tree.
- **Composition over inheritance.** Components attach to actors; no base-class
  hierarchy.
- **Signals outward, never reach upward.** A component must not call
  `get_parent()` to find a collaborator.
- **Data in `Resource` files**, not constants scattered through scripts.
- **One responsibility per script**, under ~300 lines where practical.
- **Every feature testable in isolation.** New system, new suite.

The one that has paid for itself most often is the third and fourth together.
Because no component looks up its collaborators, every one of them can be
constructed in a test with fakes and driven directly, and something has to
introduce them explicitly — which is how `WorldRoot`, the composition root,
came to exist a few features later.

## Where this left things

An empty green world with a camera, a light, and a test suite that passed with
three tests in it. Not much to look at. But at that point, adding terrain was a
matter of writing terrain — not of deciding where terrain scripts live, how they
get tested, which engine version compiles them, or whether the mesh source file
belongs in the repo.

That is the whole return on a setup pass: the second feature is cheaper than the
first, instead of more expensive.

**Next:** [002 — Terrain](002-terrain.md), where the ground gets a shape, and
`HeightMapShape3D` turns out to have an opinion about vertex spacing that is not
negotiable.
