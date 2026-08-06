# 038 — A shop you could not leave

*6 August 2026 — covers the input fix commit*

> "I am unable close out of the merchant dialog. F doesnt escape, and the esc
> key brings up the menu"

Two separate bugs wearing one costume, and the second one is the interesting
one. Both were mine, both were introduced by earlier features, and neither had a
failing test — the suite was green through all of it.

## Escape went to the wrong listener

`_unhandled_input` is delivered in **reverse tree order**: the last node in the
scene gets the event first. The end of `main.tscn` runs

```
InventoryScreen, CraftingScreen, StoreScreen, ChatBox, PlayerHud,
DebugOverlay, DevConsole, PauseMenu
```

so `PauseMenu` is handed Escape before any of the panels, calls
`set_input_as_handled()`, and the shop never hears about it. The menu opens
*over* the open shop, exactly as reported.

Nothing about that is visible in either file. `StoreScreen` handles Escape and
looks correct; `PauseMenu` handles Escape and looks correct; which one wins is
decided by a line in a `.tscn` that neither mentions. That is an invisible
dependency, and betting behaviour on it is a bad trade.

The fix is the one the dev console already used, for the same reason: an open
modal panel takes its close key in `_input`, which runs before all of
`_unhandled_input` regardless of who sits where.

```gdscript
func _input(event: InputEvent) -> void:
	if not visible:
		return
```

Closed panels cost one comparison. The inventory keeps *opening* on
`_unhandled_input` — typing "inventory" into the dev console should not open the
bag five times — and only *closing* moved.

## F was worse

F genuinely closed the shop. Then it opened it again, every frame, for as long
as the key was down.

Feature 37 added `set_input_suspended` to the panels, so the character is not
playable behind an open shop. A suspended `PlayerInputSource` reports every
button as released:

```gdscript
func poll() -> InputState:
	var state := InputState.new()
	if suspended:
		return state
```

And every consumer spots a press as a **rising edge** — held now, not held last
tick. So:

1. F down. The router sees the edge, hails the merchant, the shop opens, input
   suspends.
2. While suspended, `poll()` reports `interact = false`, so the router's
   `_held` flag goes false. The key is still physically down.
3. F's key *event* reaches the panel, which closes and unsuspends.
4. Next frame: `interact = true`, `_held = false`. **That is a rising edge.**
   The shop opens again.

An open/close flicker for as long as you hold F, settling open when you let go.
Which is to say: a shop you cannot leave.

The fix belongs in the source, because the source is what lied:

```gdscript
var suspended: bool = false:
	set(value):
		if suspended and not value:
			_swallow_held()
		suspended = value
```

On resume, every edge action still physically down is ignored until it comes
back up. Only the edge actions — movement and sprint are asked "are you held",
so continuing to walk when a panel closes is correct, and swallowing those would
strand the player until they let go of W.

There was already a special case doing exactly this shape for exactly this kind
of reason: `_swallow_attack`, added in feature 21, which eats the click that
recaptures the cursor so it does not also throw a punch. That should have been
the clue. One-off swallowing of a stale press is a general problem, and it now
has a general answer.

## What I take from it

The suite was green for both of these, and I had rendered a screenshot of the
shop working. Neither caught it, because both bugs need a *sequence*: a key held
across a state change, or two nodes competing for one event. A single call
proves neither.

The tests written for the fix are all sequences — hold, release, hold again;
open a panel, press Escape, assert the *other* thing did not happen. There is
also one asserting Escape still opens the pause menu when nothing else is open,
because that is precisely what a fix like this breaks next.

Both traps are now in `CLAUDE.md`. The second one is the one I would most like
the next person to have read:

> Suspending an input source resets every rising edge. A key held while
> suspended reads as a fresh press the moment it resumes.

---

Next: [039 — Three components that were
one](039-three-components-that-were-one.md). Posts 002–011 and 025–027 are still
owed.
