# Raising the graphics

A plan for taking this from "programmer art that reads clearly" to something
closer to a first-party Nintendo look, and — the harder half — making that work
something the AI harness can execute without a human in the loop.

---

## Part 0 — What the measurements say, before any plan

Three findings from profiling the current build. Two change the plan.

### The game renders at native resolution on any display, with no cap

This machine's screen is **6144 × 3456 at 221 DPI**. Loading the world applies
the saved display settings, which are fullscreen — so the game renders **21
megapixels**, ten times 1080p. Every screenshot taken this session came back at
that size.

That is a shipping bug, not a measurement artefact. A tester on a 4K or 5K
display gets native-resolution rendering with no render-scale fallback, and the
Steam Deck's 1280×800 is the only target that is safe by accident. **A
resolution and render-scale policy has to land before any graphics feature**,
because every feature added before it makes the cliff steeper.

### Performance cannot be measured here in time at all

| Condition | Result |
|---|---|
| 1080p windowed | 26 fps |
| 720p windowed | 43 fps |
| 1080p, 3D render scale 0.5 | no change |
| vsync disabled | no change |
| **every actor, the terrain and all UI removed** | **30 fps** |

Cost tracks *window* size, not 3D resolution, and survives deleting the entire
scene. Whatever this is measuring — X11 compositing on a 6K desktop, the present
path — **it is not the game**.

The plan was to fix this by measuring the viewport instead of the process, and
Phase 0 tried exactly that. It did not work either. Rendering one shot at three
resolutions through `viewport_get_measured_render_time_gpu()`:

| Resolution | Pixels | Reported GPU time |
|---|---|---|
| 640 × 360 | 0.23 MP | 0.30 ms |
| 1280 × 720 | 0.92 MP | 6.43 ms |
| 3840 × 2160 | 8.29 MP | 2.75 ms |

A thirty-six-fold change in pixels, and 4K reads *cheaper* than 720p. Reversing
the order changed every figure and preserved none of the ordering. Wall-clock
frame time sat at 19–29 ms regardless of resolution, and disabling vsync changed
nothing for a second time.

**There is no millisecond figure available on this machine that means anything.**
The budget is counts instead — see Phase 0 below. That is not a workaround; it is
better, because a count is identical on every machine and in CI, while a
millisecond budget would fail on a different GPU.

### The scene is nowhere near any real budget, and the sun is most of it

Measured per shot, visible pass and shadow pass separately:

| Shot | Visible draws | Shadow draws | Visible prims | Shadow prims |
|---|---|---|---|---|
| `world-noon` | 88 | 155 | 207k | 665k |
| `base-exterior` | 76 | 186 | 194k | 689k |
| `terrain-detail` | 6 | 9 | 131k | 525k |

**The shadow pass draws three to four times the primitives the camera does, in
every shot.** The directional light renders the whole 256-metre heightfield
regardless of where the camera is pointing — which is why a shot of bare ground
with six visible draw calls still costs half a million primitives. Nothing in
the project knew this before there was a harness to ask, and it is the first
real optimisation target, ahead of anything to do with what is visible.

Even so there is enormous headroom for geometry and materials. The constraint on
this project is not the GPU; it is that there is no artist and no way to verify
a look automatically.

---

## Part 1 — What "Nintendo quality" actually means

It is worth being precise, because the target is often misread as "expensive".

Breath of the Wild ran on a tablet with a 2015 mobile GPU. Wind Waker ran on a
GameCube. What makes those games look the way they do is **not** fidelity — it
is *cohesion*: a small number of cheap techniques applied with total
consistency, and an art direction strong enough that nothing looks borrowed.

The techniques that actually produce the look:

| Technique | Cost | What it buys |
|---|---|---|
| Strong directional key + flat ambient | ~free | Readable shapes, no muddy shading |
| Rim / fresnel light | ~free | Separates characters from background |
| Gradient-ramp (toon) diffuse | ~free | The signature flat-but-shaped look |
| Atmospheric perspective (fog by distance) | cheap | Depth, scale, the "vista" feeling |
| Dense vertex-animated foliage | moderate | Life. The single biggest outdoor win |
| Colour grading (LUT) | cheap | Ties every element into one palette |
| Stylised water with foam lines | cheap | Instantly reads as "made, not generated" |
| Silhouette-first shapes | free | Why their characters read at any distance |

Almost none of that is expensive. All of it is *decisions*, which is exactly
what a written art direction is for — and exactly what an autonomous agent
lacks unless it is written down first.

**What this project should not attempt**: photoreal PBR, SDFGI (expensive and
fights a stylised look), heavy post stacks, or anything needing hand-authored
character art. The robot is a CC0 placeholder and will stay one.

---

## Part 2 — The autonomy problem

This is the part the request is really about, and it is a different problem from
gameplay work.

Gameplay correctness is **testable**: `Inventory.add()` returns 3 or it does
not. Graphics quality is **perceptual**, and the current verification loop is
"render a frame and look at it" — which works, but this session alone shows its
limits:

- Timing-sensitive captures kept missing. The heavy-attack shot needed three
  attempts, and the damage numbers had faded by the frame that landed.
- `await process_frame` inside `_process` returns a coroutine, which the
  SceneTree reads as truthy and quits on. Discovered twice, separately.
- Captures without `await` are one frame stale — which at 1 fps is a second.
- A stray desktop keypress opened the pause menu over two shots.
- Every capture was a bespoke throwaway script with hand-tuned frame numbers.

None of that is a graphics problem. All of it is a *harness* problem, and it
will get worse as the visuals get more dynamic. Five things fix it.

### 2.1 A deterministic render harness

One committed tool — not a throwaway script per task — that takes a named shot
and produces a PNG, with:

- **Fixed camera, time of day, weather and RNG seed** per named shot, in a
  resource file. Same shot, same pixels, every run.
- **A settled state**, not a frame number: wait for the sky's radiance to
  converge, animations to reach a chosen keyframe, particles to a chosen age.
- **Deterministic capture**, driven by a physics-frame counter rather than idle
  frames, with the readback stall accounted for.
- **A fixed offscreen viewport** at a fixed resolution, independent of the
  desktop — which also fixes the 6K measurement problem.

Every shot in `devblog/` and every future comparison comes from this.

### 2.2 Golden-image regression

The shots become goldens. A change that alters a frame it should not have is a
failing test. Not pixel-exact — that would fail on driver updates — but a
perceptual difference metric with a stated tolerance, and the diff image written
next to the failure so the reason is visible.

This is what makes "improve the lighting" a safe operation instead of a leap:
the twelve shots that should not have changed are asserted not to have.

### 2.3 Numeric proxies for things that look wrong

Not a substitute for judgement, but they catch the failures that are objective:

- **Luminance histogram** — crushed blacks, blown highlights, a scene sitting
  entirely in the middle.
- **Contrast between the subject and its background** — the same measurement
  `UiTokens.contrast()` already does, pointed at a rendered frame. If the player
  cannot be told from the grass, that is a number.
- **Palette coherence** — how many distinct hues a frame contains. Cohesion is
  most of the target and it is measurable.
- **Silhouette coverage** — the fraction of the character's outline that
  survives against the background.
- **A frame budget in draw calls and primitives**, visible and shadow pass
  separately. Landed in Phase 0. Not milliseconds — see Part 0 for the three
  ways timing was found to measure nothing here.

### 2.4 An art direction document

`ART.md`, in the shape `UI.md` already proved works: name the target, name the
rules, name the sources, and say what is deliberately not done. Without it,
"make it look better" is unfalsifiable and an agent will thrash.

It has to be written **before** the first visual change, and it decides things
an agent cannot decide alone: the palette, the light direction, how stylised the
shading is, whether there are outlines.

### 2.5 An asset policy that needs no artist

Already the project's practice, and it should be stated: **procedural, or CC0
with provenance recorded.** Meshes built by script and serialised
(`items/mushroom.tscn`), textures fetched and downscaled with the source noted
(`assets/terrain/README.md`), icons as SVG. Anything that needs a human to draw
is out of scope until there is one.

---

## Part 3 — The phases

Ordered so that each is independently shippable, verifiable, and does not block
on the next. Every phase ends with goldens updated and the suite green.

### Phase 0 — Make it measurable — **done**

Devblog 042. What landed:

- **`shots.sh` and `ShotRunner`.** Seven named shots as `ShotConfig` resources;
  fixed camera, time of day, RNG seed and player position; its own `SubViewport`
  at the shot's resolution, so a capture is the size it says it is on any
  desktop; settled in physics frames; run under `--fixed-fps 60` so animation
  cannot land on a different frame on a busy machine. Rendered twice in two
  orders: mean difference 0.00%, zero pixels moved.
- **Golden-image regression.** `shots.sh check` fails on a frame that changed,
  and writes actual, expected and an amplified difference image side by side.
  Goldens are committed at 480 × 270. Not in `run_tests.sh` — `--headless` has
  no rendering device — but every piece of logic under it is.
- **A frame budget in counts, not milliseconds**, for the reason in Part 0.
  Draw calls and primitives, visible and shadow, budgeted separately per shot
  from measured figures with headroom.
- **`RenderBudget`.** The 3D scene is capped near 1440p and the interface stays
  native. 1080p, 1440p and the Deck are untouched; 4K renders at 70%, the 6K
  display at 50% — 5.3 megapixels instead of 21.2. On by default, because it
  fixes a bug rather than offering a preference.

Two things were found by building it that no amount of reading would have given:
the GPU timer that measures nothing, and `Window.size` reporting the old size in
the frame a window goes fullscreen — which had the cap computing against a
resolution the game had already left.

### Phase 0.5 — `ART.md` — **done**

Devblog 043. The direction is **painterly and atmospheric**, no outlines, a
neutral palette tinted per region, and a night that is blue and quiet rather
than black. Eight rules, each naming its source, and every rule that can be a
number is one: `FrameLook` measures hue count, crushed and blown fractions, the
range the frame uses, and how far the player separates in luminance from what is
immediately behind them. `shots.sh check` enforces the per-shot targets next to
the golden and the draw-call budget.

Measuring the current build against its own new rules found three things:

- **The character does not read against the world anywhere** — 1.0–1.3:1 against
  a 3:1 target. The blue robot sits at almost exactly the luminance of grass,
  walls and floor, so it separates by hue alone, which is to say by nothing at a
  glance. Largest single failing, and Phase 1's rim light is the answer.
- **Night is absent rather than dark** — 100% of the night frame below the
  readable floor, mean luminance 0.002. There is no ambient term at night.
- **Dusk is already night** — 71% dark at the time of day that should be the
  best-looking in the game.

### Phase 1 — Light and atmosphere — **done**

Devblog 044. `ArtTokens` for the air, `Atmosphere` for the per-elevation
decisions, `AtmosphereComponent` to push them onto the `Environment`. What
landed and what it bought:

- **A night that exists.** 78% of the frame below the readable floor → **14%**.
  The bug was that Godot's sky ambient reads the rendered sky, and this
  project's night sky is black by design, so the ambient at night was in effect
  zero. Below the horizon the ambient now comes from a flat moonlight blue
  instead. Rule 6, met and enforced.
- **A dusk that exists.** 64% → **0%**. The sun's light stops the instant it
  crosses the horizon and the old code took the whole world with it, leaving an
  orange sky over a black ground. Skylight now persists through an afterglow
  band below the horizon, which is what a lit sky dome actually does.
- **Sky-tinted ambient**, so shadows are blue rather than black. Rule 4, and
  visible in `player-close`.
- **Aerial perspective**, fog drawn from the sky's own horizon colour and
  thickened at dawn and dusk. Rule 2 — and the most visible single change in the
  vista shots, where the hills now recede.
- **AgX tonemapping** replacing Filmic, with exposure lifted at night. Day mean
  luminance 0.23 → 0.17, nothing crushed, nothing blown. Rule 7.

**Rim light was on this list and should not have been.** It was listed as the
answer to rule 3 and it is not: the whole environment moved subject contrast by
nothing (1.0–1.3:1 → 1.0–1.2:1), because rule 3 is about mass and a rim is an
edge. It moves to Phase 2 with the materials, where it belongs and where it was
already listed.

Cost: unchanged. Fog, ambient and tonemapping are all free at these counts.

### Phase 2 — A stylised material system *(next)*

One shared shader family replacing per-object `StandardMaterial3D`: ramp-based
diffuse, rim light, triplanar for terrain and cliffs, and a shared palette so
every surface is drawn from the same set of colours. Mirrors what `UiTokens` did
for the interface — the same argument, one layer down.

**It now carries rule 3**, which Phase 1 established the environment cannot
satisfy. The character reads at 1.0–1.2:1 against everything it stands in front
of, against a 3:1 target, because its albedo happens to sit at the luminance of
grass, walls and floor. That is an albedo and shading problem: a value structure
that puts characters and ground in different bands, with rim light on top as an
edge cue rather than as the fix.

### Phase 3 — Foliage and world density

The biggest perceived jump for an outdoor game, and the biggest performance
risk. Grass, shrubs and trees as `MultiMeshInstance3D` scattered from the same
heightfield the terrain uses, with vertex-shader wind and distance fade. Needs
Phase 0's budget to be trustworthy before it starts.

### Phase 4 — Water

A stylised shader: depth-based colour, foam at intersections, a moving normal.
Cheap, high impact, and it gives the terrain somewhere to drain to.

### Phase 5 — Characters

**No outlines.** That was an open question when this plan was written and
`ART.md` has since closed it: outlines expose every facet of a low-poly
silhouette, and the inverted-hull form costs a draw call per object. Separation
comes from luminance instead, which is rule 3 and is measured.

So this phase is ramp shading and a proper rim on the existing rig, plus
whatever it takes to hold 3:1 against every background rather than only against
grass. The robot stays; this is about how it is *lit* and *read*.

### Phase 6 — Effects and juice

Footstep dust, impact bursts, hit flashes, camera shake, a proper explosion.
Small, individually verifiable, and what makes actions feel like they landed.

### Phase 7 — Performance and the Deck

Shadow cost first — it is the larger half of every frame measured, and the
directional light is drawing the whole heightfield. Then LOD, occlusion culling,
a graphics preset for 1280×800, and FSR for displays that still cost too much at
the ladder's floor.

The render-scale ladder itself landed in Phase 0; it did not survive being left
until last, because every feature added before it makes the cliff steeper.

---

## Part 4 — What will not work autonomously

Stated plainly, because a plan that pretends otherwise wastes everyone's time.

- **I cannot judge whether something looks good.** I can measure contrast,
  histograms and palette counts, and I can render a frame and describe it. The
  final call on "is this the right look" is yours, and the plan is structured to
  put that call at phase boundaries rather than inside them.
- **Character and creature design needs a human.** Silhouette is most of what
  makes Nintendo characters work, and it is not derivable from a rule.
- **Sourcing a *coherent* 3D asset set is the real bottleneck.** CC0 assets come
  from many hands and rarely share a look. Procedural generation sidesteps this
  for props and foliage; it does not for characters.
- **Nothing here fixes the absence of an art director.** The plan substitutes
  written rules and measurable proxies for that, which is genuinely better than
  nothing and genuinely worse than a person.
