# 039 — Three components that were one

*6 August 2026 — covers the refactoring pass*

A review of the project turned up drift, most of it from the last six features
and all of it mine. Four things came out of it; this is the one worth reading
about.

## The same component, three times

`PickupComponent`, `WorkbenchComponent` and `MerchantComponent` each declared
their own group and then independently implemented `world_position()`,
`is_available()`, `prompt_text()` and the identical four-line `actor` fallback.
Three groups — `pickup`, `interactable`, `merchant` — three searches, and an
`InteractionRouter` that had to know all three types to dispatch.

Nothing about that was *wrong*. Each component was written when it was needed,
each looked reasonable on its own, and the tests passed. It is what drift looks
like: no single bad decision, and a fourth kind of thing would have meant a
fourth copy of everything.

The split that fixes it is the one composition is for. Being **reachable** is
not the same responsibility as being **pickable**, and it was only ever bundled
in because there was one thing that was both:

```
Mushroom
├── Interactable   (where am I, am I still here, what does the prompt say)
└── Pickup         (what happens when someone takes me)
```

One group. One search. And the router lost its type knowledge entirely — it
calls `interact()` and whoever attached the behaviour has already connected to
the signal. That is what stops this file growing a branch per feature.

`Interactor` and `InteractionRouter` collapsed into one at the same time. They
were 197 lines doing find-nearest-in-group, rising edge on a key,
`target_changed`, dispatch — differing only in *which* group and *which* key,
which are configuration, not types. I wrote the second three features after the
first and never noticed.

## Reach belongs to the thing, not to the reacher

The old router carried `collector.reach` for pickups and `merchant_reach` for
merchants, and had to search twice because the radii differed. Now each
`InteractableComponent` declares its own:

- a mushroom: 2.2 m
- a workbench: 2.6 m
- a merchant: 2.8 m

A merchant is bigger than a mushroom, and that difference is a fact about the
merchant. Moving it onto the thing turned two searches with two radii into one
loop that asks each candidate what its own reach is — and made "widen this
one's reach" a line in a scene file rather than a new export on the router.

## Three panels, one lifecycle

The inventory, the workbench panel and the shop each had a byte-identical
`set_open`: visibility, cursor, input suspension, signals, and after devblog 038
an identical `_input` close handler too. Thirty lines, three times. The bug in
post 038 had to be fixed in all three, which is what duplication costs in the
end.

`ModalPanel` is a component the panels **hold**, not a class they extend. They
are all `CanvasLayer`s already, and a shared base would put a class hierarchy
where this project deliberately has none. Each panel keeps its own contents,
its own signals and its own reason to exist, and delegates the four things that
were never panel-specific.

## The test framework was lying

The other finding from the review, and the one with teeth:

```
SCRIPT ERROR: Invalid assignment of property 'input_source' ...
65 suites, 954 tests — all passing
```

A GDScript runtime error aborts the test body and returns to the runner as
though the method finished. No assertion fails. The run reports success. Five
pickup tests once sat broken behind that for an entire feature.

The runner cannot see it — from inside, an aborted method and a completed one
are indistinguishable. So `run_tests.sh` greps its own output for `SCRIPT
ERROR`, parse errors, leaked instances and resources still in use, and fails on
any of them.

It caught one the moment it was switched on: a workbench test still calling
`_unhandled_input` on a panel whose close handling had moved to `_input` the
day before. And it caught roughly a dozen more during this refactor — every one
a test that had quietly stopped testing anything.

Two smaller notes on that. It is deliberately narrow: tests that provoke an
ordinary `ERROR:` on purpose — a corrupt settings file, a malformed packet —
stay green. And the output is captured with `|| status=$?` rather than a bare
assignment, because under `set -e` a failing command substitution aborts the
script *at the assignment* and takes the output with it, so a failing run
printed nothing at all. Which is worse than not checking.

## What the numbers say

- `pickup_component.gd` 84 → 93 lines, but `workbench_component.gd` 104 → 83
  and `merchant_component.gd` 128 → 111, with a shared 92-line
  `InteractableComponent` replacing three copies of the same three methods.
- `PickupCollector`, `Interactor` and `Proximity` deleted outright — 280 lines.
- Thirty-seven test suites stopped copying the same five lines of mount/free
  scaffolding, now in `TestCase`.
- `scripts/ui/` lost four files that were never UI: a data model, a settings
  store, a `DisplayServer` applier and a command type.

The line count is not the point. The point is that adding a fifth kind of thing
you can walk up to is now one scene edit and one component, and nothing has to
learn about it.

---

Next: [040 — An interface with rules](040-an-interface-with-rules.md). Posts
002–011 and 025–027 are still owed.
