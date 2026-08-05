# 033 — Terrain with somewhere to stand

*5 August 2026 — covers the terrain commit*

The old ground was 64 metres square, six metres of relief, and one octave-stack
of simplex noise. It was honest placeholder: a grid of gentle bumps, evenly, in
every direction. This makes it 256 metres, gives it plains and hills and
ridgelines, and puts real textures on it.

## One noise field cannot make a landscape

The problem with a single fractal noise field is not that it looks bad, it is
that it looks *the same everywhere*. Every square metre is as interesting as
every other square metre, which is the one property real ground never has. You
cannot build on it, because there is nowhere flat; you cannot navigate by it,
because there is no landmark.

`TerrainShaper` is four fields doing four jobs:

- **Relief** — very low frequency, and it weights everything else. This is the
  layer that decides *where* the land is interesting, and it is the one that
  makes the difference.
- **Hills** — the broad shape you read from a distance.
- **Ridges** — folded noise, `1 - abs(n)`, which creases where plain noise
  rounds. Weighted by relief, so ridgelines only appear on high ground.
- **Detail** — small, everywhere, so the surface is not plastic.

The hill layer is raised to a power (1.7) before it is used. At 1.0 it spends
half its time above the midpoint, which reads as corrugation; above 1.0 it sits
low and broad with the occasional height, which is what ground does. There is a
test asserting more than 60% of the map is below its own midpoint, because that
is the property, not the exponent.

## The mistake that made hills into objects

The first version had relief multiply the shape directly, so a relief of zero
meant a height of zero. Rendered from above, that gave rocky cones standing on
a perfectly flat green sheet. It looked like a terrain generator had run and
then someone had placed hills on the output.

The fix is one lerp:

```gdscript
return lerpf(_config.relief_floor, 1.0, mask)
```

Plains now get 16% of the hill layer instead of none — gentle undulation of the
*same shape* as the hills, so the hills read as the high end of one landscape
rather than as objects on another. Sixteen percent. That is the entire
difference between the two screenshots.

There is a test that asserts the floor holds everywhere, and its failure
message says what it is for: "plains would be perfectly flat".

## Tuning against numbers, not screenshots

Terrain is the most tempting thing in a project to tune by squinting. So the
first thing built was a probe that prints the shape of a field as percentages:

```
relief=0.0035 hill=0.0060 -> 11.2 m of relief | flat 27% gentle 69% steep  4%
relief=0.0090 hill=0.0130 -> 24.6 m of relief | flat  8% gentle 55% steep 29%
```

The first row is what the original frequencies gave on a 256 m tile: eleven
metres of relief spread over 256 metres is a four percent grade, which is why
the first render came out looking like a lawn. The frequencies had been chosen
for a world several times larger without anyone noticing, because at 64 m
across there was nothing to notice.

The probe also caught something the eye would not have: plains that measured
only 8% flat despite the relief mask calling 59% of the map plain. The detail
layer was putting a 2.6 m hummock every 17 m *on the plains*. Real numbers,
real fix, and it became `test_the_land_has_plains_hills_and_steep_ground`.

The final profile is 41% flat, 32% rolling, 21% steep, 6% cliff. The tests
assert bands around those rather than the numbers themselves — the point is
that a landscape has all four, not that it has exactly these.

## Texturing by what the ground is doing

There is no splat map and nothing for an artist to keep in sync with the
heightfield. Slope decides: grass under 16°, dirt from 16° to 26°, rock from
32° to 46°, blended. Regenerate the terrain with a different seed and the
texturing follows, because it is derived from the same surface.

Three things make it not look procedural:

- **Cliffs are triplanar.** A steep face UV-mapped from above is the texture
  smeared into vertical streaks, and that is the single most obvious tell that
  a terrain is untextured rather than textured badly.
- **The grass is sampled twice**, at 3.5 m and at 47 m, and multiplied. One
  texture repeating every 3.5 m is a chequerboard from any height; the same
  texture also repeating every 47 m hides the grid without a second asset.
- **The slope thresholds are jittered** by a texture lookup, so the boundary
  between grass and rock is ragged rather than a contour line.

Textures are CC0 from ambientCG, downloaded at 1K and **resized to 512**. That
is 676 KB for six maps rather than 13 MB, and at the distance this camera sits
from the ground the difference is not visible. The provenance and the reasoning
are in `assets/terrain/README.md`, because "where did this file come from" gets
asked once the answer is hard to find.

Normal maps are the GL variants. A DirectX normal map lights every bump from
the wrong side, which reads as the sun being in the wrong place rather than as
a wrong texture.

## Six seconds of navmesh, and the number that was never the point

Sixteen times the ground area made the test suite go from about a minute to
**seven and a half**. Almost all of it was one thing: the navmesh bake, at
0.1 m cells, over a 256 m tile — 6.5 million voxels, six seconds per scene
mount, and the suite mounts the world about forty times.

Post 024 established 0.1 m cells after a companion could not path through a
doorway. Re-reading that post: the actual finding was that the bake **ceils the
agent radius up to whole cells**, and 0.55 at 0.25 became 0.75 and closed the
door. The lesson was never "use small cells". It was "make the radius an exact
multiple of the cell size".

0.4 divides by 0.2 exactly. So the cells are now 0.2 m, the bake is a
sixteenth of the size, the suite is back under three minutes, and the companion
still walks through the doorway — there is a test for that and it did not
change. Two other properties turned out to be quietly rounded too:
`agent_max_climb` is floored to whole cells (0.3 became 0.2) and
`region_min_size` is converted to int (0.5 became 0). Godot warned about both;
both are now whole numbers of cells.

A conclusion that was right for one reason got remembered for a different
reason, and the wrong version of it cost six seconds a mount for as long as it
took to re-read the post that established it.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
