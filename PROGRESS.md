# Project status

Living record of what this project is, what has been built, and what comes
next. Read this first when picking the work back up.

Last updated after **Feature 38 — Fixing panels that could not be closed**. The planned
vertical slice (features 1–11) was completed long ago; everything since is
built on top of it.

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
| 26 | Wire protocol and transport, sized for 100 players | done | `d29a428` |
| 27 | Entity replication, interpolation, tuning export | done | `831fdaf` |
| 28 | Title screen, scene routing, shared settings panel | done | `c82922a` |
| 29 | Double jump, and a companion that dies | done | `cd68c74` |
| 30 | A sky: gradient, sun disc, halo and stars | done | `63376d3` |
| 31 | Mushrooms, pickup on F, and an inventory on I | done | `4748172` |
| 32 | Dropping items, item icons, and stack counts | done | `b45e62d` |
| 33 | Larger, layered terrain with slope-blended textures | done | `e4daf04` |
| 34 | Generated background music, and a bench that crafts soup | done | `31a71dd` |
| 35 | A chat box on F12, networked | done | `b7b05c8` |
| 36 | Gold, merchants, and a store screen | done | `c7ca19a` |
| 37 | Levels and experience, and a heavy attack on right click | done | `4ccec09` |
| 38 | Fix: panels that could not be closed | done | — |

**The planned slice is complete.** 659 tests passing across 48 suites.
`./run_tests.sh` exits non-zero on failure.

Playable now: `./run.sh`. You start in a room inside a two-room base, seen from
over the character's shoulder. WASD moves relative to the camera, the mouse
turns it, the wheel zooms. Shift sprints until the bar runs out. Go through the
internal doorway, out of the building and across to the tower. Outside is 256 m
of grassland with rolling hills and rocky high ground. F3 for the
readout, backtick for the console, Escape for the menu. Space jumps twice, left
click punches and **right click kicks** — much harder, much slower, and it
costs stamina. Hit a wanderer enough and it blows up; hitting things earns
experience, and your level and progress are on the HUD. Red mushrooms grow in
the grass: walk up to one, press **F** to pick it up, **I** to see what you are
carrying — drag a stack onto another slot to move it, or out of the panel to
put it back on the ground. There is a workbench in the second room: stand at it,
press **E**, and three mushrooms become soup. Gold-hatted **merchants** stand
outside — walk up and press **F** to sell mushrooms and soup, or buy a sword.
**F12** opens a chat box.
Something is playing in the background. Health and stamina are on screen, and both come back on their own if
you leave them alone.

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

### 26. Protocol and transport

Host and join work. Two processes exchange a handshake, intent and snapshots
over ENet, sized for **100 players**. `./run.sh` is still single-player: nothing
opens a socket until you ask it to, with `host` or `join` in the dev console.

**The server may one day be Rust**, so `NetworkProtocol` is an explicit
byte-level specification rather than Godot serialisation — plain integers and
IEEE-754 floats, little-endian, fixed layouts, with the message table and
quantisation error bounds documented and asserted by tests. Godot's `@rpc` and
`MultiplayerSynchronizer` encode `Variant`, which nothing outside Godot can read
without reimplementing it, so neither is used for anything crossing the wire.

An entity is **20 bytes**. At 20 Hz and 50 entities in interest that is 20 kB/s
per client and 2 MB/s out of a full server — a test asserts the budget, because
that number is the whole argument for interest management.

`RemoteInputSource` is the fourth driver of `MovementComponent`, and the one
feature 4 was actually built for. Verified end to end: a client's `InputState`
went over the wire as ten bytes and came back out of a `RemoteInputSource` on
the server as `move (0.50, -1.00) sprint=true`.

Two things learned doing it:

- **Reading the ENet peer directly does not work.** Assigning a peer to
  `multiplayer.multiplayer_peer` hands it to `SceneMultiplayer`, which drains
  every packet before anything else sees them. `send_bytes` / `peer_packet` is
  the supported side channel — and keeping the peer attached is what makes
  `is_multiplayer_authority()`, and therefore feature 25's seam, work at all.
- **`NetworkService` is the one file a Rust server replaces.** Godot adds a
  small framing byte to `send_bytes` payloads; that is the only Godot-specific
  thing left below the protocol, and it is isolated in one file by design.

`MULTIPLAYER.md` now has a section on what would make a Rust server hard and how
each is avoided — including the one that genuinely is hard, which is physics.

### 27. Replication

Two machines now see the same world. A player who joins is spawned by the
server, simulated there from their own intent, and broadcast to everyone at
20 Hz. Verified across two processes: nine entities — six wanderers, two
players, one companion — each with its own id, the joining player's character
moved by the server from intent that arrived over the wire.

**Clients render 100 ms in the past.** `SnapshotInterpolator` holds a short
buffer and samples between the two snapshots either side of that moment.
Snapping to the newest would show every remote character stepping twenty times a
second; the cost is a fixed delay and the benefit is that jitter and the odd
lost packet never show. Two snapshot intervals of delay, because one leaves
nothing on the far side to interpolate toward.

`NetworkEntity` is the only thing that knows an actor can be either the real
thing or a **proxy**. A proxy switches off everything that would decide where it
goes — a puppet that also simulates fights its own replicated position — and
`HealthComponent.set_health_fraction` applies replicated health *silently*,
because replaying `damaged` on a client fires flinches and damage numbers for
blows never struck there.

**A bug worth the test that caught it.** Entities placed in the scene rather
than spawned by the service arrive with no id, and all went out as entity 0 — a
client folded the whole world into one character standing in eight places.
Numbering is now its own method precisely so it could be checked without opening
a socket, which is how it was found.

`TuningExport` and the `tuning` command dump all thirteen `.tres` files to JSON,
so a Rust server can read the same numbers from the same source of truth. Godot
types are unwrapped on the way out — nothing should have to parse
`"(1600, 900)"`.

### 28. A front door

The game no longer starts in the world. `project.godot` points at
`res://scenes/title.tscn`, and `SceneRouter` moves between the title and the
game — single player, host, or join — and back again from the pause menu.

The swap is hand-rolled rather than `change_scene_to_file()`, because that call
is deferred and returns nothing: there is no moment at which the new world
exists and can be told to host. Doing it by hand gives back the new scene, so
"build the world, then open a socket in it" is two ordinary lines instead of a
global holding what the player picked.

**Leaving is not arriving in reverse.** `to_title()` closes the connection
first — a player who returns to the title while connected is a ghost the server
is still simulating — and unpauses, because the only route to that button is
through the pause menu and a paused title screen has buttons that do nothing.

The settings panel came out of `ui/pause_menu.tscn` into `ui/settings_menu.tscn`
and is instanced by both screens, with `SettingsController` owning
load-apply-save. It deliberately does **nothing** in `_ready`: a child is ready
before its parent, so a controller that loaded itself read the default settings
path before the pause menu could pass down the test override. That failed as
`expected 144, got 0` and looked like a persistence bug.

The scene swap frees the current scene, which during a test run is the test
runner — so the suite covers everything up to that call and the round trip was
verified with a throwaway probe: title → `Main` with a `Player` and no socket,
then back to `TitleScreen`, unpaused.

### 29. A second jump, and a death that was missing

`MovementConfig.air_jumps` defaults to **0** and the player's `.tres` sets it
to 1. The default matters: every walking actor shares the class, so a default
of 1 would have handed a double jump to six wanderers and the companion.

The air-jump count is reset by *being grounded*, checked every tick, not by
launching — so walking off a ledge leaves the air jump available and landing
returns it before the player thinks to ask. The launch **replaces** vertical
velocity rather than adding to it, so a double jump taken halfway down a fall
is worth exactly as much as one taken at the apex. Measured in the running
game: 1.16 m for a single, 2.23 m for a double.

**The jump suite was testing itself.** Its test double overrode
`consume_jump` — the method under test — with a copy of the rule, so every
assertion below checked the copy. `MovementComponent.is_grounded()` now exists
so a test can override *where the ground is* rather than *what jumping means*,
and the nine jump tests exercise the real thing. A test double should replace
what the code depends on, never what the code does.

**The companion could not die.** It had health, took damage and reached zero,
but its scene had no `ExplodeOnDeath` — the wanderer's has one. It read as a
movement bug because `FollowComponent` correctly stops following when the
follower is dead, so a companion at zero health stands perfectly still. That is
the bill for composition: a missing component is not an error, nothing warns,
and the symptom surfaces somewhere else. Every actor that can be killed now
has a test asserting that killing it does something.

The companion does **not** respawn. `WandererSpawner` tops the wanderer
population back up; nothing does that for the scene-placed companion.

### 30. The sky

The day/night cycle has driven a directional light since feature 9; what was
above it was a stock `ProceduralSkyMaterial` with every property at its
default. It is now a shader with a gradient, a sun disc, a horizon halo and a
field of stars, driven by the same clock.

**The colour decisions are not in the shader.** `SkyGradient` is a plain
`RefCounted` that takes the sun's elevation and returns colours, so "is the
sunset warmer than noon", "is the halo gone once the sun is down", "are there
stars at midday" are assertions rather than opinions. The shader only draws.

`SkyComponent` reads the sun's direction off the `DirectionalLight3D`'s own
basis rather than recomputing it from the clock — two sources for one
direction is two chances to disagree, and a sun drawn away from where the
shadows point is glaring in a screenshot and invisible in a diff.

Three things were wrong on the first render and fixed by looking: a fixed grey
below the horizon put a black band across the view where the terrain tile runs
out (the ground is now the horizon colour darkened, over a much longer fade);
the stars were finer than a pixel and averaged away to nothing; and the sun
needed clipping at the horizon rather than fading, which is what makes it read
as sinking behind something.

**The shared-resource trap, for the fourth time.** Sub-resources are shared
between instantiations of a scene unless they carry
`resource_local_to_scene = true`. Without it, two worlds write uniforms to the
same sky material and one world's clock recolours the other's sky. The
material, the `Sky` and the `Environment` all carry the flag now, and a test
mounts two worlds at opposite times of day and asserts their skies differ.

### 31. Mushrooms, and somewhere to put them

Mushrooms grow across the world, F picks one up, I opens a bag, and they stack.
The scope note said "no inventory" from the first commit; that was right for a
slice about movement and stopped being right once there was something worth
bending down for.

**The stacking rules are a `RefCounted`.** `Inventory` has no nodes and no
signals, so the edge cases that are miserable to check by hand are numbers:
twelve picked one at a time are one slot, partial stacks are topped up before a
new one is opened, a full stack overflows into the next. `add()` returns how
many did **not** fit, because a bool cannot say "two of your three went in" and
would have quietly deleted the third.

**Reach is a group and a distance check, not an `Area3D`.**
`PickupCollector.nearest()` is static and takes its candidates as an argument,
so choosing between two mushrooms is a test with three positions in it and no
physics frame. At fourteen mushrooms the scan costs nothing; thousands of loose
items would want a spatial index, and that is the day it becomes an `Area3D`.

**F is intent like any other.** One bool on `InputState`, one line in each
source, and one spare bit in the protocol's existing button byte — the packet
is the same ten bytes, so `VERSION` did not move and an older peer simply reads
as a player not pressing F. The first time feature 26's spare-bit budget got
spent.

Two bugs the tests found while *setting up* other scenarios: `collect()` used a
target some earlier `step()` had found, so calling it directly picked up
nothing and reported success; and `capacity` was read once in `_ready`, so
setting it afterwards did nothing silently. Both are fixed.

`MushroomPatch` copies `WandererSpawner`'s shape deliberately, including the
`_waiting` flag — a fresh `Cooldown` is ready, not waiting, so without it the
first mushroom picked is replaced on the spot. Fifth caller of `Cooldown`.

The bag does **not** pause the game: the pause menu is a menu about the game,
this is a screen about your character, and in multiplayer a bag that stops the
world cannot exist.

### 32. Dragging things out

Drag a stack onto another slot to move it, or out of the panel entirely to put
it on the ground. Cells show a real icon scaled to fit, and stackable items
show their count.

**The drag methods decide nothing.** They answer which gesture happened and
call something testable: `Inventory.move_to()` for a slot, or
`InventoryScreen.drop_to_world()` for the ground. Moving merges same-item
stacks and swaps otherwise -- a dragged stack that snaps back because the
target was occupied is a UI arguing with you -- and only what fits pours
across, with a test asserting the *total* is unchanged either way.

**Nothing leaves the bag until it exists in the world.** The spawn happens
first; only then is the slot emptied. A stack removed and then failed to spawn
is a stack that exists nowhere. A whole stack lands as one pickup carrying a
count, so nine mushrooms come back in one press of F rather than nine.

`ItemDefinition` holds a **path** to its world scene, not an exported
`PackedScene`: the mushroom scene holds the mushroom resource, so an exported
scene would be a load cycle Godot resolves by luck.

**Three leaks, all found by reading the tail of a green run.** Caching the
loaded scene in a member made a cycle between two `RefCounted`s that GDScript
never collects -- `ResourceLoader` already caches, so the fix was not to.
`set_drag_preview()` outside a real drag hands the viewport a node nothing
frees, so the payload was split into a mouse-free `drag_payload()`. And each
cell builds its own `StyleBoxFlat` -- fifth appearance of the shared-resource
trap, avoided by habit this time.

Two error messages named the wrong file, both now in `CLAUDE.md`: a script that
fails to compile reports at its *caller* as "Nonexistent function 'new'", and
`as Dictionary` on a non-Dictionary raises rather than returning null.

Icons are SVG, rasterised on import, drawn with `EXPAND_IGNORE_SIZE` and
`STRETCH_KEEP_ASPECT_CENTERED` -- without the first, a 512-pixel icon makes an
84-pixel cell 512 pixels wide.

### 33. Terrain with somewhere to stand

256 m across instead of 64, with plains, rolling hills and rocky ridgelines,
textured by slope.

**One noise field cannot make a landscape** -- every square metre is as
interesting as every other, which is the one property real ground never has.
`TerrainShaper` is four layers: a very low-frequency **relief** mask deciding
where the land is interesting, **hills** for the broad shape, folded
`1 - abs(n)` **ridges** for creases where plain noise rounds, and **detail**
everywhere. The hill layer is raised to a power so low ground is more common
than high ground, which is what a landscape does and a test asserts.

**The relief mask has a floor, and that one number is the feature.** At zero,
hills stood on a perfectly flat sheet like cones dropped on a table. Plains now
get 16% of the hill layer, so they undulate in the same shape as the hills and
the hills read as the high end of one landscape.

**Tuned against numbers.** A probe reports the slope profile as percentages,
which is how the original frequencies were caught: they gave 11 m of relief
over 256 m, a four percent grade, because they had been chosen for a much
larger world and at 64 m across there was nothing to notice. The final profile
is 41% flat, 32% rolling, 21% steep, 6% cliff, and the tests assert bands
around it.

**Texturing is derived, not painted.** Grass under 16 degrees, dirt to 26, rock
from 32 -- no splat map to keep in sync with the heightfield, so a new seed
retextures itself. Cliffs are triplanar (a steep face UV-mapped from above is
smeared into vertical streaks), the grass is sampled at two scales to hide the
tiling grid, and the thresholds are jittered so the boundaries are ragged
rather than contour lines. Textures are CC0 from ambientCG, resized to 512 --
676 KB for six maps rather than 13 MB, with provenance in
`assets/terrain/README.md`.

**The navmesh cell size was never the point.** Sixteen times the ground area
took the test suite from a minute to seven and a half, almost all of it the
bake at 0.1 m cells over 256 m -- 6.5 million voxels. Re-reading post 024, the
finding there was that the bake *ceils the agent radius to whole cells*, not
that cells must be small. 0.4 divides by 0.2 exactly, so cells are 0.2 now, the
bake is a sixteenth of the size, the suite is under three minutes and the
companion still walks through the doorway. `agent_max_climb` and
`region_min_size` were being silently rounded too; both are whole cells now.

### 34. Music nobody wrote, and soup

**The music is synthesised at runtime**, not shipped. Nothing in git but the
numbers, no licence to check, and no unexplainable file in a year.
`MusicComposer` is a `RefCounted` producing 16-bit PCM from a `MusicConfig`:
a drone, a pad chord per bar, and a sparse melody, all on a minor pentatonic
scale -- which has no semitones, so any two notes sounding together are
consonant and most of the ways generated music goes wrong are unavailable.

Note tails wrap past the end of the buffer into the beginning, so the loop has
no click in its seam; the test compares the step at the seam against the
largest ordinary sample-to-sample step rather than against a magic number. The
tests prove it is not silent, does not clip, stays on its scale and loops
cleanly. They cannot prove it is pleasant, and it is a placeholder that knows
it is one.

Rendering takes ~1.2 s, so it is cached on the config's *values* -- holding the
bytes rather than the stream, because a static variable holding a `Resource` is
reported as a leak on the way out. It also does not play with no display:
Godot's headless audio server takes a playback and never returns it, and a run
with no speakers has nothing to gain from thirty seconds of DSP.

**A workbench in the second room crafts soup from three mushrooms.** The
nearest-thing-in-reach search moved out of `PickupCollector` into `Proximity`,
duck-typed on `world_position()` and `is_available()` -- no base class needed,
and one search instead of two that drift apart.

F and E are separate keys on purpose: F takes a thing away, E operates a thing
that stays, and folding them together means deciding what a press means when a
mushroom is growing next to the bench. The HUD shows both prompts when both are
in reach.

Crafting checks room for the output *after* notionally removing the
ingredients, because the ingredients usually free the room the output needs --
three mushrooms in a one-slot bag can become one soup. And it is all or
nothing: the ingredients are only removed once the whole craft is known to
work.

**A hard-coded height, buried.** The bench went in at `y = 0`; the building
floor is wherever the terrain puts it, which after feature 33 was several
metres up. Nothing errored -- the player spawned inside the buried bench and
fell to y = -255, and the only tell was the overlay reading `state fall`.
`WorldRoot` now drops the bench onto the floor from a `Vector2`, exactly as it
already did for the player and companion, with a test that says so.

### 35. A chat box

F12 shows and hides it. Type, press Enter, and the line appears -- on your
screen and on everyone else's, because a chat that cannot reach anyone is not a
usable chat and the networking has existed since feature 26. In single-player
it is the same path with the send skipped.

Your own message appears immediately rather than waiting for the server to echo
it, because a round trip's delay on your own words reads as the chat being
broken. The display name comes from the peer id the packet arrived on, never
from inside it -- a sender who picks their own name picks everyone else's.

**`ChatLog` is where other people's text is made safe**, and it is a
`RefCounted` so hostile input is a test rather than something someone types.
Newlines become spaces (a message that can contain one can draw a fake line
attributed to somebody else; a message that can contain many can push the log
off the screen), other control characters are removed, and the length cap is
enforced there rather than on the text box -- because the box is not the only
way a message arrives.

CHAT is the protocol's first variable-length message. The length is one byte so
the ceiling is unmissable, and it is checked against the bytes actually present
rather than trusted. Truncation cuts on a character boundary; cutting UTF-8
mid-sequence sends an empty message rather than a short one.

**Adding the kind broke every chat packet**, silently. `kind_of` range-checked
against `Kind.DESPAWN` -- whichever kind was last when the check was written --
so a new kind fell outside and was ignored, which is exactly what an
unrecognised kind is supposed to do. It is a membership test now, with a test
that walks every enum value.

**Typing must not walk the character.** `PlayerInputSource.suspended` makes
`poll()` report a player doing nothing, which suspends movement, jumping,
punching, picking up and using at once rather than each learning what a chat
box is. The test that matters most is the one asserting that hiding the box
while typing gives the keyboard back.

### 36. Gold, merchants, and a store

**Gold is an `ItemDefinition`, not a wallet.** `Purse` wraps the three questions
a price needs asked, and everything else comes free: coins stack, appear in the
bag with an icon, can be dropped and picked up, and merchants carry theirs in
the same `InventoryComponent` the player uses -- so a merchant running out of
money is the inventory system working rather than a special case.

`Trade` is static functions over two `Inventory` objects, checked in full before
anything moves, so there is no partial state to unwind. A merchant cannot pay
past their purse (400 gold each, which is what stops a respawning mushroom
patch being a money printer), and paying can free the slot the goods land in --
the same rule crafting uses, because refusing a trade that would obviously work
is a rule nobody can work out from the outside.

**One key, one owner.** Merchants were asked for on F, which was already the
pickup key. Two components watching one key means standing between a mushroom
and a merchant does both, so `InteractionRouter` now owns F: it searches both
groups at their own reaches, takes whichever is genuinely nearest, and
dispatches. `PickupCollector` kept every public method and stopped watching the
keyboard. The workbench stays on E -- operating a fixture is a different verb,
and a bench cannot be mistaken for a mushroom.

**Merchants look different**: a nameplate, a gold hat, and a `ModelTint` that
sets `material_overlay` rather than `material_override` -- an override replaces
the model's materials and turns a textured robot into a flat silhouette. The
tint walks the tree for meshes rather than naming them, because an imported glb
has whatever structure the exporter felt like. They also do not wander, because
a merchant who walks off while you read their prices is one you stop visiting.

Offers are duplicated per merchant on ready. Two merchants from one scene would
otherwise share a `stock` counter -- sixth appearance of the shared-resource
trap, and the first time it was written defensively rather than discovered.

### 37. Levels, and a swing worth waiting for

**Thirty levels from three numbers.** `ExperienceTable` is a `RefCounted` over a
curve config, so the properties that matter are assertions: the cumulative
curve never goes backwards, each level costs at least as much as the last, the
exact total for level N reads back as level N, and a growth of exactly 1.0
still rises rather than plateauing. A capped character shows a **full** bar --
an empty one at max level looks like somebody who just lost their progress.

Experience comes from damage (0.5 per point) as well as kills (25 bonus), so a
fight you lose is worth something and the number moves while you are watching
it. The kill bonus rides on a `killed` signal emitted by the **attacker**, not
the victim: `HealthComponent.died` cannot say who did it, and the attacker is
the only one holding both ends. Levels are announced one signal per level
crossed, so a kill spanning two emits twice.

**Right click is a heavy attack** using the rig's `Kick` clip -- found by
reading the imported animation list rather than assuming, the same way the
`-loop` suffix trap was. It trades in four directions, each with a test on the
*relationship* rather than the number: 34 damage against 12, 1.15 s against
0.35, 2.3 m reach against 1.8, and 70 degrees of arc against 110. Further but
narrower, because a heavy that also forgives your aim is strictly better and
leaves no decision. It costs 25 stamina, refused rather than weakened.

A light punch cannot be thrown during the heavy's recovery. Without that, a jab
cancels the commitment and you pay none of the cost -- the standard way this
pair of moves gets broken.

**The new binding exposed a latent bug.** The inventory, shop and bench released
the cursor but not the keyboard, so the character stayed playable behind the
panel. Harmless until clicking "Sell" also kicked whoever stood behind it. All
three now call `set_input_suspended`, the mechanism the chat box already had.

### 38. A shop you could not leave

Reported from play: the merchant dialog could not be closed. Two bugs, both
introduced by earlier features, both green in the suite.

**Escape reached the pause menu first.** `_unhandled_input` is delivered in
reverse tree order and `PauseMenu` sits after the panels in `main.tscn`, so the
menu opened *over* the open shop. Which node wins was decided by a line in a
scene file that neither script mentions. The three modal panels now take their
close key in `_input`, which runs before all of `_unhandled_input` -- the same
thing the dev console already did.

**F reopened the shop as fast as it closed it.** Feature 37 made panels suspend
gameplay input; a suspended source reports every button released, so the still
held F read as a rising edge the moment the panel closed and unsuspended.
`PlayerInputSource` now swallows every edge action still held when input
resumes -- only the edge ones, since movement is asked "are you held" and
swallowing it would strand the player until they let go of W.

Both are sequence bugs: a key held across a state change, two nodes competing
for one event. A single call proves neither, which is why a green suite and a
screenshot of a working shop both missed them. The new tests are all sequences,
including one asserting Escape still opens the pause menu when nothing else is
open -- precisely what a fix like this breaks next.

## What is not built

The slice is done, so this is the honest list of what a survival game still
needs and this repo does not have:

- **Interaction** — the one component from the brief's list that is missing. It
  was not in the numbered plan, and nothing yet has anything to interact with.
- **A save system.** Objects can be addressed; nothing serialises them. Worth
  building *after* the networking decisions rather than before: an MMO's
  persistence is a database on the server, not a file on a client.
- **Client prediction.** Your own movement is currently latency-bound: intent
  goes to the server and the result comes back. Step 5 in `MULTIPLAYER.md`, and
  the reason `MovementSolver` is pure.
- **Interest management.** Every client is sent every entity. Fine for the
  prototype world, and the thing that has to exist before player counts get
  interesting. Step 6.
- **A client that defers entirely to the server.** A joining client still runs
  its own scene-placed world alongside the replicated one, so it sees both. The
  world should come from the server alone once connected.
- **Server-validated damage, and a gated console.** Items 1 and 5 of "what is
  wrong today" in `MULTIPLAYER.md` are still open: the attacker applies damage,
  and `tp`/`kill`/`time` are ungated.
- **Terrain streaming.** One 256 m tile, and its edges are vertical drops
  because a finite tile has to end somewhere. Chunking means many
  `Heightfield`s rather than a rewrite, which was the point of keeping it
  node-free.
- **Content spread over the new ground.** Wanderers scatter over 28 m and
  mushrooms over 44 m, both tuned when the world was 64 m across. They now sit
  in a cluster near the base with 256 m of empty grass around them.
- **A level format.** The prototype layout is constants in
  `scripts/world/prototype_level.gd`. The second building is what should decide
  what a level resource needs to say.
- **Roofs, doors that open, windows, stairs.** Buildings are open-topped boxes
  with holes in them, which is all a top-down camera needs to see into.
- **A character of our own.** The player is a CC0 robot standing in for one. It
  animates and it is the right height; it is not the art direction.
- **A test runner that fails on script errors.** Moving the interact key broke
  five pickup tests with `SCRIPT ERROR: Invalid assignment ...`, and the suite
  reported **all passing** -- a script error aborts a test body without failing
  an assertion. Those five tests were doing nothing and nothing said so. This is
  the most valuable thing on this list: a suite that logs a script error must
  not be able to report success.
- **Anything that a level unlocks.** Levels are earned and displayed; nothing
  reads them. Stat growth, gated recipes and a merchant who stocks better
  things at level 10 are all the obvious next step and none are built.
- **Experience for anything but fighting.** Crafting soup and selling to a
  merchant award nothing. Both are one `connect` away, which is why
  `ExperienceComponent` listens rather than reaching.
- **A sword that does anything.** It can be bought, carried, dropped and picked
  up. It is not equippable and does not change the punch.
- **Player names.** Chat shows "Player 2" and your own line says "You". Real
  names want accounts, and accounts want a server that is not this one.
- **Chat moderation of any kind.** Text is sanitised so it cannot break the
  log or impersonate a system line; there is no muting, no rate limit and no
  filter. A rate limit is the first thing a public server would need.
- **Eating anything.** Soup can be made, carried and dropped; nothing consumes
  it and it restores nothing. That is the obvious next thing and was
  deliberately not built.
- **A second recipe, or a bench that is not the only one.** `Recipe` takes a
  list of ingredients and `WorkbenchComponent` a list of recipes, so both are
  ready; there is one of each.
- **Music that anyone would choose to listen to.** What is there is
  synthesised, correct, and a placeholder.
- **Splitting a stack.** A drag moves the whole thing. Half-stack drags want a
  modifier key and a decision about what the UI does with the remainder.
- **Item art beyond one mushroom.** Everything else falls back to a coloured
  swatch, which is honest about missing icons rather than pretending.
- **A bag that survives a restart.** Objects can be addressed and items have
  stable ids, but nothing serialises them -- still waiting on the save system.
- **Clouds, a moon, and weather.** The sky has a sun, a gradient and stars.
  Everything else in the sky is still nothing.
- **A companion that comes back.** Killing it is permanent until relaunch;
  only wanderers are topped back up.
- **Devblog posts 025–027.** The three multiplayer features shipped without
  them, against the rule that a post lands in the same commit as its feature.
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
Resolved: camera distance, by feature 16 replacing the fixed 18 m isometric
camera with a 5 m third-person one. Terrain noise frequency, by feature 33
replacing the single noise field with four layers tuned against a measured
slope profile.

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
