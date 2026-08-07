# Dev blog

The narrative record of this project: why things were built the way they were,
what went wrong, and what the next person should know before they touch it.

`PROGRESS.md` is the *current* state — kept accurate, rewritten as things
change, read first when picking the work back up. This folder is the *history* —
appended to, and left alone. A post is a record of a moment. If something in an
old post later turns out to be wrong, the correction goes in a **new** post
rather than an edit to the old one.

## Convention

- **Markdown only.**
- `NNN-slug.md` — zero-padded three-digit sequence, kebab-case slug. Numbers are
  never reused and never renumbered.
- Every post opens with a metadata line: the date, and the commits it covers.
- Write what a reader cannot get from the diff: the alternative that was
  rejected, the trap that cost an afternoon, the number that turned out to be
  wrong.

## Posts

| # | Post | Covers |
|---|---|---|
| 001 | [Foundations](001-foundations.md) | Scaffold, engine pin, test harness, empty 3D world |
| 012 | [A character with legs](012-player-character.md) | Sourcing a CC0 rig, and three things that went wrong |
| 013 | [Facing the way you run](013-facing-mode.md) | A design reversal, and Godot's resource cache |
| 014 | [A base to walk out of](014-prototype-level.md) | Levelling ground, subtracting doorways, a 5 cm floor |
| 015 | [A console, and two ways to lose an object](015-dev-console.md) | Callables, bound arguments, and a leak with no failing test |
| 016 | [Over the shoulder, and a correction](016-third-person-camera.md) | Mouse look, why the camera must not follow itself, and a backwards character |
| 017 | [Jump](017-jump.md) | Height not speed, held not pressed, and a 0.04-second animation |
| 018 | [A menu, and the file a player can edit](018-settings-menu.md) | Validating settings, Escape's second job, and a test that wrote real data |
| 019 | [A punch that hits nothing](019-punch.md) | Why the swing is not the combat, and a reusable cooldown |
| 020 | [Six characters, and the promise from feature 4](020-wanderers.md) | The input abstraction paying off, and a give-up timer |
| 021 | [Punches connect, and π is not π](021-punches-connect.md) | Hit detection, flinching, and 32-bit trigonometry |
| 022 | [Two bars, one delay, and a puff of sparks](022-regen-hud-explosions.md) | Regeneration, why the HUD is not the overlay, and a guard that cleared itself |
| 023 | [Telling the player what happened](023-feedback-and-respawning.md) | Respawning, damage numbers, and a shared resource caught a third time |
| 024 | [A friend, and two numbers that broke pathfinding](024-companion-and-navigation.md) | Following, runtime navmesh baking, and voxel rounding |
| 028 | [A front door](028-title-screen.md) | Why the scene swap is hand-rolled, and a child that was ready too early |
| 029 | [Two jumps, and a companion that could not die](029-double-jump-and-a-companion-that-could-not-die.md) | Air jumps in data, a test that was testing itself, and the bill for composition |
| 030 | [The sky](030-the-sky.md) | Colour decisions out of the shader, a hole in the world, and a shared resource caught a fourth time |
| 031 | [Mushrooms, and somewhere to put them](031-mushrooms-and-a-bag.md) | Stacking as pure logic, a group instead of an Area3D, and the first spare protocol bit spent |
| 032 | [Dragging things out, and three ways to leak](032-dragging-things-out.md) | Drag logic outside the mouse, a resource cycle, and two error messages that name the wrong file |
| 033 | [Terrain with somewhere to stand](033-terrain-with-somewhere-to-stand.md) | Four noise layers, tuning against numbers, and a navmesh conclusion remembered wrong |
| 034 | [Music nobody wrote, and soup](034-music-and-soup.md) | Synthesised music, testing a loop seam, and a bench buried under its own floor |
| 035 | [A chat box, and a range check that aged badly](035-a-chat-box.md) | Sanitising other people's text, a length byte you must not trust, and typing that walked the character |
| 036 | [Gold, merchants, and one key with one owner](036-gold-and-merchants.md) | Currency as an item, all-or-nothing trades, and five tests that had stopped testing anything |
| 037 | [Levels, and a swing worth waiting for](037-levels-and-a-heavier-swing.md) | A curve instead of a table, who gets credit for a kill, and a panel that released the cursor but not the keyboard |
| 038 | [A shop you could not leave](038-a-shop-you-could-not-leave.md) | Input order decided by an invisible line in a .tscn, and suspension resetting every rising edge |
| 039 | [Three components that were one](039-three-components-that-were-one.md) | Splitting reachable from pickable, reach as a property of the thing, and a test runner that was lying |
| 040 | [An interface with rules](040-an-interface-with-rules.md) | Naming the guidelines, one theme instead of 84 overrides, and contrast tests that failed on the palette I had just shipped |
| 041 | [Getting it to testers](041-getting-it-to-testers.md) | Why Steam Playtest, the executable bit that fails silently, and a session file that expires without telling anyone |
| 042 | [A harness that measures itself](042-a-harness-that-measures-itself.md) | Repeatable screenshots, golden images, a 6K rendering bug, and a frame budget built on a premise that turned out to be false |
| 043 | [Rules for a look](043-rules-for-a-look.md) | An art direction with numbers under it, three attempts at one measurement, and a character nobody can pick out of the grass |
| 044 | [A night you can see in](044-a-night-you-can-see-in.md) | The ambient term that was nearly black by design, a dusk that ended at the horizon, and a measurement that could not tell the fix from the bug |
| 045 | [One shader for everything](045-one-shader-for-everything.md) | Value bands, a ramp that invented light, and three bugs that each produced a picture looking fine |

Numbers follow the **feature** order, not the order posts get written — 012 is
the twelfth feature, and 002–011 and 025–027 below are still owed. The three
multiplayer features shipped without their posts, against the rule in
`CLAUDE.md` that a post lands in the same commit as its feature.

### Planned

The slice was built before this folder existed, so the backlog is written in
arrears. In order:

| # | Post | Feature |
|---|---|---|
| 002 | `002-terrain.md` | Noise heightfield, mesh, matching collision |
| 003 | `003-isometric-camera.md` | Fixed-yaw camera controller |
| 004 | `004-input-abstraction.md` | `InputSource`, and why nothing else reads `Input` |
| 005 | `005-movement.md` | Camera-relative WASD, cursor facing, collision |
| 006 | `006-health-and-stamina.md` | `VitalPool`, the recovery delay, the exhaustion lock |
| 007 | `007-sprint.md` | The seam between movement and stamina |
| 008 | `008-animation-state-machine.md` | Four states, and the hysteresis band |
| 009 | `009-day-night-cycle.md` | One light, a whole atmosphere |
| 010 | `010-debug-overlay.md` | The project's only UI |
| 011 | `011-save-identifiers.md` | Addressing objects a save file has never met |
| 025 | `025-multiplayer-foundation.md` | The authority seam, and single-player as a host of one |
| 026 | `026-wire-protocol.md` | A language-neutral protocol, sized for 100 players |
| 027 | `027-replication.md` | Snapshots, rendering in the past, and eight actors sharing one id |
