# 042 — A harness that measures itself

*7 August 2026 — covers the Phase 0 graphics-harness commit*

`GRAPHICS.md` proposed seven phases of visual work behind a Phase 0 whose whole
job was to make the other seven checkable: a repeatable screenshot harness,
golden-image regression, a frame budget, and a fix for the finding that the game
renders at whatever resolution the monitor happens to be.

Three of those four landed as designed. The fourth — the frame budget — was
built on a premise that turned out to be false, and finding that out was the
most valuable thing the harness did all day.

## The plan for the budget, and why it was wrong

The profiling that motivated `GRAPHICS.md` had produced numbers that made no
sense: 26 fps at 1080p, 43 at 720p, no change from halving the 3D render scale,
no change from disabling vsync, and **30 fps with every actor, the terrain and
the entire interface deleted**. Cost tracked the size of the window and survived
deleting the game.

The diagnosis was that frames-per-second measures the process, and the process
here is mostly a compositor pushing pixels around a 6K desktop. The prescription
followed: measure the *viewport* instead, through
`RenderingServer.viewport_get_measured_render_time_gpu()`, which is the
renderer's own timing of the thing being changed.

The harness reported 0.5 ms for whichever shot ran first and 4–7 ms for every
shot after it. The images were byte-identical, so the cheap one was not drawing
less. I guessed at a warm-up problem, added a throwaway viewport before the
first real one, and it changed nothing.

So I stopped guessing and rendered one shot at three resolutions:

| Resolution | Pixels | Reported GPU time |
|---|---|---|
| 640 × 360 | 0.23 MP | 0.30 ms |
| 1280 × 720 | 0.92 MP | 6.43 ms |
| 3840 × 2160 | 8.29 MP | 2.75 ms |

A thirty-six-fold change in pixels, and 4K reads *cheaper* than 720p. Reversing
the order changed every number and preserved none of the ordering. Wall-clock
time per frame sat between 19 and 29 ms regardless of resolution, because this
machine cannot present a frame faster than that whatever is in it. Disabling
vsync changed nothing, which is the second time that has been true.

There is no millisecond figure available on this desk that means anything.

## What replaced it

Counts. `RenderingServer.viewport_get_render_info()` reports draw calls,
primitives and objects for a viewport, split into the visible pass and the
shadow pass. Those numbers are exact, reproducible to the unit, identical on
every machine, and they are what actually moves when geometry is added — which
makes them a better budget than milliseconds even where milliseconds work,
because a golden that fails on a different GPU is a golden nobody keeps.

They also immediately said something nobody in this project knew:

```
terrain-detail            6 draws +   9 shadow    131k prims +  525k shadow
world-noon               88 draws + 155 shadow    207k prims +  665k shadow
```

**The sun draws three to four times as many primitives as the camera does**, in
every shot. It renders the whole 256-metre heightfield regardless of where the
camera is pointing — which is why the shot of bare ground, with six visible draw
calls, still costs half a million primitives. Nobody had looked, because nothing
had asked. It is now budgeted separately in every shot, and a change that
quadruples it fails the check.

A plausible number that means nothing is worse than no number, because somebody
will quote it. The millisecond figure is gone from the tool's output entirely.

## The 6K bug, and the one that was hiding behind it

The game set `Viewport.scaling_3d_scale` from a settings slider that defaults to
1.0, and never looked at the display. On this machine — 6144 × 3456 — going
fullscreen asked the renderer for **21 megapixels**, ten times 1080p. Every
screenshot taken during the previous four features came back at that size and
nobody noticed, because it looked correct.

`RenderBudget` caps the 3D render resolution at roughly 1440p and leaves the
interface at native size. 1080p, 1440p and the Steam Deck are untouched; 4K
renders at 70%, and this display at 50%. The scale comes off a six-rung ladder
rather than a continuous curve, so two machines can quote comparable numbers.
The floor at 0.5 is deliberate: below that, bilinear upscaling is visibly soft
and the answer is FSR, which is a Phase 7 decision rather than a smaller number.

Writing that, I left a note on `output_size()` saying the call order in
`apply()` mattered — ask before going fullscreen and you get the old windowed
size. Then I checked it instead of trusting it, which is how I found that asking
*after* going fullscreen gives the old size too:

```
Borderless fullscreen   window.size=(3840, 2160)   screen=(6144, 3456)
```

`Window.size` does not update in the frame the mode changes. The cap was being
computed for a resolution the game was no longer at, and the failure is
invisible — fullscreen works, the game runs, the scale is merely wrong. It now
asks the *settings* which surface is about to be filled and only falls back to
the window when there is nothing to ask. The decision is a pure function of two
sizes, so it is tested without a display.

## Determinism, which is most of the value

A shot is a resource: camera, target, field of view, time of day, RNG seed,
where the player stands, whether the interface is drawn, how many physics frames
to settle for, how many to count over. The runner freezes the clock, seeds the
RNG *before* the scene is instantiated, points the settings at a path that does
not exist so a saved fullscreen preference cannot reach the window, releases the
cursor, and renders into a `SubViewport` at the shot's own resolution — which is
what makes a capture the size it says it is on any desktop.

`shots.sh` runs it with `--fixed-fps 60`. Without that, every frame advances by
however long the last one really took, so animation and particles land somewhere
slightly different on a busy machine and a golden fails for the crime of the
desktop being busy.

Seven shots, rendered twice, in two different orders: **mean difference 0.00%,
zero pixels moved.** That is the number the next seven phases rest on.

## Three shots that were wrong, and were blessed anyway

The harness worked, was deterministic, passed its own checks, and three of its
seven shots were photographs of the sky.

The camera positions were written as world coordinates. The player is *dropped
onto the terrain*, and the terrain is a heightfield — at the spawn point the
ground is at y = 3.3, not 0. So a camera placed at y = 1.6 to frame a character
standing at chest height y = 1.2 was a metre and a half underground, looking up
through back-faced terrain at a pale blue sky.

Every check passed. The shot had a real camera, a real target, a settled world
and a plausible image; `ShotConfig.problems()` had nothing to object to, because
none of the things it knows how to check were wrong. A picture of the sky is not
black. And the goldens were blessed from it, so from that moment the regression
net was asserting that the sky had not changed.

It was caught by opening the PNG and looking at it, which is the one step no
amount of harness removes.

Two changes came out of it. `anchor_to_player` reads the camera position and
target as offsets from wherever the player ended up standing, so a shot about a
character cannot be broken by the terrain moving under it. And
`must_show_player` fails the shot outright when the player is not inside the
camera frustum — the only check available that could have caught this, because
it is the only one that asks whether the thing the shot is *about* is in front
of the camera.

The same look-at-it pass found the debug overlay in the gameplay shot, drawing a
live `fps 52` in the corner: a number guaranteed to differ on every run. The
developer tools are now hidden in every shot regardless of what it asked for.
`UI.md` already exempts them from the design system on the grounds that they are
not the game, which turns out to be the same argument.

## What the previous forty-one features paid for this

Every screenshot before today was a throwaway script with a hand-tuned frame
number. The bill, from one afternoon:

- `await process_frame` inside `_process` returns a coroutine, which the
  SceneTree reads as truthy and quits on. Found twice, in two separate scripts.
- A capture without the `await` is one frame stale, which at these frame rates
  is most of a second.
- The heavy-attack shot needed three attempts and still lost its damage numbers
  to a fade.
- A stray keypress on the desktop opened the pause menu over two shots.

None of that is a graphics problem, and none of it would have been fixed by
being more careful the next time.

## What is deliberately not here

**Goldens are not in `run_tests.sh`.** `--headless` has no rendering device;
`root.get_texture()` returns null and the run dies several frames later on a
null parameter. The suite covers the logic — the comparison, the statistics, the
cap, the shot validation, and the freeze — and `shots.sh check` covers the
pixels. That split is not a compromise, it is the only shape available.

**Goldens are stored at 480 × 270, not full size.** They are committed, and this
repository stays small on purpose. A regression that survives a 4.7× Lanczos
downscale is not a subtle one. Lanczos rather than bilinear because bilinear
discards most of the pixels it is handed, so two frames differing in fine detail
can resize to the same image and pass a test they should fail.

**A missing golden fails rather than blessing itself.** Otherwise the first run
after a regression records the regression as correct.

**No `ART.md` yet.** It is the next thing `GRAPHICS.md` asks for and it is the
one that needs decisions rather than code — the palette, the light direction,
how stylised the shading is, whether there are outlines. An agent cannot pick
those alone, and a phase of visual work without them would be unfalsifiable.

---

Next: `ART.md`, then Phase 1 — light and atmosphere.
