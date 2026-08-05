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
| 11 | Save identifiers | done | `bdb7a1d` |
| 12 | Player character (placeholder rig) | done | `460bb9a` |
| 13 | Facing mode: face your travel, not the cursor | done | `6367ad9` |
| 14 | Prototype level: a base to walk out of | done | `e7ddd7d` |
| 15 | Dev console | done | `41647fc` |
| 16 | Third-person camera: mouse look, wheel zoom | done | `a9ebd09` |
| 17 | Jump | done | `4b13064` |
| 18 | Escape menu and graphics settings | done | `6ec1535` |
| 19 | Punch on left click | done | |

**The planned slice is complete.** 455 tests passing across 34 suites.
`./run_tests.sh` exits non-zero on failure.

Playable now: `./run.sh`. You start in a room inside a two-room base, seen from
over the character's shoulder. WASD moves relative to the camera, the mouse
turns it, the wheel zooms. Shift sprints until the bar runs out. Go through the
internal doorway, out of the building and across to the tower. F3 for the
readout, backtick for the console, Escape for the menu. Space jumps, left
click punches.

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
feel deliberate. Facing originally preferred the cursor over the walk direction;
feature 13 made that a config choice and flipped the player to face their travel.

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

### 12. Player character

The capsule is gone. The player is now a CC0 rigged robot
(`assets/characters/godot_robot/`, provenance in the README beside it), 1.74 m
tall, which is close enough to the 1.8 m collision capsule that nothing needed
scaling.

**No script changed.** The whole swap was one scene edit and four strings in
`resources/animation/player_animation.tres`. That is the return on feature 8
keeping the state machine ignorant of rigs — the rig came from a platformer, so
its base locomotion clip is called `Run` and its fast one `Sprint`, and our walk
and run point at those without anyone renaming anything.

A new test asserts every clip the config names actually exists in the rig.
Nothing but a string connects the `.tres` to the `.glb`, and a typo there does
not error — the character just stands still while sliding along the ground,
which reads as a physics bug and is not one.

Two things this turned up, both now in `CLAUDE.md`: Godot's glTF importer
**consumes a `-loop` suffix** from clip names, so `Idle-loop` in the file is
`Idle` in the engine; and `StringName` comparison sorts by interned pointer
rather than by text, which had left a save-registry test passing on luck since
feature 11.

The character also settles the camera argument. At 18 m it is a smudge — see the
open item below, which is no longer a matter of taste.

### 13. Facing mode

The character now faces the way it is running. It used to face the cursor, and
feature 5 defended that in a comment — facing the cursor while strafing is what
a top-down ARPG does *in combat*. There is no combat, so what it actually did
was drag the character's head around while you ran.

`MovementConfig.facing_mode` is a `FacingMode` enum, `MOVEMENT` or `CURSOR`,
rather than a deletion. Both behaviours are legitimate for this genre and both
stay tested; combat may well want `CURSOR` on some actors later without every
actor changing with it.

`InputState.has_aim` / `aim_point` are now **populated but unconsumed** — the
same status `sprint` had between features 4 and 7. Interaction targeting and any
future combat will want them, and resolving the cursor against a plane costs
nothing.

One trap came out of it: `load()` hands every caller **the same cached
`Resource` instance**, so a test that flipped `facing_mode` on the player's
`.tres` changed it for every other test in the run. Tests `duplicate()` the
config first, and a test now asserts that switching one actor does not move
anyone else.

Verified by running all four compass directions with the cursor pinned to the
north the whole time: facing matched travel to 0.0° every time, where the old
behaviour would have faced north four times out of four.

### 14. Prototype level

A two-room base you start inside, a doorway between the rooms, a doorway out,
and a tower to walk to. `StructureConfig` → `WallBuilder` → `Structure`, plus
`PrototypeLevel` holding the layout.

**A doorway is a subtraction, and subtraction is where the off-by-one lives.**
`WallBuilder` turns a wall run plus its openings into solid boxes — piers either
side, a lintel above — and is the only part of this with real logic in it, so it
carries most of the tests. A gap half a metre out is a door you cannot walk
through or a wall with daylight under it, and neither is visible from thirty
metres up.

**The ground had to be levelled first.** Terrain noise moves **3.4 m** across a
building-sized footprint; a structure on that either floats at one corner or
buries itself at another, and the resulting step at the doorway is not something
a character can climb. `Heightfield.flatten()` cuts a pad, easing back to real
terrain over 5 m so it does not read as a plateau stamped into the hillside.
Both pads use one height, because levelling them separately puts a step between
them that then needs a ramp or a cliff.

`Terrain.present()` is the new seam: it shows a field without regenerating it,
so mesh and collision are rebuilt together from the same data and cannot
disagree. A crater will want the same door.

The floor slab stands **5 cm** above the levelled ground. Not zero, because two
coplanar surfaces fight over the same pixels; small enough that the capsule
rolls over the threshold instead of being stopped by it. Confirmed by walking
the character through, not by reasoning about it.

**The layout is constants in a script, not data.** A deliberate limit: walls,
openings and pads all have tested logic behind them, but *where the walls go* is
still code. A level format is its own job, and inventing one to describe a
single prototype building would be guessing at what the second building needs.

### 15. Dev console

Backtick opens it. `DevConsole` is the registry, parser and history and knows
nothing about survival games; `GameCommands` holds what the commands do;
`DevConsoleUI` owns the panel and the keys. Every command can therefore be run
in a test rather than by typing it and watching — which is the workflow a dev
console exists to replace.

Commands: `help`, `clear`, `where`, `tp`, `time`, `heal`, `hurt`, `kill`,
`stamina`, `speed`, `quit`.

**It pauses the world while open.** Without that the player keeps walking as you
type, because `PlayerInputSource` reads the `Input` singleton and a focused text
box does nothing to that. The toggle is handled in `_input` rather than
`_unhandled_key_input` for the same family of reason: the text box has focus and
would otherwise type the key meant to close it.

Two bugs came out of this, both now traps in `CLAUDE.md`, both from one
asymmetry in `Callable`:

- It stores an object **id**, so the `GameCommands` built as a local was freed
  the moment `install()` returned and every command silently became invalid —
  the console answered everything with "registered but does nothing".
- `bind()` stores arguments as **strong references**, so `_help.bind(console)`
  made `console → command → callable → console`, a cycle GDScript never
  collects. Every mounted world leaked one. `help` is a built-in of `DevConsole`
  now, which is where it belonged anyway.

The second was found by the test suite's exit warning, not by a failing
assertion. `./run_tests.sh` is now clean of leak warnings, which makes it worth
watching as a signal.

### 16. Third-person camera

The fixed isometric camera is gone. The camera now sits behind and above the
character at **5 m and 20°**, turns with the mouse, and zooms on the wheel
between 1.5 m and 14 m. `prefabs/isometric_camera.tscn` is renamed
`third_person_camera.tscn` — feature 3's write-up above describes what it was,
not what it is.

`CameraConfig` → `CameraOrbit` → `CameraFraming` → `CameraController`.
`CameraOrbit` is new and holds the state a fixed camera never needed: yaw and
pitch the player turns by hand, and a distance the wheel changes. `CameraFraming`
now takes angles as arguments instead of reading them off the config, which is
what made the fixed camera fixed.

**Yaw is not automatic.** A camera that swings itself behind the character, with
movement relative to that camera, chases its own tail: hold a sideways key, the
character turns, the camera follows, the key now means a different direction,
and you walk in circles. Mouse control is what every third-person game uses and
is the reason it works.

`InputState` deliberately does **not** carry look and zoom.
`InputSource.consume_look()` / `consume_zoom()` drain them instead, because
`move` and `sprint` are *states* two components can read in the same tick
without harm, while look and zoom are *deltas* — read one twice and the camera
turns twice for one flick of the wrist. Movement and the camera share one
source, so this distinction is load-bearing rather than tidy.

The camera pulls in when something solid is between it and the player. Not
optional: the player starts indoors, and 5 m behind them is 5 m inside a wall.

Mouse capture is on by default (`CameraConfig.mouse_look`), with Escape
releasing the cursor, a click taking it back, and the dev console releasing it
while open. `HOLD_RIGHT` is the fallback if capture misbehaves.

**It also found a bug in feature 12.** The character model was facing backwards
the whole time — the mesh is authored facing +Z, and the top-down camera could
never show it. Post 016 has the correction; post 012 stands as written.

### 17. Jump

Space jumps 1.1 m. `MovementConfig.jump_height` is a **height, not a launch
speed**: height is the thing anyone needs to know — whether you clear that ledge
— and `MovementSolver.jump_velocity()` derives the speed from it and gravity, so
retuning gravity does not silently change what the character can climb.

`InputState.jump` is *held*, like `sprint`, not "just pressed". The rising edge
is spotted by `MovementComponent`, which keeps `InputState` a description of
what the player is doing rather than a list of events — the same reasoning that
kept look and zoom out of it in feature 16, arriving at the opposite answer
because jump genuinely is a held key. Holding space jumps once; you have to
release to jump again.

The launch is written **after** velocity is solved and **before**
`move_and_slide`, or gravity cancels it in the tick it happens. There is no air
control and no double jump: those are decisions this game has not made, and
defaulting to "yes" would make them for it.

The animation state machine gained `JUMP`, chosen by vertical speed, with a
0.5 m/s threshold rather than zero — the velocity crosses zero at the top of the
arc, and a zero threshold flips to the falling clip for one frame on the way up.

One rig lesson: **a clip name tells you nothing about its length.** The robot's
`Jump` is a 0.04 second single-frame pose that ends in two frames and leaves the
`AnimationPlayer` reporting nothing playing. `Jump2` is 0.21 s of actual launch
motion, and is what the config names.

### 18. Escape menu and settings

Escape opens Resume / Settings / Quit. Settings covers display mode (windowed,
exclusive fullscreen, borderless fullscreen), resolution, monitor, v-sync, frame
cap, anti-aliasing, render scale, master volume, look sensitivity and invert
look. **Everything listed does something** — nothing is a placeholder for a
system that does not exist yet, which is why there is one volume slider rather
than the usual three.

Four pieces, so the part that cannot be tested is as small as possible:

| | |
|---|---|
| `GameSettings` | plain data plus the rules about what is valid |
| `SettingsStore` | reads and writes `user://settings.cfg` |
| `SettingsMenu` / `PauseMenu` | show settings, collect them, say what was pressed |
| `SettingsApplier` | the only file that touches a window, renderer or audio bus |

The validation rules are not defensive padding — the settings file is the one
piece of state a player can reach with a text editor. A monitor index from a
two-screen desk, opened on a laptop, falls back to the first screen rather than
opening off-screen. An unsupported frame cap **rounds down** to one we offer
rather than being honoured. A corrupt file gives defaults, a truncated one loses
a single setting rather than all of them, and keys from a later build are
ignored.

**Escape used to release the mouse.** The menu owns that key now and releases the
cursor as part of opening — one gesture doing one thing instead of two. Pausing,
releasing the cursor and showing the panel happen together, because any one
without the others is a bug you can feel. The dev console takes its own Escape
first (it uses `_input`, the menu uses `_unhandled_input`), so the key closes a
console before it reaches the menu; inside the settings panel Escape steps back
rather than throwing the panel away.

Settings rows are built from a list in code rather than laid out in the scene. A
dozen label-and-control pairs hand-written into a `.tscn` is four hundred lines
that have to be edited in lockstep with `GameSettings`.

Two things to know when running the suite:

- `./run_tests.sh` prints **one** `ConfigFile parse error` line, from the test
  that proves a corrupt settings file cannot stop the game starting. Godot's
  parser logs before returning its error code and has no quiet variant. A second
  error line means something is actually wrong.
- `PauseMenu.settings_path` is overridable so tests write somewhere harmless. It
  is not: the suite rewrote the real settings file once before that was noticed.

### 19. Punch

Left click throws a punch, rate-limited to one every 0.35 s.

**It hits nothing.** No hit detection, no damage, no target — that is combat,
which the brief keeps out of this slice. This is the swing: an intent, a rate
limit, and something for the animation to show. Whatever eventually deals damage
listens to `AttackComponent.attacked` rather than replacing it.

`Cooldown` is a small reusable [RefCounted] rather than a float in the
component, because eating, crafting and anything else unspammable will want the
same thing, and getting the frame-rate independence and the edges right once
beats five slightly different countdowns. `use()` checks and starts the wait in
one call, so nothing can ask permission, act, and forget to say so.

The cooldown doubles as how long the punch shows. The rig's swing is 1.21 s; at
0.35 s that is deliberately cut into a jab, because a punch you have to wait out
is not one you would click twice.

Two seams worth knowing:

- **Punching beats locomotion** in the animation state machine. Crude —
  punching while running replaces the run rather than blending over it — but a
  state machine cannot express two things at once, and an upper-body overlay
  needs an `AnimationTree`.
- **The click that recaptures the cursor does not punch.** After the menu or an
  alt-tab, the first click is aimed at the window, not at whatever is in front
  of you. `PlayerInputSource` swallows attack until the button comes back up.

Holding the button throws one punch, not one per cooldown — releasing arms the
next, the same rule as jump. Auto-repeat while held would be a one-line change
in `AttackComponent.step`.

## What is not built

The slice is done, so this is the honest list of what a survival game still
needs and this repo does not have:

- **Interaction** — the one component from the brief's list that is missing. It
  was not in the numbered plan, and nothing yet has anything to interact with.
- **A save system.** Objects can be addressed; nothing serialises them.
- **Terrain streaming.** One 64 m tile. Chunking means many `Heightfield`s
  rather than a rewrite, which was the point of keeping it node-free.
- **A level format.** The prototype layout is constants in
  `scripts/world/prototype_level.gd`. The second building is what should decide
  what a level resource needs to say.
- **Roofs, doors that open, windows, stairs.** Buildings are open-topped boxes
  with holes in them, which is all a top-down camera needs to see into.
- **A character of our own.** The player is a CC0 robot standing in for one. It
  animates and it is the right height; it is not the art direction.
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
- **Terrain noise frequency** (0.015) gives ~66m features on a 64m tile. This
  was raised when the camera was 18 m up and the ground read as flat; at
  third-person distance the same terrain has 3.4 m of relief across a building
  footprint, which is plenty. **Re-judge it from the new camera before
  changing it** — the original complaint was about a view that no longer exists.

Resolved: camera distance, by feature 16 replacing the fixed 18 m isometric
camera with a 5 m third-person one.

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
