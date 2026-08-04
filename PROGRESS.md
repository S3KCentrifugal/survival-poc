# Project status

Living record of what this project is, what has been built, and what comes
next. Read this first when picking the work back up.

Last updated after **Feature 11 — Save identifiers**, which completes the
planned vertical slice.

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
placeholder, health component, stamina component, save identifiers.

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
abstraction. **All but interaction exist.**

Systems that belong to the world rather than to an actor — the day/night cycle,
the save registry — live in `scripts/systems/`. The UI's own logic lives in
`scripts/ui/`. Both follow the same three layers.

## Progress

| # | Feature | Status | Commit |
|---|---|---|---|
| 1 | Bootstrap: folders, test harness, empty 3D world | done | `036ad98` |
| 2 | Terrain: noise heightfield, mesh, collision | done | `0984fb4` |
| 3 | Fixed isometric camera controller | done | `80a4076` |
| 4 | Input abstraction | done | `2e83539` |
| 5 | Movement: WASD, cursor facing, collision | done | `d8dae5f` |
| 6 | Health and stamina components | done | `cdd214b` |
| 7 | Sprint (movement × stamina) | done | `65c6a43` |
| 8 | Animation controller | done | `c83b4e3` |
| 9 | Day/night placeholder | done | `f60aee6` |
| 10 | Debug overlay | done | `f35cc35` |
| 11 | Save identifiers | done | |

**The planned slice is complete.** 270 tests passing across 23 suites.
`./run_tests.sh` exits non-zero on failure.

Playable now: `./run.sh`. Walk with WASD, face the cursor, hold shift to sprint
until the bar runs out, watch the sun cross the sky, F3 for the readout.

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

### 6. Health and stamina

Both vitals are the same shape — a current value, a ceiling, and the rule that
neither end overshoots — so `VitalPool` owns that maths once and both components
compose one. Hunger, thirst and temperature will want the same thing.

`HealthConfig` → `VitalPool` → `HealthComponent`. Thin on purpose: no armour, no
damage types, no respawn. It refuses the impossible transitions — the dead take
no further damage, healing does not resurrect — so `died` can only fire once and
listeners need no guards of their own.

`StaminaConfig` → `Stamina` → `StaminaComponent` is where the real state lives:
a **recovery delay** and an **exhaustion lockout**. Without the delay, tapping
the sprint key is free, because the bar refills in the gaps between taps.
Without the lockout, an exhausted actor sprints one frame in every two. Intent
that cannot be granted still ticks recovery, or an actor holding the key with an
empty bar never gets going again.

The component takes intent as a **latch**: a consumer calls `request_drain()` on
every frame it wants effort and reads the answer back from `can_spend()`. The
latch is cleared as it is consumed, so letting go is simply the absence of a
request — there is no "stop" to forget. Sprint reads that in feature 7.

Both components are attached to the player and tuned by `.tres`, and nothing
consumes either yet. That is expected: they are the reusable pieces, and
gameplay wiring is its own feature.

### 7. Sprint

The seam between movement and stamina. `MovementConfig.sprint_multiplier` is a
multiplier rather than a second speed, so retuning the walk keeps the
relationship between the two — the gap is what the player feels.

`MovementComponent.stamina` is an explicit `@export`, wired in `player.tscn` and
**optional**: an actor without one sprints as long as it likes, which is what a
deer should do and what an enemy does until it is given a bar.

Two rules earn their tests. Sprinting on the spot is not sprinting — without the
movement check, holding the key while standing still drains the bar for nothing.
And the stamina node sits *after* movement in the player scene, so the cost
lands the same frame it is incurred; the latch means that if it ever did not,
the cost would land the next frame instead of being lost.

Measured in the real scene: 4.5 m/s walking, 7.65 m/s sprinting, dropping back
to a walk mid-run as the bar empties and resuming once the lockout lifts.

### 8. Animation controller

`AnimationConfig` → `AnimationStateMachine` → `AnimationComponent`. Four states:
idle, walk, run, fall.

The state machine knows nothing about rigs, clips or blending — it turns motion
into a state, and the component turns that state into whatever the actor happens
to be drawn with. That is what lets it be tested with numbers rather than with a
character model that does not exist yet.

**The thresholds are a hysteresis band, not one number used twice.** It takes
0.4 m/s to start moving and 0.15 m/s to stop. With a single threshold, an actor
drifting at exactly that speed flips state every frame and restarts the clip
over and over. A `.tres` with the two the wrong way round is capped rather than
trusted, because inverted hysteresis flickers worse than none.

Speed is horizontal only: an actor falling straight down is not walking.
`animation_player` is an optional export and is **unassigned** — the player is
still a capsule. The state machine runs anyway, which is the point: the rig
arrives later without this component changing. A clip a rig does not have is
skipped silently rather than logged sixty times a second.

Observed in the real scene: idle → walk at 0.50 m/s → run → walk on releasing
sprint → idle → fall when stepping off the tile.

### 9. Day/night placeholder

`DayNightConfig` → `DayNightCycle` → `DayNightComponent`, in `scripts/systems/`
rather than `scripts/components/`: it belongs to the world, not to an actor.

**The sun is the only thing it touches.** The scene's procedural sky already
takes its gradient from the brightest directional light, so moving that one
light moves the sky and the ambient light with it — one rotation, a whole
atmosphere, and nothing else to keep in sync.

The arc runs from due east through a *tilted* overhead axis. Passing exactly
through the zenith would leave the basis that aims the light degenerate, and
stamps midday shadows underfoot where they read as no shadow at all. A zero
day length freezes the clock rather than dividing by zero, because a frozen sun
is a far easier bug to read than a NaN one.

The basis comes from `Basis.looking_at`, never from hand-written axes — see the
`Transform3D` trap in `CLAUDE.md`. Night keeps a little cool light: pitch black
is not atmosphere, it is a bug report.

A day is 600 real seconds. `day_began` / `night_began` fire on the horizon
crossing — the hooks a survival loop wants — and jumping the clock with
`set_time_of_day` deliberately does *not* fire them.

Rendered and inspected at four times: dawn warm with long raking shadows, noon
bright and neutral with short ones, dusk the mirror of dawn, night dark and blue
but still readable.

### 10. Debug overlay

The project's only UI. `DebugReadout` (in `scripts/ui/`) formats the lines and
knows nothing about where the numbers came from, so what the panel *says* is
tested without a viewport, a font or a frame. `DebugOverlay` gathers values and
decides when to redraw.

Every watched reference is optional and a missing one prints `--`, so the panel
can be dropped into a half-built scene and still be useful. The lines are fixed:
one that disappears makes the panel jump, and you cannot tell "no stamina
component" from "I forgot to add the line". `main.tscn` wires the overlay to
what it watches, the same way every other collaborator in this project is
introduced.

**F3 toggles it**, read from the key event queue rather than the `Input`
singleton. That rule exists so gameplay intent always arrives through an
`InputSource` and can come from an AI or a network peer instead — a debug panel
is neither, and has no business in an actor's intent.

Two things learned by looking at it rather than by reasoning about it: the
readout needs a **monospace font** (`SystemFont`, falling back to the default
face), because padding labels in code is meaningless against a proportional
font and a ragged panel is much harder to scan; and bars are ASCII `[####----]`
rather than block characters, because a debug tool that renders as tofu on
someone else's machine has failed at its one job. A NaN fraction reads as empty,
since the overlay is most useful in exactly the situation that produced it.

It refreshes ten times a second, not sixty: rebuilding that string every frame
is pointless garbage for something the eye reads a few times a second.

### 11. Save identifiers

`SaveIdComponent` plus `SaveRegistry`. **Nothing here writes a save.** This is
the half that has to be right first: an object whose identity changes between
sessions cannot be reloaded into, and one that shares an identity with another
silently overwrites it.

An id comes from, in order: the one authored in the scene (the player's is
`player`); otherwise the node's tree path, taken once as it enters the tree.
For anything **spawned at runtime** neither is stable — assign
`SaveIdComponent.random_id()` at spawn and save the id with the object. A path
is not an identity for something that did not exist when the level was authored.
That rule is a convention rather than something the code can detect, which is
exactly why the duplicate check exists.

Ids are readable rather than hashed: the first thing anyone does with an
unfamiliar save file is look for something they recognise.

The registry is **built on demand, not kept up to date** — a live registry has
to be told about every spawn and every free, and the one that is never told is
the bug. Components join a group and a save pass walks it. The duplicate check
is the reason it is a class rather than a dictionary: two objects sharing an id
is not a crash, it is a save where one quietly overwrites the other, discovered
by a player a week later when their chest is empty. A test walks the assembled
world and asserts there are none.

## What is not built

The slice is done, so this is the honest list of what a survival game still
needs and this repo does not have:

- **Interaction** — the one component from the brief's list that is missing. It
  was not in the numbered plan, and nothing yet has anything to interact with.
- **A save system.** Objects can be addressed; nothing serialises them.
- **Terrain streaming.** One 64 m tile. Chunking means many `Heightfield`s
  rather than a rewrite, which was the point of keeping it node-free.
- **A rig.** The animation state machine drives nothing, by design.
- Crafting, inventory, combat, enemies, and real UI — all deliberately out of
  scope for the slice.

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
