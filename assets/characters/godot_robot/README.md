# 3D Godot Robot — placeholder player character

| | |
|---|---|
| Source | <https://github.com/AGChow/3D-Godot-Robot-Platformer-Character> |
| Via | Godot Asset Library, asset `1467` |
| Author | CaptainRipley / AGChow |
| Licence | **CC0 1.0 Universal** — see `LICENSE`. No attribution required; kept anyway. |
| Commit | `fecf5b23e825cabedb9a6c9872d03ee57b5fdd61` |
| Retrieved | 2026-08-04 |

The unmodified upstream archive is kept outside the repo at
`<games-root>/source/survival-poc/characters/3d-godot-robot-fecf5b2.zip`. Only
the engine-ready `.glb` lives here, per the rule in `CLAUDE.md`.

## Why this one

A **placeholder**, chosen because it was the only CC0 rigged character with
locomotion clips that could actually be fetched without driving someone's
checkout or Google Drive. It is a robot, not a human. Replacing it is expected.

## Clips

Twenty animations. Four are wired up in
`resources/animation/player_animation.tres`:

| State | Clip |
|---|---|
| idle | `Idle-loop` |
| walk | `Run-loop` |
| run | `Sprint-loop` |
| fall | `Fall-loop` |

The mapping is not a typo. This rig came from a platformer where the base
locomotion *is* a run, so its `Run-loop` is our walk and its `Sprint-loop` is our
run. Nothing in the code cares — `AnimationConfig` exports the clip name for each
state precisely so a rig never has to be renamed to suit us.

The other sixteen (`Jump`, `Attack1`, `Crouch`, `WallSlide`, …) are unused: the
state machine has four states and no jump. They cost nothing sitting in the file.
