# 030 — The sky

*5 August 2026 — covers the sky commit*

The day/night cycle has existed since feature 9. What it drove was one
directional light, and the sky above it was a stock `ProceduralSkyMaterial`
with every property left at its default. Feature 9's post said the coupling was
free:

> The scene's procedural sky already takes its gradient from the brightest
> directional light, so moving this one moves the sky and the ambient light
> with it — one rotation, a whole atmosphere, and nothing else to keep in sync.

That was true, and it was also the ceiling. A stock procedural sky cannot do a
sunset worth looking at and cannot do a star at all. Replacing it means giving
up the coupling that came free and wiring it back by hand — which is the trade
this feature makes, and the reason `DayNightComponent`'s docstring now carries
a correction rather than the old claim.

## Where the decisions live

A sky is a shader, and a shader is the worst place in a codebase to put a
decision. You cannot test it, you cannot read a value out of it, and the only
way to find out what it did is to look at a picture.

So the shader knows how to *draw* a sky and nothing about what time it is:

```
uniform vec3 zenith_color : source_color;
uniform vec3 horizon_color : source_color;
uniform float halo_strength;
uniform float star_fade;
```

Every one of those arrives from `SkyGradient`, which is a plain `RefCounted`
that takes one number — how high the sun is, from -1 to 1 — and returns
colours. Which means the interesting claims are assertions rather than
opinions:

```gdscript
func test_the_sunset_is_warmer_than_noon() -> void:
	var dusk := gradient.horizon_color(0.0)
	var noon := gradient.horizon_color(1.0)
	assert_true(dusk.r > noon.r)
	assert_true(dusk.b < noon.b)
```

`test_the_halo_belongs_to_the_horizon` is the one I would not have thought to
write if the logic had stayed in GLSL. The glow around the sun is light
scattered along a low path through thick air, so it peaks *at the horizon* and
is nearly absent at noon — and it has to be gone once the sun is properly
down, or you get a glow outliving the thing casting it.

## Three details that were wrong the first time

**The sun must be drawn where the light comes from.** `SkyComponent` reads the
direction off the `DirectionalLight3D`'s own basis rather than recomputing it
from the clock:

```gdscript
# A DirectionalLight3D shines along its local -Z, so the direction back
# toward the sun is +Z.
return day_night.sun.global_transform.basis.z.normalized()
```

Two sources for one direction is two chances to disagree, and a sun in one
corner of the sky with shadows pointing out of another is glaring in a
screenshot and invisible in a diff. There is a test that walks five times of
day and asserts the drawn direction is the exact negation of the lit one.

**The ground was a hole in the world.** The first version had a fixed dark grey
below the horizon and a short fade into it. Rendered, that put a hard black
band straight across the view — and because the terrain is one 64 m tile, you
see plenty of below-the-horizon. It did not read as distance. It read as the
world running out.

The fix was to stop giving it a colour of its own. The ground is now the
horizon colour darkened by a fraction, so at sunset it is dark orange and at
midnight nearly black, and the fade runs over `smoothstep(-0.45, 0.02, height)`
instead of `(-0.09, 0.015)`. A palette that is always a shade the sky is
already wearing cannot clash with it.

**The stars were too small to survive.** They were there in the first night
render — a handful of barely-perceptible specks. Each star's core was
`smoothstep(0.09, 0.0, distance)` in cell units, which at 1280×720 is a dot
landing between pixels. Widening the core to `0.14` and raising brightness to
3.2 gave an actual night sky. Sub-pixel detail does not render; it averages
away and reads as "the feature does not work".

## The trap I nearly walked into for the fourth time

The sky material is a **sub-resource** of `main.tscn`. My first comment in the
scene file said, confidently:

> A sub-resource, not a file: every instantiation of this scene then gets its
> own material.

That is wrong. Sub-resources are **shared** between instantiations unless they
carry `resource_local_to_scene = true`. Two worlds — two tests, two windows
later — would have written uniforms to the same material, and one world's clock
would have recoloured the other's sky.

This is the same shared-resource trap that has already caught this project
three times: a `MovementConfig` mutated in a test, a HUD `StyleBox`, a health
bar material. It is now four. The material, the `Sky` and the `Environment` all
carry the flag, and there is a test that mounts two worlds, sets one to noon
and the other to midnight, and asserts their skies differ.

Worth noticing that the wrong comment was written *before* the code was
checked. A comment asserting a behaviour is a claim, and claims want tests.

## What it looks like

The sun rises due east and sets in the west, leaning past the zenith rather
than through it, because feature 9 already got that right. Around it:

- **Noon** — deep blue overhead, pale near the horizon, a white disc, no halo.
- **Sunset** — purple zenith, orange horizon, the disc clipped at the horizon
  line rather than fading, which is what makes it read as sinking *behind*
  something. The halo is at full strength here and nowhere else.
- **Night** — near-black with a field of stars, each twinkling out of step
  with the rest.

Stars are skipped during the radiance cubemap pass (`AT_CUBEMAP_PASS`). They
are finer than that cubemap's texels, so they do not survive being averaged
into it — they just shimmer through the ambient light of the entire scene.

The dev console's `time` command scrubs the whole day, which is how all of the
above was checked without waiting ten minutes per look.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
