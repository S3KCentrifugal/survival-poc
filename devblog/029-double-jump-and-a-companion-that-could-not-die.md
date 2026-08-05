# 029 — Two jumps, and a companion that could not die

*5 August 2026 — covers the double jump commit*

Two small things this time, and both of them are really about the same thing:
what a component does when nobody told it anything.

## The second jump

`MovementConfig` gains `air_jumps`, defaulting to **0**. The player's `.tres`
sets it to 1.

The default is the interesting part. Every walking actor in the game shares
this config class — the player, six wanderers, the companion. A default of 1
would have handed a double jump to everything that walks, which is not a
feature, it is a surprise. Feature 17's comment said as much when it refused to
guess:

> Air control and double jumps are decisions this game has not made yet, and
> defaulting to "yes" would make them for it.

The decision is now made, and it is made **per actor**, in data.

### Landing is checked every tick, not on the press

The obvious implementation resets the air-jump count when you launch from the
ground. That is wrong twice over:

- **Walk off a ledge and you have nothing.** You never jumped, so nothing ever
  reset the counter — except it was never spent either, so it happens to work.
  Until the second time you fall without jumping, when the count is whatever
  the last airborne stretch left it at.
- **Land and you still have nothing** until you press jump again, because the
  reset was attached to the launch.

So the reset hangs off being grounded, checked on every tick:

```gdscript
var grounded := is_grounded()
if grounded:
	_air_jumps_used = 0
if not pressed:
	return false
```

The state is "how many air jumps have I spent since I last touched anything",
and it is answered by the ground, not by the button.

### The launch replaces vertical velocity

`body.velocity.y = jump_velocity(...)` — an assignment, not a `+=`. This is a
one-character decision with a real feel consequence: a second jump that had to
*overcome* the speed of a long fall would be worth almost nothing at exactly
the moment a player reaches for it. Measured in the running game, a single jump
peaks at 1.16 m and a double at 2.23 m, and a double jump taken while falling
at 12 m/s launches at the same speed as one taken at the apex. There is a test
for that last one, because it is the sort of thing a later "fix" quietly
breaks.

## The test that was testing itself

The jump suite could not run a physics frame — `is_on_floor()` only means
anything after `move_and_slide()` inside one — so it used a subclass that
pretended to be standing on something:

```gdscript
class GroundedMovement:
	extends MovementComponent
	var grounded: bool = true

	func consume_jump(state: InputState) -> bool:
		var pressed: bool = state.jump and not _jump_held
		_jump_held = state.jump
		return pressed and grounded
```

Read that again. It overrides `consume_jump` — **the method under test** — with
a copy of the rule. Every jump test below it was checking that copy. In
particular:

```gdscript
func test_you_cannot_jump_in_mid_air() -> void:
```

...passed by asserting a rule written in the test file, not the one in the
component. The real `consume_jump` could have grown air jumps, lost the rising
edge, or been deleted outright, and this suite would have stayed green.

The fix is to move the seam one level down. `MovementComponent.is_grounded()`
now exists solely so a test can override *where the ground is* rather than
*what jumping means*:

```gdscript
class GroundedMovement:
	extends MovementComponent
	var grounded: bool = true

	func is_grounded() -> bool:
		return grounded
```

Nine tests now exercise the real thing. The lesson generalises: **a test double
should replace what the code depends on, never what the code does.** If the
override contains an `if`, look again — that `if` is the thing you meant to
test.

## The companion that could not die

> "If I kill the character that follows me it doesn't explode, the character
> seems to just stop moving."

That is an exact description of the bug, including the misleading part. The
companion had health, took damage, showed a health bar, and reached zero. It
just had no `ExplodeOnDeath` node. The wanderer scene has one; the companion
scene, written three features later, does not.

What made it read as a *movement* bug is one line in `FollowComponent`:

```gdscript
if hurt != null and (hurt.is_reacting() or not hurt.is_alive()):
```

Following correctly stops when the follower is dead. So a companion at zero
health stands perfectly still — and "stopped moving" is what you see, not
"died". The health bar over its head said 0, and nothing in the world agreed
with it.

This is the bill for composition, and it is worth stating plainly rather than
pretending the architecture has no cost. A missing component is not an error.
Nothing warns. There is no base class whose contract went unfulfilled, because
the entire point is that there is no base class. The actor simply lacks a
behaviour, silently, and the symptom surfaces somewhere else entirely.

The fix is four lines of `.tscn`. The defence is the test:

```gdscript
var explode: ExplodeOnDeath = companion.get_node_or_null("Explode")
assert_not_null(explode, "a companion at zero health would just stand there")
```

Every actor that can be killed should have a test asserting that killing it
does something. That assertion is cheap, and it is the only thing standing
between "composition is flexible" and "composition is a list of things you
forgot".

One consequence worth being upfront about: the companion now blows up **and
does not come back**. `WandererSpawner` tops the wanderer population back up;
nothing does that for the companion, because it is placed in the scene by hand.
Killing your only friend is currently permanent until the next launch.

---

Next: [030 — The sky](030-the-sky.md). Posts 002–011 and 025–027 are still owed.
