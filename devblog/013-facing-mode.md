# 013 — Facing the way you run

*2026-08-04 · commit pending*

The character used to turn to face the mouse cursor. Now it faces the direction
it is travelling. Short post, but it covers a design reversal, a config
decision, and a caching trap that had been sitting there since the project
started.

## The behaviour that was wrong

Feature 5 built facing with a deliberate priority, and defended it in a comment:

> Aim wins over movement — facing the cursor while strafing is the whole point
> of a top-down control scheme.

That is a true sentence about ARPGs, and it was still the wrong call here. It
describes what a top-down game does **in combat**, where you back away from
something while keeping your weapon pointed at it. There is no combat. What it
actually produced was a character whose head was dragged around by the mouse
while running, looking sideways at nothing.

The clue was in the original comment all along: it justified the behaviour by an
activity the game does not have.

## Why a config value and not a deletion

The obvious move is to delete four lines and always face travel. I did not,
because both behaviours are genuinely correct for this genre at different
moments, and the cursor path was already written, already tested and already
working.

So `MovementConfig` gained a `FacingMode` enum — `MOVEMENT` or `CURSOR` — and
the player's `.tres` selects `MOVEMENT`. That is one exported property and one
branch. It is not speculative machinery: it is a design decision moved out of a
component and into the data, which is where this project says design decisions
live.

The test for cursor facing did not get deleted either. It sets the mode and
asserts the old behaviour still works.

`InputState.has_aim` and `aim_point` are now **populated but unconsumed** —
exactly the status `sprint` had between features 4 and 7. Interaction targeting
will want them, and resolving the cursor against a ground plane costs nothing.
It is not dead code; it is code with no customer yet.

## The trap: `load()` returns the same object every time

Writing the tests turned up something that would have bitten eventually and been
horrible to diagnose.

To test cursor facing I set `movement.config.facing_mode = CURSOR`. Godot's
`load()` **caches resources**: every caller of
`load("res://resources/movement/player_movement.tres")` gets *the same instance*.
So that assignment did not configure one actor for one test — it reconfigured
the player's movement for every test in the run, in file order, depending on
which suite happened to go first.

The fix is `duplicate()` before mutating, with a comment saying why. The
insurance is a new test that mounts two players, switches one, and asserts the
other did not move:

```gdscript
func test_switching_one_actor_does_not_change_the_shared_config() -> void:
```

This is the same shape of bug as the `StringName` sort in post 012: a thing that
works by accident, in a way no assertion in the suite could distinguish from
working on purpose. Two in two days suggests the real lesson is to be suspicious
of any test that shares mutable state with the thing it is testing.

## Verifying it

Facing is not something to take a passing test's word for, so the check ran the
character through all four compass directions with the aim point pinned far to
the north the entire time — under the old behaviour, every leg would have faced
north.

```
east   travel  1.00, 0.00  facing  1.00, 0.00  off by   0.0 deg
south  travel  0.00, 1.00  facing  0.00, 1.00  off by   0.0 deg
west   travel -1.00, 0.00  facing -1.00, 0.00  off by   0.0 deg
```

Zero degrees off in every direction, plus a render to confirm the model itself
was turning rather than just the collision body.

## Note

Nothing about the turn *rate* changed. Facing still eases toward the target at
`turn_speed_degrees` (720°/s) using `angle_difference`, so it takes the short way
round and does not snap. Reversing direction mid-run reads as a turn, not a
teleport.
