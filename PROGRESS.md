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
**`MULTIPLAYER.md`** holds the networking architecture: the authority model, the
replication plan, the path to an MMO, and the order the work should happen in.

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
| 19 | Punch on left click | done | `eeaef61` |
| 20 | Wandering characters | done | `a3b1062` |
| 21 | Punches connect; wanderers react | done | `c222edb` |
| 22 | Health regen, player HUD, and death by explosion | done | `669a517` |
| 23 | Respawning, damage numbers, health bars over heads | done | `d8f8f4c` |
| 24 | Companion that follows you, with pathfinding | done | `563e75b` |
| 25 | Multiplayer foundation: session and authority seam | done | `bf555d5` |

**The planned slice is complete.** 611 tests passing across 45 suites.
`./run_tests.sh` exits non-zero on failure.

Playable now: `./run.sh`. You start in a room inside a two-room base, seen from
over the character's shoulder. WASD moves relative to the camera, the mouse
turns it, the wheel zooms. Shift sprints until the bar runs out. Go through the
internal doorway, out of the building and across to the tower. F3 for the
readout, backtick for the console, Escape for the menu. Space jumps, left
click punches — hit a wanderer enough and it blows up. Health and stamina are
on screen, and both come back on their own if you leave them alone.

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

### 20. Wandering characters

Six actors amble about the world at 1.3 m/s, pausing for a few seconds between
short walks, each straying no more than 9 m from where it spawned.

**This is what the input abstraction was for.** A wanderer runs the *player's*
`MovementComponent` — same acceleration, same turning, same collision, same
animation state machine — and movement cannot tell that the intent came from a
state machine rather than a keyboard. Feature 4 claimed that would work; this is
the first time anything proved it.

`WanderConfig` → `Wander` → `WanderComponent`. `Wander` is pure: hand it a
position and a delta, get back a direction. No nodes, no navigation, no physics.

The rules worth having:

- **A give-up timer.** An actor wedged against a wall, or aiming at a spot
  inside a building, walks into it for the rest of the session without one.
- **Seeded per actor.** Wanderers sharing a generator walk in step, which reads
  as choreography rather than life. Each gets its own seed from the spawner, and
  the spawner's own seed is fixed so a world looks the same twice.
- **Destinations spread evenly over the circle**, by square-rooting the random
  radius. Without it they bunch toward the middle and a group reads as a huddle.
- **Ticked by the component, not by `poll()`.** Polling reports what the last
  tick decided and advances nothing — the states-versus-deltas rule from feature
  16, applied before it could bite.

`WandererSpawner` places them, keeps them out of the base so nobody is standing
in the room you wake up in, and gives each a `random_id()` because a tree path
is not an identity for something spawned (feature 11's rule).

**These are not enemies.** No aggression, no targeting, no combat — the brief
keeps those out and this does not smuggle them in. They are characters that
exist and move. They will happily wander into the tower.

### 21. Punches connect

The swing from feature 19 now lands. `MeleeSolver` answers whether a target is
within reach and inside the arc; `AttackComponent` asks the physics server what
is near, filters by that, and damages what it finds.

A shape query rather than a walk of every actor: the physics server already
knows what is nearby, and asking it scales with the crowd rather than with the
map. Height is deliberately ignored — a punch that misses because the target
stands slightly downhill is worse than one that is generous about height.

`HurtReaction` is the receiving end. It listens to `HealthComponent.damaged`,
holds a short reeling window, and that window does two things: the animation
shows the flinch, and whatever drives the actor stops driving it. Kept out of
`HealthComponent` because health owns a number and how long a character reels is
presentation. A second hit **restarts** the reel rather than being swallowed by
the first, which is the difference between a punch that lands and one that does
nothing.

In the state machine, being hit beats everything including your own swing: a
punch landing on someone mid-punch has to interrupt them or it did not land.

A new trap in `CLAUDE.md` came out of this. **`Vector2` holds 32-bit floats**, so
`angle_to` on an exact half-turn returns `3.14159274` — larger than
double-precision `PI`. A 360-degree arc therefore failed to reach the thing
directly behind. Angles need a tolerance, never an exact comparison.

**Death is only half-handled.** A wanderer at zero health stops moving for good
and that is all: the rig has no death clip, and nothing despawns or loots it. It
stands there. Deliberate — a death *system* is its own feature, and inventing
one here would decide respawning, bodies and loot on the game's behalf.

### 22. Regeneration, a HUD, and blowing up

**Health regenerates** at 3/s after 6 quiet seconds, the same shape stamina has
had since feature 6 — and for the same reason: without the delay, health ticks
back up between blows and a fight has no attrition in it. The delay reuses
`Cooldown`, because "you cannot do that again yet" is the same problem the punch
already solved.

**`PlayerHud` is not the debug overlay.** They are separate because they answer
to different people — one is for whoever is playing, the other for whoever is
building — and because F3 should not take your health bar away with it. It is
driven by the `changed` signals rather than polled, so a bar redraws only when
the number behind it moves. Health turns urgent below 30%, and the stamina bar
changes colour while you are locked out, because an actor who cannot sprint
should not look identical to one who can.

**`ExplodeOnDeath` finishes what feature 21 left half-done.** A wanderer at zero
health bursts and is removed. Still not a death *system* — nothing respawns,
drops loot or leaves a body — but nothing stands there inert either.

The trap worth keeping: **the burst is parented to the actor's parent, never the
actor.** An effect spawned as a child of the thing being freed is freed with it
and lasts zero frames. There is a test that asserts a surviving explosion is
left in the world.

Measured end to end: nine punches to blow a wanderer up, and a player at 55
health back to 72 once the delay had run.

### 23. Respawning and hit feedback

**The world tops itself back up.** `WandererSpawner` prunes actors that have
been freed, notices the gap, waits eight seconds and puts one back. Not instant:
somebody reappearing the moment you finished them reads as the punch not
counting. Replacements never land within 14 m of the player — a wanderer
materialising in front of you is worse than a world with one fewer in it for a
moment.

The delay had a bug worth remembering: a fresh `Cooldown` is **ready**, not
waiting, so the first death refilled on the spot and the delay only ever applied
*between* replacements. The wait now starts when a gap appears.

**Damage numbers** float up off whatever was hit and fade late — a number that
starts disappearing immediately is one you have to be already looking at. They
belong to the *attacker* (`DamageNumbers` on the player), because the question
is "how much am I doing"; a wanderer walking into a wall does not litter the
world with numbers. The killing hit prints bigger and in a different colour,
decided *before* the damage lands so it answers what is about to happen.

**A health bar floats over whoever you hit**, and only over them. Always-on bars
turn a landscape into a spreadsheet; one that appears on damage and fades after
four quiet seconds answers the only question you were asking. Built from two
billboarded quads rather than a `SubViewport` per actor, which would be a render
target per actor.

Two details that are load-bearing rather than fussy: the fill pivot never scales
to exactly zero, because a zero scale collapses the basis and Godot warns about
a non-invertible transform every frame it is on screen. And both the bar
material and the HUD's `StyleBox` are duplicated before tinting, or recolouring
one recolours every one in the world — post 013's trap, now met three times.

Both the number and the burst are parented to the victim's **parent**. Anything
attached to the thing being freed is freed with it, and the killing blow is
exactly the feedback you most want to see.

### 24. A companion, and navigation

A friend spawns beside you and follows you around, going **round** walls rather
than into them.

`FollowConfig` → `Follow` → `FollowComponent`. `Follow` is distances and a
clock: whether to set off, keep going, or stop. The route comes from a
`NavigationAgent3D`; movement is still the player's own `MovementComponent`,
which now has three different things driving it and cannot tell any of them
apart.

- **A short delay before setting off** (0.6 s). A companion that moves on the
  same frame you do is glued to you rather than following you.
- **Hysteresis on the distances** — stops at 2.2 m, sets off again at 3.2 m.
  With one threshold it starts and stops every frame while you stand still.
- **It sprints when it falls more than 9 m behind**, spending stamina like
  anyone else, through the same sprint the player uses.

**Navigation is baked at runtime**, after the pads are flattened and the walls
are up — a mesh baked over the original hillside would route through walls and
up slopes that no longer exist. Terrain and structures join a
`navigation_source` group, because they are siblings in the scene rather than
children of the region.

Two numbers that had to be right, and the reason the whole thing looked broken
until they were:

- **`agent_radius` is ceiled to whole cells by the bake.** At 0.55 with 0.25
  cells it became 0.75, eroding 0.75 m from every surface — which leaves a 1.6 m
  doorway with a tenth of a metre of navigable width.
- **Cell size had to drop to 0.1.** Even at a correct radius, a 1.6 m opening
  in a 0.3 m wall does not survive rasterisation at 0.25. The project's default
  navigation cell size matches, or every region added warns.

The symptom of both was identical and misleading: the companion set off, walked
confidently into an internal wall, and stayed there. `is_pathfinding()` exists
so that "walks into walls" and "has no navmesh" can be told apart.

### 25. Multiplayer foundation

Priority 4 of this project has always been "multiplayer-friendly architecture —
authoritative server later, single-player now". This is the first instalment,
and it is a *seam* rather than a feature: nothing about playing the game changes.

**`MULTIPLAYER.md` is the design.** Read it before touching networking. The
short version:

- **Single-player is a host with one local player and no socket**, never a
  separate code path. Two paths diverge and every multiplayer bug becomes one
  that only reproduces in multiplayer.
- **Server-authoritative.** Clients send intent and render; the server decides.
- Sized for **100 players**, with an honest account of what an MMO additionally
  needs (zone servers, a database, a gateway, and probably not Godot's
  high-level multiplayer).

`GameSession` says what kind of session this process is. `NetworkAuthority`
answers "may I simulate this?" and is built on Godot's own per-node authority
rather than a scheme of our own — with no peer connected it answers yes
everywhere, so the checks cost nothing today.

The five systems that mutate shared state now ask before acting: damage, the two
AI drivers, the spawner and death. A test asserts all five still ask, because a
seam nobody uses is not a seam.

Feature 4's `InputSource` turns out to be the load-bearing piece: a
`RemoteInputSource` fed from client packets is a fourth driver, and movement
will not know. Three drivers already exist and none needed movement to change.

**A trap came out of it.** Godot installs an `OfflineMultiplayerPeer` by
default, so `multiplayer_peer != null` and `has_multiplayer_peer()` are both
*true* in single-player — a connectivity check written either way never fires.
The offline peer reports id 1 and `is_server() == true`, which is right for
authority and wrong for "is anyone there".

## What is not built

The slice is done, so this is the honest list of what a survival game still
needs and this repo does not have:

- **Interaction** — the one component from the brief's list that is missing. It
  was not in the numbered plan, and nothing yet has anything to interact with.
- **A save system.** Objects can be addressed; nothing serialises them. Worth
  building *after* the networking decisions rather than before: an MMO's
  persistence is a database on the server, not a file on a client.
- **Any actual networking.** Feature 25 laid the seam; there is no transport, no
  replication and no prediction. `MULTIPLAYER.md` has the order of work.
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
