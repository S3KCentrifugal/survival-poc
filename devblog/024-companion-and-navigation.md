# 024 — A friend, and two numbers that broke pathfinding

*2026-08-05 · commit pending*

There is now a companion that follows you around, and it goes round walls rather
than into them. Most of this post is about the hour it spent walking into one.

## Third driver, same movement

`MovementComponent` now has three things steering it: a human at a keyboard, a
wanderer's state machine, and a companion following a path. None of them know
about each other and none of them required a line of movement to change.

That claim was made in feature 4, first cashed in feature 20, and is starting to
feel less like a design principle and more like a fact about the codebase. The
new code in this feature is entirely *deciding* — no movement, no collision, no
turning, no animation.

## The delay is the difference between following and being glued

`Follow` is distances and a clock. Three rules, and only the first was asked
for:

**A 0.6 second pause before setting off.** Requested, and correct: a companion
that starts moving on the same frame you do is attached to you rather than
following you. It reads as a trailer rather than a person.

**Hysteresis on the stop distance.** Not requested, and necessary. It stops at
2.2 m and only sets off again at 3.2 m. With a single threshold, a companion
standing at exactly that range starts and stops on alternating frames — the same
problem as the walk/idle flicker in post 008, and the same fix.

**Sprinting when it falls behind.** Beyond 9 m it sprints, spending stamina
through exactly the same system the player uses, so it can be exhausted by
chasing you. That was not asked for either, but a companion that can never catch
up is one you leave behind, and the sprint was already there.

## The hour it spent walking into a wall

Navigation is baked at runtime, because the terrain is generated and the
buildings are assembled from code. It has to happen *after* the pads are
flattened and the walls are up: a mesh baked over the original hillside would
route the companion through walls and up slopes that no longer exist.

That part worked first time. Then:

```
companion indoors at (-4.5, 1.5); player outside at (4.0, 12.0)
0.3s later: state=0 (waiting)
1s: 12.4 m away, following=true, sprinting=true
15s: 10.0 m away, at (-0.7, 3.2), left the building: false
```

It set off, it sprinted, and fifteen seconds later it had moved four metres and
was pressed against the internal wall. Everything reported success. The navmesh
had baked — 506 polygons. The map was valid. `is_target_reachable()` was true
for a nearby target.

The cause was two numbers, and both had the same shape: **a value silently
rounded to the resolution of the voxel grid.**

**`agent_radius` is ceiled to whole cells.** I asked for 0.55 with 0.25 m cells,
and got 0.75. The bake erodes that radius from every surface, so a 1.6 m doorway
in a 0.3 m wall was left with 1.6 − 1.5 = **0.1 m** of navigable width. Godot
says so, in a warning I had been filtering out of the output because the *other*
navigation warning was noisy:

```
WARNING: Property agent_radius is ceiled to cell_size voxel units and loses precision.
```

**And the cell size itself.** Even at an exact radius of 0.5, a 0.6 m residual
gap does not reliably survive rasterisation at 0.25 m. Dropping cells to 0.1 m
took the mesh from 506 polygons to 1475 and made the doorways real.

What made this expensive is that both failures present *identically to a working
system that has simply decided not to go that way*. The agent had a valid map, a
reachable nearby target, and a confident straight-line direction. There was no
error, no null, nothing to catch.

`FollowComponent.is_pathfinding()` exists because of that hour. "The companion
walks into walls" and "the companion has no route and is falling back to a
straight line" look the same from the outside, and the difference is the first
thing you want to know.

## On filtering warnings

I hid the navigation warnings from my own test output because one of them —
a cell size mismatch — was firing on every region and drowning the summary. The
message that would have saved the hour was in the batch I was filtering.

The right move was the one I eventually made: fix the mismatch so the channel is
quiet, rather than silence the channel. This is the third time in this project
that clean output has turned out to be worth real time (posts 015 and 018 being
the others), and the first time I broke my own rule and paid for it.

## Sprint was already there

The other half of the request was a sprint on Shift. It has been in since
feature 7, bound to Shift by physical keycode. I checked before writing
anything:

```
walk  1.5s:  6.23 m (sprinting=false)
shift 1.5s: 10.90 m (sprinting=true)
```

The first attempt to verify it reported `0.00 m` and looked like a bug — the
player was walking into the base's north wall the whole time. Fourth harness
mistake in five features, and the same lesson as post 021: when a probe
disagrees with tested code, suspect the probe.
