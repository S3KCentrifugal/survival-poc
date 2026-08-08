# 046 — Something to stand in

*7 August 2026 — covers the Phase 3 foliage commit*

The world has been a textured heightfield with four buildings on it since
feature 6. This is the phase that puts something on it: grass, shrubs and trees,
scattered from the same heightfield the terrain is built from, with wind in the
vertex shader.

It is also the first phase with a real cost, and the first one where the budgets
built back in Phase 0 did the job they were built for.

## The thing I did not expect it to fix

`ART.md` rule 3 — a character sits at least 3:1 in luminance against what is
immediately behind them — has been the largest open failing since post 043.
Phase 1 moved it by nothing. Phase 2 built a value structure and got it from
1.0:1 to 2.5:1, which I wrote up as "most of the way there", with the remaining
gap blamed on tonemapping and on the robot's inherently pale albedo.

Grass finished it. `player-close` measures **3.5:1**.

In hindsight it is obvious and I had the wrong model of the rule. A value band
changes what the *character* is. Foliage changes what is *behind* the character,
and the rule is about the pair. Darkening the ground with something growing on
it did what darkening the ground with a palette could not, because the palette
route ran into night readability — post 045's tension, where taking the ground
band from 0.045 to 0.038 sent the night frame from 15% below the readable floor
to 67%. Grass sidesteps that entirely: it is dark geometry sitting *on* a ground
that is still bright enough to see by at night.

Two phases and a rule I had already declared "as good as it gets".

## What it cost, and what keeps it bounded

A vista went from 88 visible draw calls to 158, and from 207k primitives to
348k. That is a real increase and it is the first time this project has had one.
Three decisions keep it from being much worse.

**Chunking.** A `MultiMesh` has exactly one bounding box, so twenty thousand
clumps in a single instance are either all drawn or all culled — a camera
looking away from the meadow pays for it in full. Split into 16-metre chunks,
the renderer has something to cull with: the close shot draws 36 calls where the
vista draws 158, from the same field.

**Grass casts no shadow.** The shadow pass already draws two to four times what
the camera does. Letting the densest thing in the world into the shadow map
would have been the most expensive single decision available, in exchange for
shadows a few pixels across. Trees do cast, because they are few and large
enough that missing shadows would read as the trees not really being there.

**A visibility range.** Grass stops at 78 metres and fades out over the last
quarter of that. Anything that casts a shadow fades *hard* instead, because a
dithered fade is an alpha effect and alpha is what silently stops a material
casting shadows at all — post 045's most expensive bug, avoided this time by
knowing about it.

One invariant broke, and it is worth recording: the shadow pass is no longer the
larger half *in draw calls*. Foliage adds seventy visible calls and casts
nothing, so on the close and night shots the camera now issues more calls than
the sun. The **primitive** count still holds the old order, and it was always
the number that mattered. The test that encoded the old observation now asserts
the durable one.

## Three bugs, and one of them was in the test

**A `MultiMesh` keeps nothing in a headless run.** The test that checked nothing
grows inside the building read the instance transforms back and found every one
of them at the world origin — which is inside the building. Every write was
accepted, every read returned identity, `buffer.size()` was 0, and nothing
errored: the transforms live in the rendering server, and the headless server
discards them. The game was fine; the test was measuring an empty buffer. It now
asserts through `FoliageScatter`, which is pure, and there is a second test that
fails if a future Godot ever starts keeping the buffer, so the workaround
announces itself rather than quietly outliving its reason.

**Writing `NORMAL` in the fragment shader defeated Godot's back-face flip.**
With culling disabled — which crossed quads need — Godot negates the normal for
back faces before `fragment()` runs. Overwriting it with a world-space normal of
my own put every second face of every quad in permanent shadow. It rendered as
solid black blobs clustered under the trees and looked exactly like a shadow
bug.

**The palette was in sRGB again.** Vertex colours are handed to the shader
exactly as stored and `ALBEDO` is linear, so a green authored the way a colour
picker shows it arrived about twice as bright as it reads on the page. The first
field of grass was pale mint sitting on top of a dark meadow. This is the same
colour-space mistake as post 045's `to_band()`, in a different place, two days
apart — which is why it is now written into `FoliageMesh` as a paragraph rather
than a line.

## The band flattened the gradient

A blade is dark at the root and light at the tip, and that gradient is most of
what makes it read as a plant rather than as a green spike. Running each pixel
through the value band destroyed it: banding the root and the tip *separately*
lands them both on the same brightness, by construction.

So a gradient is now scaled by a single number derived from its middle, computed
once when the mesh is built rather than per pixel. The clump sits in the ground
band; the blade still gets lighter toward the top. It is also cheaper, which is
the second-best reason to do it.

## What this does not do

The clumps are three crossed opaque quads. They read as low-poly tufts, which is
a coherent stylised look, but they are not blades — real stylised grass uses
alpha-tested cards, and alpha is exactly what this project cannot spend freely
after post 045. The trees are a trunk and a canopy built from six-sided rings.
They read as trees at distance and as faceted blobs up close.

Both are honest placeholders that follow the asset policy: procedural, because
there is no artist. They are a large improvement on nothing and they are not
what the reference look has.

## Music is off now

Unrelated to the phase, and worth a line. The generated loop is background
texture rather than a score, and a game that starts playing at somebody unasked
is a game they mute at the operating system — after which nothing else it does
with sound can reach them. Music now has its own bus, defaults to silent, and
has its own slider next to the master one. It still plays into the muted bus, so
turning it up is immediate rather than needing a reload.

---

Next: [047 — A person, with a sword](047-a-person-with-a-sword.md).
