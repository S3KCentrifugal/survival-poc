# 014 — A base to walk out of

*2026-08-04 · commit pending*

Until now the world was a hillside with a robot on it. This post is about giving
it a building: two rooms, a door between them, a door out, and a tower to walk
to. Prototype geometry — boxes — but the two problems worth writing about were
not about geometry at all.

## Problem one: the ground moves more than a building can tolerate

Before designing anything I measured what the terrain actually does under a
house-sized footprint. This turned out to be the most useful ten minutes of the
whole feature:

```
whole tile:                        -3.57 ..  3.31 m
14 x 10 m under the base:          -0.43 ..  2.94   (relief 3.37 m)
8 x 8 m under the tower:           -2.09 ..  0.61   (relief 2.71 m)
```

**3.4 metres of relief across the base's footprint.** From thirty metres up the
terrain reads as almost flat — post 010 even lists "raise the noise frequency"
as an open item because it looks *too* smooth. At building scale it is nothing
of the sort.

Any flat structure on that ground floats a metre in the air at one corner and
buries itself at the other. Worse, the doorway threshold becomes a 3.4 m step,
and a `CharacterBody3D` has no step-up: a vertical face is a wall regardless of
how tall it is. The building would have been decorative.

So the level levels its own ground. `Heightfield.flatten(area, height, blend)`
sets a rectangle to a fixed height and eases back to the real terrain over a
margin. The blend is not decoration — without it the pad is a plateau stamped
into the hillside with a cliff of exactly the relief you just removed, which is
worse than the problem it solves.

Both pads use **one** height. Levelling them independently is more realistic and
immediately puts a step between the two, and then the ground between them has to
be a ramp or a cliff, and a prototype should not be having that argument yet.

This needed a new seam on `Terrain`. It regenerated from config on every
`rebuild()`, so there was no way to hand it a modified field. `present(field)`
now shows a field as it stands, and `rebuild()` is `present(generate(config))`.
Mesh and collision are still built together from the same data, which is the
only way they cannot drift apart. A crater will want the same door.

## Problem two: a doorway is a subtraction

`WallBuilder` is the only part of this with real logic in it, and it does one
thing: given a wall run and a list of openings, return the solid boxes. Piers
either side of each gap, a lintel above it where the wall is taller than the
opening.

Subtraction is where the off-by-one lives, and the failure modes are all quiet:

- A gap half a metre out is a door you cannot fit through, or a wall with
  daylight under it.
- A doorway flush with the end of a wall produces a **zero-width box** —
  invisible, collides with nothing, and counted in every total forever after.
- Openings given out of order produce overlapping spans, and a wall whose solid
  parts add up to more than its own length.
- An opening running off the end, if not clipped, does the same.

None of that is visible from the game camera. All of it is one assertion each,
so `test_wall_builder.gd` carries nineteen of them — including the one that
matters most: *nothing solid stands in the doorway below head height.*

## The five centimetre floor

The floor slab sits 5 cm above the levelled ground.

Zero would be the obvious choice and is wrong: the slab top and the terrain
surface would be coplanar and fight over the same pixels. But any lip is a
vertical face, and vertical faces stop characters.

5 cm works because the player's collider is a **capsule** — its bottom is a
hemisphere of radius 0.4 m, so a small lip resolves as a slope rather than a
wall and the character rolls over it. That is a claim about physics, not
geometry, so I did not reason about it. I drove the character through:

```
spawned at (-3.0, 1.39, 0.0)
  reached waypoint 0 (3.0, 0.0)   -- through the internal doorway
  reached waypoint 1 (3.0, 7.0)   -- out through the south door
  reached waypoint 2 (13.0, 6.0)  -- across the open ground
  reached waypoint 3 (13.0, 11.0) -- in through the tower door
ARRIVED
```

The first run of that harness reported `STUCK on leg 1`. The building was fine;
my waypoints were wrong — I had routed the character through the divider wall at
z = 2.6 when the doorway is at z = 0. Worth recording because for about a minute
I believed I had found a collision bug, and the fix was in the test.

## What is deliberately not built

**The layout is constants in a script, not a resource.** Walls, openings and
pads all have tested logic behind them, but *where the walls go* is code in
`prototype_level.gd`. This project puts data in `Resource` files, so that is a
real deviation and it is deliberate: inventing a level format to describe one
prototype building would be guessing at what the second building needs. The
second building is what should decide the format.

No roofs, no doors that open, no windows, no stairs. Buildings are open-topped
boxes with holes in them, which is exactly what a top-down camera needs in order
to see inside — and the camera looking into a roofless room turns out to read
perfectly well.

## Where it leaves things

You start in a room. You walk through a door into the next room, out of the
building, across open ground, and into a tower. That is the first time this
project has had anywhere to *be* rather than just somewhere to move.

It also gives the camera argument a second data point in the other direction: at
18 m a lone character is a smudge, but a 12 × 8 m building frames well. Whatever
distance gets chosen now has two things to serve, not one.
