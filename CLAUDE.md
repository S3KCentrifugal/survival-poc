# Working in this project

A long-lived 3D survival game. Optimise for the person reading this in a year,
not for finishing the current task quickly.

## Non-negotiables

- **Static typing everywhere.** Parameters, returns, and locals (`:=` counts).
  Typed collections: `Array[Player]`, `Dictionary[int, int]`.
- **Logic separate from presentation.** Anything that can be a plain
  `RefCounted` should be, so it is testable without a scene tree. Nodes read
  that state and draw it.
- **Composition over inheritance.** Components attach to actors. Do not grow a
  base-class hierarchy.
- **Signals outward, never reach upward.** A component must not call
  `get_parent()` to find collaborators.
- **Data in `Resource` files**, not constants scattered through scripts.
- **One responsibility per script**, under ~300 lines where practical.
- **Every feature testable in isolation.** New system, new suite in `tests/`.

## Before you finish

Run `./run_tests.sh`. It must exit 0. If a change is visual, actually look at
it — render a frame and inspect it rather than assuming.

## Traps specific to this project

- **`class_name` globals only resolve after an import pass.** On a fresh clone
  run `godot --headless --editor --quit --path .` first, or every suite fails
  with "Could not find type". `run_tests.sh` and `run.sh` handle this.
- **Test suites run on the first processed frame, not `_initialize`.** Nodes
  added to `root` before the tree is live never enter it, so `_ready` never
  fires. See `tests/framework/test_runner.gd`.
- **`Transform3D(...)` literals in `.tscn` are basis ROWS, not axis columns.**
  Hand-writing one from computed axis vectors gives a transposed (rolled)
  transform. To author a scene without the editor, build the nodes in a
  throwaway script, set transforms with `looking_at()`, and let
  `ResourceSaver.save()` serialize it — correct by construction.
- **A launched game dies when its spawning shell exits.** Use `setsid ./run.sh &`
  when launching from a shell that will close. Godot reports this as a clean
  exit 0, not an error.

## Scope discipline

The vertical slice is deliberately narrow: no crafting, no inventory, no
combat, no enemies, no UI beyond a debug overlay. Build the feature asked for
and stop. Do not add the "obvious next thing" unprompted.
