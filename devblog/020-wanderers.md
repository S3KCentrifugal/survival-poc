# 020 — Six characters, and the promise from feature 4

*2026-08-04 · commit pending*

Six actors now amble around the world. They walk slowly, stop for a few seconds,
pick somewhere else, and never stray far from where they started.

The feature is small. What makes it worth a post is that it is the moment a
claim made sixteen features ago either paid off or did not.

## The claim

Feature 4 built an input abstraction and justified it like this:

> Nothing outside `PlayerInputSource` may read the `Input` singleton. That is
> what lets an enemy run the player's movement code, a test drive a character
> with no keyboard, and a server eventually receive intent from a client.

Two of those three had been demonstrated. Tests have driven characters since
day one. Nothing had ever run the player's movement code without a keyboard
behind it.

So the honest test of that design was: how much of `MovementComponent` needs to
change to make a wanderer walk?

**None of it.** Not one line. The wanderer's `Wander` produces a direction, a
`ScriptedInputSource` carries it, and `MovementComponent` accelerates, turns and
collides exactly as it does for the player — with the same
`sprint_multiplier`, the same `angle_difference` turning, the same
`is_on_floor()` gravity. The animation state machine picks walk and idle without
knowing anything changed either.

The only new code is the deciding. That is what the abstraction was for, and it
is pleasant to be able to say so with a diff rather than an argument.

## What "wandering" actually needs

Less than it looks, and one thing more than it looks.

The obvious part: pause for a random time, pick a point within a radius of home,
walk at it, stop when you arrive, repeat.

The part that is not obvious until it happens: **give up.** An actor that picks
a destination inside a wall, or gets wedged against one, walks into it forever.
There is no navigation mesh here and no intention of adding one yet, so the
answer is a timer — ten seconds of not arriving and it picks somewhere else.
Without it the world slowly fills with characters pressed against walls, which
is exactly the sort of thing you notice a week later and cannot reproduce.

Two smaller ones:

**Each wanderer needs its own seed.** Sharing a generator makes them pause and
turn on the same frame, and a group moving in lockstep reads as choreography
rather than as life. The spawner hands each one a seed drawn from its own fixed
seed, so they differ from each other and the world still looks the same twice.

**The radius needs a square root.** Picking `randf() * radius` bunches points
toward the middle, because the area of a ring grows with its distance. Six
actors converging on the same spot looks like a bug in the pathing rather than a
bug in the statistics. `radius * sqrt(randf())` spreads them evenly, and there
is a test that samples two hundred destinations and asserts about half land in
the outer half of the circle.

## The trap that did not happen

`WanderComponent` ticks the `Wander` in `_physics_process` and `poll()` only
reports what the last tick decided.

That is deliberate, and it comes straight from post 016. There, look and zoom
were deltas being drained by `poll()`, and two components sharing a source would
each have eaten half the mouse movement. A wanderer's clock is the same shape of
hazard: if polling advanced it, an actor whose source was read by both movement
and something else would wander at double speed.

It cost nothing to avoid because the rule was already written down. That is the
first time in this project a documented trap has prevented a bug rather than
explained one.

## Not enemies

They have no aggression, no targeting, no combat, and nothing to do with the
punch from post 019. The brief keeps enemies out of the slice and this does not
smuggle them in through the back door — it adds characters that exist and move.

Whether a wanderer that notices you is a small change or a large one is a real
question, and the answer is that the *deciding* would be a new `InputSource` and
the moving would still be free. Which is the same claim as before, and now with
some evidence behind it.

## Measured

Twenty seconds in the real world, six actors:

```
Wanderer1 moved  3.97 m, now walking, state=walk
Wanderer3 moved  4.75 m, now pausing, state=idle
...
6 of 6 moved; average 2.76 m in 20s
```

Everyone moved, nobody sprinted off, and they were in different phases of their
own cycles at the end. One of them had let itself into the tower.
