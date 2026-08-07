# 045 — One shader for everything

*7 August 2026 — covers the Phase 2 material commit*

Phase 1 fixed the air and left the largest failing on the board untouched: the
player reads at 1.0:1 against the world it stands in, against a 3:1 target. Post
044 established why the environment could never move it — the rule is about
**mass**, and lighting is not.

This is the phase that moves it. It also found three bugs, every one of which
produced a picture that looked fine.

## The value structure

`ART.md` rule 3 says a character has to sit 3:1 in luminance against what is
immediately behind them, and there are no outlines to fall back on. The cause of
1.0:1 was never mysterious once measured: the robot's albedo sits at almost
exactly the luminance of grass, of the building walls, and of the floor.

So every surface is now assigned a **band** and pulled toward it. Ground at the
bottom, structures in the middle, props above them, characters well clear at the
top. The gap between the ground band and the character band *is* the silhouette.
`SurfacePalette` owns the arithmetic; the same formula lives in GLSL for
textured surfaces.

Pulled by **scaling**, not by mixing toward a grey of the target brightness.
Mixing desaturates as it moves, so a green field pulled down comes out sludge —
which would fix rule 3 by breaking rule 1.

The result: **1.0:1 → 2.5:1**, and `player-close` is now the first shot in the
project that enforces anything about silhouette.

Not 3:1, and the gap is instructive. At the palette level the bands separate
**6.8:1**. The screen gives back 2.5. Lighting and AgX both compress a contrast
on its way to the frame, so a value structure built to exactly the target arrives
under it — which is why the bands aim well past 3:1 rather than at it, and why
the honest number today is 2.5.

## Three bugs that looked like features

**`ALPHA` makes a material transparent, and transparent materials cast no
shadows.** The shader wrote `ALPHA = surface.a` to carry through the albedo's
alpha, which seemed obviously harmless. Merely assigning `ALPHA` — even 1.0 —
moves a spatial material onto the transparent pipeline.

Every shadow in the game disappeared. What I noticed first was the shot report:

```
base-exterior   88 draws +  34 shadow   (was 88 + 196)
world-noon      88 draws +  28 shadow   (was 88 + 155)
```

The shadow pass had fallen by five times with the primitive count unchanged, and
my first thought was that sharing one material family had let Godot batch the
shadow pass — a plausible, satisfying, completely wrong conclusion that I came
within one sentence of writing down as a Phase 2 benefit. It was only checking
the frame that showed the buildings casting nothing onto the grass.

**A custom `light()` must not multiply `ALBEDO`.** The characters came out pale
and formless, and the obvious explanation was that Godot leaves `DIFFUSE_LIGHT`
untinted when you override `light()`, so I added `ALBEDO *` to it. The frame got
darker and the contrast measurement fell from 2.9:1 to 2.3:1 — which is what
squaring an albedo does. Godot applies it for you. The docs' Lambert example is
genuinely ambiguous about this and the wrong version looks plausible; the only
thing that settled it was rendering both.

**The palette maths was in the wrong colour space.** `SurfacePalette.to_band()`
scaled sRGB channels by a ratio derived from *linear* luminance. Asked for a
target of 0.25 it returned 0.41. The shader was correct — `ALBEDO` is already
linear — so my comment claiming the two were "the same formula" was false in the
only way that matters. Caught by the unit test, which is the one of the three
that did not need a renderer.

## The ramp invented light

The first ramp gave its lowest band a weight of 0.45, so any surface turned even
slightly toward the sun was lit at nearly half strength. Every rolling hill and
every curved character came out pale and formless, and I spent two iterations
blaming the value band and then the rim before looking at the curve itself.

A ramp is allowed to *quantise* light. It is not allowed to invent it. Reweighted
so each plateau lands near the Lambert value it replaces — 0.22 at the
terminator, 0.55 through the middle, 1.0 facing the sun — the hills got their
form back and the mean luminance of the world dropped by a fifth.

## Night versus the ground

Rule 3 wants a dark ground. Rule 6 wants a night you can see in. They pull
against each other through exactly one number, and the sensitivity is brutal:
moving the ground band from 0.045 to 0.038 took `world-night` from 15% below the
readable floor to 67%.

Paid for by raising the night ambient *energy* above the day's. That reads wrong
until you say it out loud: after the sun goes, ambient is the only light there
is, so it has to carry the whole frame rather than fill in shadows around a key
light. What has to stay true is that night contributes less light overall, which
the colour handles — and which is now a test, because the obvious invariant
("night energy is lower than day energy") is false on purpose.

## What is shared, and what a shared shader cannot do

`shaders/stylised.gdshaderinc` holds the shading: the value band, the ramp, the
rim. `stylised.gdshader` draws characters, structures and props.
`terrain.gdshader` includes the same file, so the ground is lit by the same
maths as everything standing on it — before this it was the only surface in the
world with its own lighting, which is the quickest way to make one world look
like two.

Imported glTF materials are converted at load by `StylisedSurface`, as a
**surface override**. Never by editing the material: an imported material is a
cached resource shared by every instance of the model, so writing to it would
restyle every character in the game from one component and survive into the next
scene that loaded the mesh. That is the trap that has now caught this project
four times, and this is the first time it was designed around rather than
discovered.

What none of it does is make the robot look like a character. Its albedo is
mostly white and light blue, so it still reads pale however it is lit or banded.
`ART.md` has said from the start that the models are CC0 placeholders; this is
what that costs, stated as a number rather than as a caveat.

---

Next: Phase 3 — foliage and world density, which is the biggest perceived jump
for an outdoor game and the first phase with a real performance risk attached.
