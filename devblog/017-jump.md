# 017 — Jump

*2026-08-04 · commit `4b13064`*

Space jumps 1.1 metres. Small feature, three decisions worth writing down and
one thing about rigs I did not know this morning.

## Height, not launch speed

`MovementConfig.jump_height` is in metres of clearance. The launch speed comes
from `MovementSolver.jump_velocity()`:

```gdscript
return sqrt(2.0 * gravity * height)
```

The alternative — exporting a `jump_velocity` directly — is one fewer line and
quietly wrong. Height is the number anyone actually cares about, because it
answers "can I get onto that ledge". Gravity in this project is already tuned
away from Earth's (20 m/s², because real gravity feels floaty at this scale),
and it may be retuned again. With a speed exported, every gravity change
silently alters what the character can climb. With a height exported, it does
not.

The test asserts the round trip rather than the formula: launch at the derived
speed, compute the apex from `v²/2g`, and check it lands on the height that was
asked for.

## Held, not pressed — and why that is the opposite of last time

`InputState.jump` is whether the key is **down**, exactly like `sprint`. The
rising edge is spotted by `MovementComponent`, which remembers whether the key
was held last tick.

This is the same question post 016 answered the other way. There, `look` and
`zoom` were kept *out* of `InputState` because they are deltas and reading one
twice turns the camera twice. Here, jump goes *in*, because "is space down" is a
state — two things can read it in the same tick, it can be recorded, replayed,
or arrive from a network peer, and it means the same thing every time.

The distinction is not "which is more convenient" but **whether reading it
changes anything**. Deltas are consumed; states are observed. Jump is observed;
the *event* of jumping is derived from two consecutive observations, by the
thing that acts on it.

The practical consequence is the one that matters: holding space jumps once. You
have to let go to jump again, which is what stops a held key becoming a hover.
There is a test that holds the key for twenty ticks and asserts exactly one
launch, and a run in the real scene that held it for two and a half seconds and
came back with a peak of 1.16 m and both feet on the floor.

## Ordering, which is the whole bug surface

```gdscript
body.velocity = solve_velocity(state, delta, _sprinting)   # applies gravity
if launching:
    body.velocity.y = MovementSolver.jump_velocity(...)    # then launch
body.move_and_slide()                                      # then move
```

Write the launch before `solve_velocity` and gravity overwrites it in the same
tick — the character twitches and stays put. Write it after `move_and_slide` and
the launch does not take effect until the next tick, which is invisible but
wrong. There is a test for the first of those, because it is the one that looks
like "jump does nothing" rather than like a bug.

No air control, no double jump, no coyote time. Those are decisions this game
has not made, and implementing a jump that works in mid-air would make them for
it. `is_on_floor()` and nothing else.

## The rig lesson: a clip name tells you nothing about its length

The state machine gained a `JUMP` state, chosen by vertical speed, and the
config pointed it at the rig's `Jump` clip. The screenshot came back with the
character clearly airborne, the overlay reading `state jump`, and:

```
rising: state=jump clip= vy=4.30
```

**`clip=` empty.** Nothing playing. The clip existed — there is a test asserting
that — and it had been played.

`Jump` is **0.04 seconds long**, non-looping. A single-frame pose. It plays,
finishes two frames later, and `AnimationPlayer.current_animation` goes empty
while the skeleton holds the final pose. `Jump2`, sitting next to it, is 0.21 s
of actual launch motion. `Fall` is 0.83 s and loops, which is what an airborne
clip should do.

Post 012 wired the clip names by reading them out of the `.glb`, and post 012's
test asserts the named clips *exist*. Neither of those tells you a clip is a
single frame. The config now names `Jump2`.

The general form, worth remembering next time a rig arrives: **existence, length
and loop mode are three separate questions**, and only the first one is obvious
from a list of names.

## The zero-crossing

`JUMP` is chosen when vertical speed is above **0.5 m/s**, not above zero. At the
top of an arc the velocity passes through zero on its way down, and a
zero threshold would flip to the falling clip for a frame or two while the
character is still rising. Same shape of problem as the walk/idle hysteresis in
post 008, same shape of fix.

There is a test that walks a whole arc from +8 m/s down through zero to −8 and
asserts exactly one transition.
