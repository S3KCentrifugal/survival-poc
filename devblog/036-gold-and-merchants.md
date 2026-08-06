# 036 — Gold, merchants, and one key with one owner

*5 August 2026 — covers the currency and trading commit*

Gold coins, merchants who are visibly not wanderers, and a shop that opens on F.
The trading was the easy part. The key was not.

## Gold is an item

The obvious way to add currency is a number on the player: a wallet component,
`gold: int`, done in ten lines.

It is an `ItemDefinition` instead, with `max_stack = 999`. That costs one small
file — `Purse`, which wraps "what does this bag hold, can it afford that, take
the payment" — and buys everything else for nothing. Coins stack. They show up
in the inventory with an icon. They can be dropped on the ground and picked back
up, because `world_scene_path` already exists. Merchants carry theirs in the
same `InventoryComponent` the player uses, so *a merchant running out of money*
is the inventory system doing its job rather than a special case somebody has to
remember to write.

A wallet would have been a second system with its own capacity rules, its own
save format, and its own bugs.

## Nobody pays for nothing

`Trade` is static functions over two `Inventory` objects. No nodes. Which is why
the case that actually matters is a test:

```gdscript
func test_a_refused_trade_moves_nothing_at_all() -> void:
```

Every trade is checked in full before anything moves, so there is no partial
state to unwind because there is never a partial state. `Purse.pay` refuses
outright rather than paying what it can — a partial payment leaves the buyer
poorer with nothing to show for it, which is the worst outcome available here.

Two rules are worth calling out:

**A merchant cannot pay past their purse.** They start with 400 gold and that
is all they have. Without it, a field of respawning mushrooms is a money
printer that nobody has to leave the first hill to operate.

**Paying can free the slot the goods land in.** Spending your last coins empties
the gold stack, so a "full" bag can still buy a sword. This is the same rule
crafting uses — three mushrooms in a one-slot bag can become one soup — and
both are the same underlying observation: checking room *before* the payment
refuses trades that would obviously work, and that is a rule nobody can work out
from the outside.

I only counted the case where the payment takes **all** of it. A general answer
needs a simulation of the bag; this one is obviously true or obviously not, and
`_pays_out(held, amount)` says so in one line.

## Two components, one key, both fire

The ask was for merchants on **F**. F was already the pickup key.

The naive version is a second component watching the same key, and it is wrong
in a way you find in about four seconds of play: stand between a mushroom and a
merchant, press F, and you pick the mushroom up *and* open the shop. Neither
press meant that.

So `InteractionRouter` now owns F. It asks `Proximity` across both groups —
at their own reaches, since a person is bigger than a mushroom — takes whichever
is genuinely nearest, and dispatches. `PickupCollector` keeps everything public
it had, including `collect()`; it just stopped watching the keyboard.

The workbench is deliberately *not* in the router. It stays on E, because
operating a fixture is a different verb from walking up to a thing, and a bench
cannot be mistaken for a mushroom at any distance.

The screenshot of this feature has the prompt reading `[F] Pick up Mushroom`
while standing next to a merchant, because a mushroom was closer. That is the
router working, and you fix it by taking one more step toward the merchant.

## The tests that had stopped testing anything

Moving the key broke `test_pickup.gd`, which set `collector.input_source`. Here
is the part worth writing down:

```
SCRIPT ERROR: Invalid assignment of property 'input_source' ...
...
61 suites, 871 tests — all passing
```

**All passing.** A script error inside a test aborts that test's body without
failing an assertion, so five pickup tests were doing nothing at all and the
runner said everything was fine. I caught it because the errors were on screen,
not because anything went red.

That is a hole in the test framework rather than in this feature, and it is now
in `PROGRESS.md` as the next thing worth fixing there: **a suite that logs a
script error should not be able to report success.**

## Distinct merchants, without replacing the model

"Distinct from other wandering characters" is not met by a component nobody can
see. Three things, in increasing order of subtlety: a nameplate that says
Merchant, a gold hat, and a tint.

The tint is `material_overlay`, not `material_override`. An override replaces
the model's materials outright and turns a textured robot into a flat
silhouette; an overlay draws on top, so it is recognisably the same character
wearing a different colour. `ModelTint` walks the tree to find the meshes rather
than naming them, because an imported glb has whatever node structure the
exporter felt like and a scene that names its children breaks on the next
re-export.

There is a test asserting `painted_count() > 0` — a tint that silently found no
meshes looks exactly like no tint.

Merchants also do not wander. A merchant who walks off while you read their
prices is a merchant you stop visiting, and "some of the characters are
merchants" is answered by there *being* merchants among the wanderers, not by
them behaving identically.

## The sixth time

```gdscript
func _own_the_offers() -> void:
```

Two merchants instanced from one scene share their `TradeOffer` resources, and
`stock` lives on the offer. Buy the last sword from one and the other has none
either — which reads as the shop being broken rather than as two nodes pointing
at one resource.

Sixth appearance of the shared-resource trap in this project, and the first time
it was written defensively before being discovered. That feels like the trap
finally being learned rather than survived.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
