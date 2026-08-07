# 044 — A night you can see in

*7 August 2026 — covers the Phase 1 atmosphere commit*

`ART.md` said what the game should look like. This is the first phase that
changes what it does look like: the ambient term, the fog, and the tonemapper —
everything about the air, as opposed to the sky it is made of.

Two of the three findings from post 043 are fixed. The third is not, and the
interesting part of this post is why it could never have been.

## Night was not dark, it was absent

The measurement was 100% of the night frame below the readable floor, with a
mean luminance of 0.002. The cause turned out to be one line of scene
configuration doing exactly what it says.

The environment used `ambient_light_source = SKY`, which is the right answer and
is what every Godot tutorial recommends: the ambient light comes from the
rendered sky, so it is automatically the right colour at every hour, for free.
Except this project's sky is a custom shader whose night palette is
`Color(0.015, 0.025, 0.075)` — deliberately, because a night sky is nearly
black. So the ambient at night was an average of nearly black, which is nearly
black, and every surface not directly facing the moon rendered with no light on
it at all.

Nothing was wrong. The sky was right, the setting was right, and the result was
a black screen.

The fix is `ambient_light_sky_contribution`, blended by sun elevation: by day
the sky is the right answer and provides all of it, and below the horizon it
hands over to a flat moonlight blue. Along with a moon that is actually a key
light — `night_energy` was 0.05, which is not a dim night, it is no night —
the frame goes from 78% below the floor to **14%**.

## Dusk was already night

71% dark at the hour that should be the best-looking in the game.

Same family of cause. The sun's own light stops the instant it crosses the
horizon, because that is what a horizon is, and the old code let the world go
with it: `light_energy` lerped to its night value at elevation zero. Meanwhile
the sky shader kept painting a bright orange sunset, because *its* band is
defined separately and extends below the horizon. An orange sky over a black
field.

A lit sky is a lit dome, and the ground is lit by the dome long after the sun is
behind a hill. `Atmosphere.skylight_amount()` keeps skylight through an
afterglow band 0.22 below the horizon, so the moment of sunset still has about
half of it. Dusk goes from 64% below the floor to **0%**, and the sunset shot is
now the best frame in the project.

## The measurement that could not tell the difference

Here is the part worth writing down.

With night visibly fixed — stars, blue hills, readable characters, a picture I
would put in a trailer — `FrameLook` still reported **90% dark**. The frame
before the fix reported 100%.

A measure that gives essentially the same answer either side of the change it
exists to verify is not a measure. So rather than argue with it or quietly
loosen it, I measured both frames at a range of thresholds:

```
                   <0.0005  <0.0010  <0.0020  <0.0040  <0.0080  <0.0150
night, unplayable      67%      72%      78%      78%     100%     100%
night, readable         0%       0%       0%      11%      86%      90%
dusk, before            0%       0%       0%      64%      67%      71%
dusk, after             0%       0%       0%       0%      20%      51%
```

The floor was 0.015, guessed in post 043 before there was any frame to check it
against. Everything from 0.008 up measures *how dark a night is*, which is not
the question — night is supposed to be dark. The question is whether anything in
it can be made out, and 0.004 answers that: 78% against 11%, with room on both
sides.

That recalibration is the sort of thing that looks, in a diff, exactly like
moving the goalposts to make your own work pass. The difference is that the
threshold now has two frames bracketing it that everyone agrees about — one is a
black screen, one is playable — and it separates them. The old one did not
separate anything. Both frames are committed, so the next person can check the
claim rather than take it.

With a floor that works, both night targets could finally be *set*. `ART.md`
rule 6's own figure — no more than 45% below the floor — is now enforced on
`world-night`, which measures 14%.

## The thing that did not move, and was never going to

Post 043's largest finding was that the player does not read against the world:
1.0–1.3:1 luminance contrast against a 3:1 target. `ART.md` rule 3 said rim
light was the answer.

After the whole of Phase 1 — ambient, fog, a night, a dusk, a new tonemapper —
the number is 1.0–1.2:1. It moved by nothing.

It was never going to. Rule 3 is a statement about **mass**: what value does the
character read as when you squint. A rim light is a bright line a few pixels
wide around a silhouette. It makes an outline legible against a busy background,
which is genuinely worth having, and it does not change the value of the thing
inside the outline by any amount a disc-and-ring measurement can see. Neither
does lighting the air around it: fog helps a character stand out from *distant*
background, and every one of these shots has the character standing in front of
grass three metres behind them.

The blue robot's albedo simply sits at the luminance of grass, of the building
walls, and of the floor. That is an albedo problem and it gets fixed by albedo:
Phase 2's material system, with a value structure that puts characters and
ground in different bands. Rim light goes there too, as an edge cue on top
rather than as the fix.

I have corrected rule 3 in `ART.md` rather than quietly moving the target. The
claim was wrong when I wrote it, and a rule that names the wrong remedy is worse
than one that names none, because somebody will implement the remedy and then be
puzzled.

## What it cost

Nothing. Draw calls and primitives are identical to the frame before, for all
seven shots. Fog, ambient and tonemapping are per-pixel work on a scene rendering
88 draw calls, which is not where this project's frame goes — the sun is, and
that is Phase 7.

Day frames came down from 0.23 to 0.17 mean luminance with AgX replacing Filmic.
Nothing is crushed and nothing is blown, so that is the compressed mid-range rule
7 asks for rather than an underexposure. It is worth flagging because "the game
got darker" is a thing somebody will notice and it was deliberate.

## Where the numbers live

`ArtTokens` arrived, per rule 8, and it is worth being precise about what it does
*not* hold. The sun's colour and energy stay in `DayNightConfig`; the sky's
palette stays in `SkyConfig`. Both are already resources that the light and the
sky shader read, and copying them into `ArtTokens` would create a second version
of every number in a place nobody would think to look — which is the exact
failure rule 8 exists to prevent. `ArtTokens` owns the air, which was previously
owned by nothing at all.

`Atmosphere` is the pure half: give it a sun elevation, it returns an ambient
energy, an ambient colour, a sky contribution, a fog colour, a fog density and an
exposure. No shader, no node, no clock — so "is there still light in the sky ten
minutes after sunset?" is a test with a figure in it. Given the bug being fixed
was invisible to everybody for forty-two features, that seemed like the right
shape.

---

Next: Phase 2 — a stylised material system, which now carries rule 3.
