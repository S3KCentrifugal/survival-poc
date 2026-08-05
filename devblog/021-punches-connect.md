# 021 — Punches connect, and π is not π

*2026-08-04 · commit `c222edb`*

Post 019 built a punch that hit nothing, and argued that was the right place to
stop. Two features later there is something worth hitting, so now it connects:
the wanderers take damage, flinch, and stop wandering while they reel.

The interesting part is a floating-point bug that only appears at exactly the
boundary — which is exactly where the test was.

## Being right about where to stop

The seam left in post 019 was a signal:

> `attacked` fires the moment a punch is thrown, and whatever eventually deals
> damage listens to it rather than replacing this.

That turned out to be nearly right and slightly wrong. Damage is not something
that *listens* to the swing — it is part of the swing, because the swing is what
knows where it reached. So `AttackComponent.punch()` now resolves its own hits.

But the shape of the decision held: none of the *reach* numbers existed until
there was something to reach. `reach`, `arc_degrees`, `damage` and `max_targets`
were all chosen by punching a robot, not by guessing two features early. Post
019 said "every one of those thirty lines would have made a decision the game
has not made", and the numbers I picked today are not the ones I would have
guessed then.

## Asking the physics server rather than the scene

Finding what a punch hits could be a walk of every actor in the world, filtered
by distance. It is a sphere query instead, because the physics server already
maintains "what is near what" and asking it scales with the crowd rather than
with the size of the map.

The arc filter then runs on the handful the query returned. Height is thrown
away deliberately: a punch that misses because the target is standing slightly
downhill is worse than one that is generous about height, and this game has
terrain everywhere.

## π is not π

The arc check was one line:

```gdscript
return absf(facing.angle_to(to_target)) <= arc * 0.5
```

A test asserted that an arc opened to a full 360 degrees reaches something
standing directly behind you. It failed, and my first instinct was that the test
was wrong — a half-turn is exactly π, half of 360 degrees is exactly π, and
`π <= π` is true.

It is not, because **`Vector2` holds 32-bit floats**:

```
angle=3.14159274101257324219    <- Vector2.angle_to, 32-bit
half =3.14159265358979311600    <- deg_to_rad(360.0) * 0.5, 64-bit
```

The angle comes back *larger* than double-precision π by about 9e-8. Godot's
vectors are single-precision, so trigonometry on them is single-precision, while
every float in GDScript is a double. The two meet at the comparison and disagree.

What makes this worth writing down is the failure profile. It is invisible
everywhere except at the exact boundary — a 110-degree arc, which is what the
game actually uses, is unaffected. A 180-degree arc would silently fail to reach
the one target standing precisely at the side. The bug lives in the last
0.000006 degrees, so it can only ever be found by a test that asks about the
boundary, or by a player doing something absurd once and never reproducing it.

The fix is a tolerance and a comment explaining why it is not decoration. It is
in `CLAUDE.md` now, because any angle comparison in this project will meet it
again.

## The receiving end

`HurtReaction` listens to `HealthComponent.damaged` and holds a short window
where the actor is reeling. That window does two things at once: the animation
state machine shows the flinch, and the `WanderComponent` stops steering.

It is a separate component rather than a flag on `HealthComponent` because
health owns a number and the rules about that number, and *how long a character
reels* is presentation. The same reasoning that kept clip names out of the
animation state machine.

One rule earned its test. A second hit **restarts** the reel rather than being
swallowed by the first. Without that, punching someone twice quickly looks
identical to punching them once, and "my second punch did nothing" is a bug
report you cannot act on.

In the state machine, hurt beats everything — including your own punch. Landing
a hit on someone mid-swing has to interrupt them, or from their side it did not
land.

## Death is half a feature and says so

A wanderer at zero health stops moving. That is all that happens. The rig has no
death clip, nothing despawns it, nothing loots it — it stands there, inert.

This is the post-019 argument again, and I am taking the same side. A death
*system* decides respawning, bodies, loot and whether the world refills, and
none of those questions have anything to do with "make the wanderers react".
Half a feature that admits it beats a whole one built on guesses.

## Three probe bugs

Worth recording because it is now a pattern. Verifying this took three attempts
and all three failures were in the harness, not the game:

1. A probe that walked the player to the victim, then "corrected" its facing
   with `rotation.y += PI`. Godot's `look_at` already aims **-Z** at the target,
   which is the direction a node faces — so the correction turned the player
   around and every punch missed. It looked exactly like broken hit detection.
2. Before that, spacing clicks on idle frames while the cooldown runs on the
   physics clock (post 017's trap, met again).
3. And pressing and releasing a button inside one frame, so physics never saw it
   held.

The lesson is not "write better probes". It is that a throwaway harness is
*untested code written quickly to check tested code*, and when it disagrees with
the thing it is testing, the harness is the better suspect. Twice now I have
started to believe a real bug on the strength of a probe that was lying.
