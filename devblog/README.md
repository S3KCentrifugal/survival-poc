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

Numbers follow the **feature** order, not the order posts get written — 012 is
the twelfth feature, and 002–011 below are still owed.

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
