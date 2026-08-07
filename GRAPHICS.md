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

### Performance cannot currently be measured here

| Condition | Result |
|---|---|
| 1080p windowed | 26 fps |
| 720p windowed | 43 fps |
| 1080p, 3D render scale 0.5 | no change |
| vsync disabled | no change |
| **every actor, the terrain and all UI removed** | **30 fps** |

Cost tracks *window* size, not 3D resolution, and survives deleting the entire
scene. Whatever this is measuring — X11 compositing on a 6K desktop, the
present path, the harness itself — **it is not the game**, and I cannot tell a
graphics regression from noise with it.

Every number a graphics plan depends on comes from this measurement. Fixing it
is Phase 0 and nothing meaningful can be judged before it.

### The scene is nowhere near any real budget

109 draw calls, 728k primitives, 291 objects, 452 MB of textures. There is an
enormous amount of headroom for geometry and materials. The constraint on this
project is not the GPU; it is that there is no artist and no way to verify a
look automatically.

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
- **A frame budget**, once 2.1 makes it measurable.

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

### Phase 0 — Make it measurable *(prerequisite)*

Render harness, golden images, frame-budget measurement, and the
resolution/render-scale policy that the 6K finding demands. Adds no visible
polish and everything else depends on it.

### Phase 1 — Light and atmosphere *(largest win, no assets)*

Environment work only: tonemapping (AgX or ACES rather than the current
Filmic), exposure, a colour-grading LUT, distance fog tuned per time of day,
SSAO, subtle bloom on highlights only, and a proper three-point-ish rig — key
sun, sky ambient, and a bounce term.

This is where a scene stops looking like a renderer and starts looking like a
place. It costs no art and it is fully within an agent's reach because every
knob is a number in a resource.

### Phase 2 — A stylised material system

One shared shader family replacing per-object `StandardMaterial3D`: ramp-based
diffuse, rim light, triplanar for terrain and cliffs, and a shared palette so
every surface is drawn from the same set of colours. Mirrors what `UiTokens` did
for the interface — the same argument, one layer down.

### Phase 3 — Foliage and world density

The biggest perceived jump for an outdoor game, and the biggest performance
risk. Grass, shrubs and trees as `MultiMeshInstance3D` scattered from the same
heightfield the terrain uses, with vertex-shader wind and distance fade. Needs
Phase 0's budget to be trustworthy before it starts.

### Phase 4 — Water

A stylised shader: depth-based colour, foam at intersections, a moving normal.
Cheap, high impact, and it gives the terrain somewhere to drain to.

### Phase 5 — Characters and outlines

Inverted-hull or depth-edge outlines, better shading on the existing rig. The
robot stays; this is about how it is *lit* and *read*, not replacing it.

### Phase 6 — Effects and juice

Footstep dust, impact bursts, hit flashes, camera shake, a proper explosion.
Small, individually verifiable, and what makes actions feel like they landed.

### Phase 7 — Performance and the Deck

LOD, occlusion culling, a graphics preset that targets 1280×800 at 60 fps, and
the render-scale ladder for high-DPI displays.

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
