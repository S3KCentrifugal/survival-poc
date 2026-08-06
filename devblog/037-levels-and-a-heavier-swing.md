# 037 — Levels, and a swing worth waiting for

*5 August 2026 — covers the progression and heavy attack commit*

Experience, levels, a bar on the HUD, and right click doing something worth the
wait.

## A curve, not a table

Thirty levels from three numbers: a first-level cost, a growth multiplier, and a
cap. A hand-written table is fifty numbers somebody has to keep monotonic by
hand, and the day one of them is typed wrong is the day a kill costs you a level.

`ExperienceTable` is a `RefCounted` over that config, which means the properties
worth caring about are assertions rather than something noticed at level 12 by a
player:

- the cumulative curve never goes backwards,
- each level costs at least as much as the last,
- the exact total for level N reads back as level N, for every N,
- a growth of exactly 1.0 still produces a strictly rising curve rather than a
  plateau that makes every level after it instant.

That last one is why the build does `maxi(int(round(cost)), 1)` — a plateau is
the failure mode of a curve, and it costs one `maxi` to make impossible.

**A capped character shows a full bar, not an empty one.** `progress()` returns
1.0 at the cap. An empty bar at max level looks exactly like a character who
just levelled and lost their progress, which is a support ticket rather than a
feature.

## Experience from damage, not only kills

`per_damage: 0.5` and `per_kill: 25`. A wanderer is 100 health, so killing one
is 50 from damage plus 25 for the finish.

Splitting it that way does two things. A fight you lose is still worth
something. And — the reason it is actually right — the number moves *while you
are watching it*. A bar that only jumps on a kill tells you nothing during the
fight, which is precisely when you are looking at it.

The kill bonus needed a signal, and where it lives is the interesting bit:

```gdscript
## Emitted when a blow takes something from alive to not.
##
## Here rather than on the victim, because the interesting question is *who*
## killed it -- and the attacker is the only one holding both ends of that.
signal killed(target: Node3D)
```

`HealthComponent` already has `died`, and it would have been easy to listen to
that. But `died` cannot say who did it, and a victim that broadcasts its death
to everyone means every listener has to work out whether it was *their* kill.
The attacker knows, because it asked `is_alive()` either side of its own blow.

Levels are announced **one signal per level crossed**, in order. A single kill
that crosses two levels emits twice, because a UI that plays a fanfare should
play two.

## The rig already had a kick

"Make it clear from the animation it is a stronger attack" is not answered by
playing the punch slowly. It is answered by a different move — and reading the
clip list off the imported rig rather than assuming turned up `Kick`, 1.29 s,
sitting next to the 1.21 s `Attack1` that the punch uses.

That is the second time this project has got something for free by looking at
what the asset actually contains. It is worth making a habit of.

The heavy is a trade in four directions, and every one of them has a test
asserting the *relationship* rather than the number:

| | Light | Heavy |
|---|---|---|
| Damage | 12 | 34 |
| Cooldown | 0.35 s | 1.15 s |
| Reach | 1.8 m | 2.3 m |
| Arc | 110° | 70° |
| Stamina | free | 25 |

Further but **narrower**, because a heavy that also forgives your aim is
strictly better in every way and there is no decision left to make. The cooldown
is long enough to show most of the 1.29 s kick rather than cutting it into a jab
the way the punch's 0.35 s deliberately cuts `Attack1`.

Stamina is a refusal, not a weakening. A heavy that quietly becomes a light one
when you are tired is a heavy you cannot rely on, and "why did that do 12" is a
worse question than "why did nothing happen".

### The exploit that writes itself

```gdscript
func punch() -> bool:
	if not _heavy_cooldown.is_ready() or not _cooldown.use():
		return false
```

Without that first clause you throw a heavy, then immediately jab, and the jab's
short cooldown means you have paid none of the heavy's recovery. Cancelling a
committed animation with a cheap one is the standard way this gets broken in
games that have this pair of moves, and it costs one condition to close.

Holding both buttons throws the heavy. It is checked first on purpose — the one
that costs something should win, not the one that happens to be earlier in the
function.

## The bug the new binding exposed

Right click was free. Now it is an attack, and that immediately made a latent
bug visible: opening the inventory, the shop or the bench released the *cursor*
but not the keyboard. The character was still fully playable behind the panel.

Harmless while the only bindings were keys you would not press with a panel
open. Not harmless once clicking a "Sell" button also kicks whoever is standing
behind it.

The mechanism already existed — `set_input_suspended`, written for the chat box
in feature 35, which had exactly this problem with typing. All three panels now
call it alongside `set_mouse_captured`, and there is a test that opens each and
asserts both that input is suspended and — the half that actually bites — that
closing it gives the keyboard back.

Two features apart, the same mistake, and the second one only showed up because
an unrelated button changed meaning. Worth remembering that "released the
cursor" and "stopped listening to the player" are different things.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
