# 019 — A punch that hits nothing

*2026-08-04 · commit `eeaef61`*

Left click throws a punch, one every 0.35 seconds however fast you click. It has
no hit detection, deals no damage, and has no target. That is not an oversight —
it is the feature, and being clear about the difference is most of this post.

## The swing is not the combat

`AttackComponent` produces an intent, enforces a rate limit, and gives the
animation something to show. What it does *not* do is decide that something got
hit, because that is combat, and combat is explicitly out of the slice.

The temptation was to add a hitbox "while I'm here". It would have been maybe
thirty lines: a shape in front of the character, an overlap query, a call to
`HealthComponent.take_damage`. And every one of those thirty lines would have
made a decision the game has not made — how far the reach is, whether it hits
multiple targets, whether it hits through walls, what damage even means when
nothing else deals any.

So the seam is a signal. `attacked` fires the moment a punch is thrown, and
whatever eventually deals damage listens to it rather than replacing this. That
is one line of extension surface instead of thirty lines of guesses.

## Cooldown as its own thing

The rate limit could have been a float on the component:

```gdscript
_remaining = maxf(_remaining - delta, 0.0)
```

It is a small class instead, because eating, crafting, reloading and every other
unspammable thing wants exactly this, and I would rather get the edges right
once. The edges being: a huge delta from a loading hitch must not leave a
negative wait that counts *back up* to ready, a zero duration must not divide by
its own zero when asked for a fraction, and counting down must be frame-rate
independent.

The one design decision in it is that `use()` checks and starts the wait in a
single call:

```gdscript
func use() -> bool:
	if not is_ready():
		return false
	remaining = duration
	return true
```

Two calls — `is_ready()` then `start()` — invite the bug where something asks
permission, acts, and forgets to say it acted. One call cannot be half-used.

## The cooldown is also the punch

`AttackComponent.is_attacking()` reads off the cooldown rather than keeping a
second timer. That is deliberate: two timers can disagree, and the failure mode
is a character stuck mid-swing or one who punches invisibly.

It does mean the rig's 1.21 s swing is cut into a 0.35 s jab, which sounds like
a bug and is the intent. A punch you have to wait out is not a punch you would
click twice, and "very brief cooldown" was the ask. Raising `cooldown` gives you
the fuller swing and the slower rate together, which is the honest relationship
between the two.

## Two seams that needed thought

**Punching beats locomotion.** The animation state machine can express one thing
at a time, so `PUNCH` takes priority and punching while running replaces the run
instead of blending over it. That is visibly crude. The right fix is an
`AnimationTree` with an upper-body blend, which is a real feature rather than a
line, and the rig is a placeholder anyway. Written down rather than pretended
away.

**The click that recaptures the cursor must not punch.** Escape opens the menu
and releases the mouse; resuming takes it back; alt-tabbing releases it too. The
click that gives the cursor back to the game is aimed at the *window*, not at
whatever is standing in front of you. `PlayerInputSource` now swallows attack
until the button comes back up after a capture.

That is a small thing that would have felt like a bug and been almost impossible
to describe: "sometimes it punches when I click back in". Worth spotting before
shipping rather than after a bug report.

## Held is one punch

Same rule as jump: holding the button throws one punch and you have to release
to throw another. The cooldown *would* have made auto-repeat safe, and plenty of
games do it — so this is a choice rather than a constraint, and `AttackComponent`
is one line from the other behaviour if it turns out to feel better with a mouse
in hand.

## Measured

Clicking every other frame for two seconds, with the cooldown at 0.35 s:

```
clicked every other frame for 2s -> 6 punches (cooldown 0.35s)
```

Two seconds divided by 0.35 is 5.7. Six punches is the rate limit doing exactly
its job and not one swing more.
