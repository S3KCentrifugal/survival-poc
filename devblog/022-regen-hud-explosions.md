# 022 — Two bars, one delay, and a puff of sparks

*2026-08-05 · commit `669a517`*

Health now comes back on its own, there is a real HUD showing it, and a wanderer
punched enough times stops existing in a shower of orange.

Three small features that mostly reuse things already here, which is the most
interesting thing about them.

## The delay is the feature, not the regeneration

Health regenerates at 3 per second. That part is a line of arithmetic. The part
worth having is the **six quiet seconds before it starts**.

Without a delay, health ticks back up between blows and a fight has no attrition
in it — every exchange starts from full and nothing accumulates. With one,
disengaging is a decision: you either get away for six seconds or you do not.

Stamina has worked this way since feature 6, for exactly the same reason:

> Without the delay, tapping the sprint key is free, because the bar refills in
> the gaps between taps.

The two vitals now behave identically about coming back, which is worth
something on its own. A player who has learned how one works has learned how
both do.

The delay itself is a `Cooldown` — the class post 019 wrote for the punch. That
is the third caller now, and it has needed no changes for any of them, which is
about as good a sign as a small abstraction gets.

## The HUD is not the debug overlay

There has been a readout in the corner since feature 10 showing health, stamina,
position, FPS and the animation state. It would have been easy to call that the
HUD and move on.

It is not, and the reason is who each one answers to. The overlay is for
whoever is *building* the game: it can say anything, it changes whenever a new
system lands, and it is bound to F3 so it can be turned off. The HUD is for
whoever is *playing*: it says two things, it should never surprise anyone, and
pressing F3 must not take your health bar away with it.

They also fail differently. If the overlay is wrong, a developer squints at it.
If the HUD is wrong, a player dies.

So: two bars, bottom left, driven by the `changed` signals rather than polled —
a bar only has to redraw when the number behind it moves.

Two pieces of judgement in it, both of the same kind. Health turns urgent below
30%, because a bar that looks the same at 90% and 9% is a bar you stop reading.
And the stamina bar changes colour while you are locked out, because an actor
who *cannot* sprint should not look identical to one who can — the number alone
does not tell you that, and post 006's exhaustion rule is invisible without it.

Recolouring a bar duplicates its `StyleBox` first. That is post 013's resource
cache trap in UI clothes: both bars were handed styles from the same scene, and
tinting one in place tints the other. There is a test.

## Blowing up

Post 021 left death half-finished on purpose:

> A wanderer at zero health stops moving. That is all that happens... A death
> *system* decides respawning, bodies, loot and whether the world refills.

Asked for explosions, so: `ExplodeOnDeath` listens for `died`, spawns a burst,
and removes the actor. Still not a death system — nothing respawns, drops loot
or leaves a body — but nothing stands there inert either, which was the part
that read as broken rather than as unfinished.

The trap is worth the entry it got. **The burst must be parented to the actor's
parent, never to the actor.** An effect spawned as a child of the thing being
freed is freed with it and lasts exactly zero frames. It would have looked like
the particles not working, and I would have gone looking in the particle
material.

There is a test that asserts a *surviving* explosion is left in the world after
the corpse is gone, which is the only version of that check that would fail if I
got it wrong.

## A guard the test caught

The first version of `explode()` guarded against firing twice with the same flag
the removal cleared:

```gdscript
if _pending or actor == null:
    return
_pending = true
...
if remove_after <= 0.0:
    _remove()     # which sets _pending = false
```

So the second call sailed straight through and exploded again. In practice
`died` only fires once, so nothing would have noticed until something else — a
console command, a scripted death — called it directly.

Two flags now: one for "has gone off", never cleared, and one for "waiting to be
removed", which the removal clears. The general shape is that **a guard the
cleanup switches off is not a guard**, and it is easy to write when the two
meanings happen to coincide on the day you write them.

## Measured

Nine punches to blow up a wanderer. A player at 55 health back to 72 by the time
the delay had run and a few seconds had passed. The HUD showing 0.55 and then
0.72 of a bar, which is the number the player actually sees rather than the one
the component holds.
