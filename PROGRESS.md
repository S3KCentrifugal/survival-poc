# Project status

Living record of what this project is, what has been built, and what comes
next. Read this first when picking the work back up.

Last updated after **Feature 5 — Movement** (`d8dae5f`).

## What this is

A commercial-quality 3D survival game in Godot 4, intended to last several
years. Fixed top-down/isometric camera in the style of V Rising or Diablo, but
the gameplay focus is **survival, not loot**.

Godot 4.7.1, GDScript only, Git. No C#, no .NET build step, no third-party
addons.

## Priorities

In the order they break ties:

1. Clean, maintainable architecture
2. Data-driven systems
3. High performance
4. Multiplayer-friendly architecture — authoritative server later, single-player now
5. AI-assisted development: an agent should be able to understand and modify this easily
6. Minimal technical debt

Explicitly **not** a goal: cleverness. Build small, reusable systems that can
grow. Do not over-engineer.

## Coding standards

- Scripts under ~300 lines where practical, one responsibility each
- Composition over inheritance
- No circular dependencies
- No singleton abuse
- `Resource` files for configurable data
- Signals instead of tight coupling
- Gameplay logic separate from presentation
- Every feature testable in isolation
- Static typing everywhere, including typed collections

`CLAUDE.md` holds the enforceable version of this plus the engine traps.

## Working process

**One feature at a time.** For each:

1. Explain the design
2. Implement only that feature
3. Explain where every file belongs
4. Stop and wait

Do not generate the whole game at once, and do not build the "obvious next
thing" unprompted.

## Scope of the current vertical slice

**In:** empty 3D world, terrain, player, fixed isometric camera, WASD movement,
mouse rotation, sprint, collision, basic animation state machine, day/night
placeholder, health component, stamina component.

**Out, deliberately:** crafting, inventory, combat, enemies, and any UI beyond a
simple debug overlay.

## Architecture pattern

Every system so far follows the same three layers, and new ones should:

| Layer | Type | Role |
|---|---|---|
| Config | `Resource` | Exported tuning data, edited as `.tres` |
| Logic | `RefCounted` | Pure maths/state, no scene tree, fully unit-tested |
| Component | `Node` | Applies the logic to the world |

Components never look up their collaborators. They take explicit `@export`
references, and **`WorldRoot`** (`scripts/world/world_root.gd`) is the
composition root that introduces them — it spawns the player on the terrain,
builds the input source from the camera, and tells the camera what to follow.

The reusable-component set the brief calls for: health, stamina, movement,
interaction, save identifiers, animation controller, camera controller, input
abstraction. Three of those exist so far.

## Progress

| # | Feature | Status | Commit |
|---|---|---|---|
| 1 | Bootstrap: folders, test harness, empty 3D world | done | `036ad98` |
| 2 | Terrain: noise heightfield, mesh, collision | done | `0984fb4` |
| 3 | Fixed isometric camera controller | done | `80a4076` |
| 4 | Input abstraction | done | `2e83539` |
| 5 | Movement: WASD, cursor facing, collision | done | `d8dae5f` |
| 6 | Health and stamina components | **next** | |
| 7 | Sprint (movement × stamina) | | |
| 8 | Animation controller | | |
| 9 | Day/night placeholder | | |
| 10 | Debug overlay | | |
| 11 | Save identifiers | | |

**106 tests passing** across 10 suites. `./run_tests.sh` exits non-zero on
failure.

The slice is playable now: `./run.sh`, walk with WASD, the character faces the
cursor.

### 1. Bootstrap

Folder hierarchy per the brief (lowercase, matching Godot's style guide and the
surrounding toolkit). Reflection-based test runner in `tests/framework/` —
subclass `TestCase`, name methods `test_*`. `tests/test_project_structure.gd`
guards the hierarchy so a directory cannot silently vanish.

### 2. Terrain

`TerrainConfig` → `Heightfield` → `Terrain`. `Heightfield` is node-free and
answers "how high is the ground here?", which movement, spawning and AI all
need without touching the terrain node.

**Vertex spacing is pinned at 1 metre.** `HeightMapShape3D` samples are always
one unit apart and it has no spacing property, so any other resolution forces a
scaled collision shape — which scales the heights too and silently
desynchronises collision from the visible mesh. Resolution is therefore derived
(`size + 1`) and detail comes from noise.

Currently a single 64×64m tile centred on the origin. Not streaming; chunking
later means many `Heightfield`s rather than a rewrite.

### 3. Camera

`CameraConfig` → `CameraFraming` → `CameraController`. Fixed yaw — the camera
never rotates with the target, which is what makes an isometric view readable.

Focus smoothing uses `1 - exp(-speed * delta)`, not `speed * delta`, so it
behaves identically at 30 and 144 fps. Pitch is clamped below 90° because
`looking_at` is degenerate when forward parallels up.

### 4. Input abstraction

`InputState` (one tick of intent) ← `InputSource` ← `PlayerInputSource` /
`ScriptedInputSource`.

**Nothing outside `PlayerInputSource` may read the `Input` singleton.** That is
what lets an enemy run the player's movement code, a test drive a character with
no keyboard, and a server eventually receive intent from a client.

`InputState.move` is already world-space — the camera-relative rotation happens
here, so a server never needs to know about a client's camera. Aim resolves
against a horizontal plane rather than a terrain raycast, because a raycast
makes the cursor's world point jump as it crosses hills.

WASD is bound by **physical** keycode, so it survives AZERTY and Dvorak.

### 5. Movement

`MovementConfig` → `MovementSolver` → `MovementComponent`, driving a
`CharacterBody3D`.

Turning uses `angle_difference` so it always takes the short way round.
Acceleration is linear and therefore exactly frame-rate independent.
Deceleration is higher than acceleration, which is most of what makes movement
feel deliberate. Facing prefers the cursor over the walk direction.

`InputState.sprint` is populated but **deliberately unconsumed** — sprint lands
in feature 7 where stamina can gate it. Wiring a speed multiplier now would
mean building it twice.

## Open items

Nothing here is blocking; all are judgement calls left to the owner.

- **The name.** `survival-poc` says throwaway; the brief says multi-year and
  commercial-quality. Cheaper to change now than after more history, the
  GitHub URL, and the toolkit manifest entry accumulate.
- **Asset sync is not configured.** `SYNC_REMOTE` is unset in
  `../../toolkit/machine.local.sh` (the file does not exist). `source/` and
  `library/` are deliberately excluded from git, so art masters would have **no
  backup path**. Harmless while both are empty; wire it before the first real
  `.blend` lands.
- **Camera distance** (18m in `resources/camera/default_camera.tres`) frames the
  character small. ~12–14m reads better. Art call, left alone.
- **Terrain noise frequency** (0.015) gives ~66m features on a 64m tile, so it
  reads nearly flat at gameplay distance. Raise toward 0.04 for local relief.

## Environment notes

Engine, paths, exact invocations and the accumulated engine traps live in
`CLAUDE.md`. The traps are worth reading before touching a `.tscn` or writing a
test — each one cost real time to find:

- `class_name` globals need an import pass; the wrappers detect a stale cache
- Test suites must run on the first live frame, not `_initialize`
- `Transform3D` literals in `.tscn` are basis **rows**, not axis columns
- Exported node references need `node_paths=PackedStringArray(...)` or they are
  silently null
- Idle frames and physics ticks are different clocks
- Godot treats **clockwise** winding as front-facing
- `--headless` cannot render a frame
