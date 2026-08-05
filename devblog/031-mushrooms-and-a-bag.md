# 031 — Mushrooms, and somewhere to put them

*5 August 2026 — covers the inventory commit*

The scope note in `CLAUDE.md` has said "no crafting, no inventory" since the
first commit. That was the right call for a vertical slice about movement, and
it stopped being the right call the moment there was something in the world
worth bending down for.

Four pieces: a thing to pick up, a rule for holding it, a way to ask, and a
screen to look at.

## Where the rules live

`Inventory` is a plain `RefCounted`. No nodes, no signals, no scene tree. This
matters more here than almost anywhere else in the project, because stacking is
made entirely of edge cases that are miserable to check by hand:

- Twelve mushrooms picked one at a time must be **one** slot, not twelve.
- A partial stack must be topped up before a fresh slot is opened, or a bag
  fills with air.
- A stack of twenty overflows into the next slot rather than capping.
- A pickup that only half fits must **leave the rest behind**.

That last one drove the signature. `add()` returns the number that did *not*
fit:

```gdscript
func add(definition: ItemDefinition, amount: int = 1) -> int:
```

Zero means it all went in. A `bool` cannot express "two of your three went in",
so a bool would have quietly deleted the third — and a mushroom that vanishes
because you were full is worse than one you could not pick up.

`test_inventory.gd` has nineteen tests and not one of them builds a node.

## Removing drains the smallest stack first

A detail nobody asks for and everybody notices the absence of. With eight
mushrooms held as 5 + 3, taking two out should leave one stack of five, not
5 + 1. Draining the smallest first closes half-empty slots instead of
multiplying them.

The other half of that: **an emptied slot stays where it was.** Items sliding
around the grid whenever you use one is infuriating in a way that is hard to
argue with afterwards, so `Inventory` never compacts.

## A group, not an Area3D

The Godot-shaped answer for "is something within reach" is an `Area3D` with a
collision layer. What is here instead is a group and a distance check:

```gdscript
static func nearest(from: Vector3, candidates: Array, reach: float) -> PickupComponent:
```

Static, taking its candidates as an argument. Which means choosing between two
mushrooms is a test with three positions in it, no physics frame, no collision
layers to get wrong, and no `_physics_process` to wait for. At fourteen
mushrooms the scan costs nothing. A world with thousands of loose items wants a
spatial index, and that is the day this becomes an `Area3D` — it is not today.

The distance is squared throughout, and it is measured in three dimensions on
purpose: a mushroom on a roof is not in reach of someone standing under it.

## F is intent like any other

The interesting part of adding a key is how little had to change. `InputState`
gained one bool; `PlayerInputSource` gained one `Input.is_action_pressed`;
`ScriptedInputSource` gained one setter. `PickupCollector` takes an
`InputSource` exactly as movement does, so a test drives it with no keyboard
and a remote player will drive it with no local machine.

The wire protocol needed one line:

```gdscript
## Bit 3 of a byte that already had five spare. The packet is the same ten
## bytes in the same order, so VERSION does not move.
const BUTTON_INTERACT: int = 1 << 3
```

Feature 26 spent a while on a fixed-layout binary format with a spare-bit
budget, and this is the first time that budget got spent. An older peer never
sets the bit, which decodes as a player not pressing F — a graceful default
rather than a version negotiation.

The rising edge is spotted in the collector, same as jumping and punching:
holding F must not clear a whole patch.

## Two bugs the tests found before the game did

**`collect()` did not look before taking.** It used a target that some earlier
`step()` had found, so called on its own — from a console, or a test — it
picked up nothing and reported success at zero. Its own docstring said "picks
up whatever is in reach", which was a lie about a method that required an
undocumented call to have happened first this frame.

**`capacity` was read once, in `_ready`.** Setting it afterwards did nothing at
all, silently. It is a setter now, applied whenever it is written. A property
that only takes effect if you happen to write it before `_ready` is a property
that does nothing for half its callers.

Both were found by tests that were *trying to set up a scenario*, not by tests
aimed at those methods. That is the usual way: the arrangement is where the API
gets used the way a stranger would use it.

## Growing, not appearing

`MushroomGrowth` scales the model from 8% to full over two and a half seconds.
That is the entire implementation of the word "grow" and it does most of the
work: a thing that pops into existence at full size reads as a spawner firing.

Two decisions attached to it:

- **The first crop starts full size.** A world that opens on a field of
  seedlings looks like someone planted it as you arrived.
- **A half-grown mushroom is a real mushroom.** Collection does not wait for
  the animation. Making the player wait for a lerp to finish is a rule nobody
  enjoys discovering.

`MushroomPatch` is deliberately the same shape as `WandererSpawner` — scatter,
keep clear of the buildings, top back up after a delay — because a reader who
has understood one has understood both. It also copies the respawner's
`_waiting` flag rather than rediscovering the bug behind it: a fresh `Cooldown`
is *ready*, not waiting, so without the flag the first mushroom picked is
replaced on the spot.

That is the fifth caller of `Cooldown` now. Punching, stamina recovery, health
regen, wanderer respawn, and mushrooms.

## The bag does not pause the game

The pause menu pauses because it is a menu *about the game*. The inventory is a
screen about your character, and in multiplayer a bag that stops the world
cannot exist. It releases the cursor — a grid you cannot click is not a grid —
and it is `PROCESS_MODE_ALWAYS`, so if something else ever pauses while it is
open it does not become uncloseable.

Cells show a colour swatch and a count, no name. There is no item art yet, and
a coloured square is honest about that in a way a missing-texture checkerboard
is not. An item name in an 84-pixel cell is three characters and an ellipsis,
which tells you less than the colour already did; the full name is in the
tooltip.

Each cell builds its **own** `StyleBoxFlat`. Sharing one would have been the
fifth appearance of the trap in `CLAUDE.md` — recolouring a slot would recolour
every slot.

---

Next: [032 — Dragging things out, and three ways to
leak](032-dragging-things-out.md). Posts 002–011 and 025–027 are still owed.
