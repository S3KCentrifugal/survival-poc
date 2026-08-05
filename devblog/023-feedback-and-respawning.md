# 023 — Telling the player what happened

*2026-08-05 · commit `d8f8f4c`*

Three things that all answer the same question in different places: a number
that floats off whatever you hit, a bar over its head, and a world that fills
itself back up so there is something left to hit.

## A fresh cooldown is ready, not waiting

The respawn delay did not work, and the reason is worth more than the fix.

```gdscript
_delay.advance(delta)
if _delay.is_ready() and missing() > 0:
    _replace_one()
```

That reads correctly and is wrong. A `Cooldown` that has never been used is
**ready** — that is what ready means. So the moment a gap appeared it was
already ready, the replacement happened on the spot, and the eight-second delay
only ever applied *between* replacements rather than after a death.

The test caught it because it asked the question in the right order: kill one,
run half the delay, assert the gap is *still there*. A test that only checked
"does it refill eventually" would have passed on the broken version, which is
the same trap as post 015's vacuous assertion.

The fix is to start the wait when the gap appears. What made it easy to get
wrong is that "ready to be used" and "not currently waiting for anything" are
the same state, and only one of them is what the caller meant.

## Where feedback belongs

A damage number could hang off the victim — anything hurt prints what it took —
or off the attacker. It hangs off the attacker, and the reason is the question
being answered. "How much am *I* doing" is the player's question, so it belongs
to the player. A wanderer walking into a wall does not litter the world with
numbers nobody is reading, and if something else ever deals damage it does not
get the player's UI for free.

The health bar goes the other way: it belongs to the *victim*, because "how hurt
is that one" is a property of that one, and any number of things might want to
ask.

Both are parented into the victim's **parent** rather than the victim. This is
the third time this project has met that rule — post 022 hit it with the
explosion — and it is worth stating plainly: **anything that describes a death
cannot be a child of what died.** The killing blow is precisely the feedback you
most want to see, and it is the one frame where the thing you attached it to is
being freed.

## Bars that are not always on

Every actor showing a bar all the time turns a landscape into a spreadsheet. A
bar that appears when you hit something and fades after four quiet seconds
answers the only question you were asking — *is that one nearly done* — and says
nothing the rest of the time.

Two implementation notes that are load-bearing rather than fussy.

**Two billboarded quads, not a `SubViewport`.** The obvious way to get a real
`ProgressBar` into the world is to render one to a texture. That is a render
target per actor, and there are six of them. Two unshaded quads with a scaled
pivot cost nothing and look identical at this size.

**The fill never scales to exactly zero.** A zero scale collapses the basis, and
Godot then warns about a non-invertible transform on every frame the thing is on
screen. `maxf(fraction, 0.0001)` and a comment saying why, because the next
person to see that line will otherwise tidy it away.

## The same trap, three times now

Post 013 found that `load()` caches resources, so mutating one mutates it for
everybody. Post 022 met it again with the HUD's `StyleBox`. This post met it a
third time with the health bar's material: recolouring one bar recoloured every
bar in the world, because they were all handed the same `StandardMaterial3D`
from the same scene.

Three occurrences in ten features is enough to call it a pattern rather than an
accident: **in Godot, a resource reached through a scene or a `load()` is
shared until you duplicate it.** It applies to `.tres` files, theme styleboxes
and material overrides alike, and the symptom is always the same — you change
one thing and something else across the map changes with it.

Each time it has been caught by a test that asserts the *other* one did not
move. That test is cheap and I now write it by reflex.

## Measured

Nine punches to blow a wanderer up, printing `12` each time. Population 6 → 5 on
the death, still 5 a second later, back to 6 about ten seconds after that.
