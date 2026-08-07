# 043 — Rules for a look

*7 August 2026 — covers the ART.md commit*

`GRAPHICS.md` put an art-direction document in front of every phase of visual
work, on the grounds that "make it look better" is unfalsifiable and an agent
handed an unfalsifiable goal will thrash. Post 042 shipped the harness without
one and named it as the blocking item. This is it.

Three decisions were not mine to make, so they were asked:

- **Painterly and atmospheric**, the Breath of the Wild lineage, over cel-shaded
  Wind Waker, storybook Animal Crossing, or stylised naturalism.
- **A neutral base palette tinted per region**, over committing the whole world
  to one temperature.
- **A night that is blue, quiet and playable**, over one that is genuinely dark.

Everything below follows from those, and most of the value turned out to be in
what happened when the new rules were pointed at the build that already existed.

## The half of an art direction that is a number

`UI.md` works because it is not only prose. It names WCAG's 4.5:1, and
`UiTokens.contrast()` measures it, and a test fails when a palette change breaks
it — which it did, on the first palette, at 4.25:1 against the raised surface
nobody had checked.

`ART.md` gets the same treatment. `FrameLook` walks a rendered frame and reports
four things a golden image cannot:

- **How many hues it is built from.** Twelve buckets, counting the ones carrying
  real weight. Cohesion is most of what this look means and it is countable: four
  hues reads as designed, eleven reads as assembled from whatever was to hand.
- **How much is crushed or blown.** Detail lost to either end of the range is
  lost for good, and both ends are where an untuned tonemapper puts things.
- **How much of the range it uses.** Reported, not enforced — a painterly frame
  deliberately uses less than a photographic one. What it must not do is use
  none.
- **How far the subject separates from what is behind it**, as a WCAG-style
  luminance ratio.

A golden image only knows whether something *changed*. These catch four ways of
being wrong that were true before anyone changed anything.

## What it said about the game as it stands

| Shot | Mean luminance | Dark | Hues | Subject contrast |
|---|---|---|---|---|
| `world-noon` | 0.232 | 0% | 5 | **1.2:1** |
| `base-exterior` | 0.235 | 0% | 5 | **1.2:1** |
| `hud-gameplay` | 0.189 | 2% | 4 | **1.1:1** |
| `player-close` | 0.324 | 0% | 2 | **1.1:1** |
| `world-dusk` | 0.037 | **71%** | 2 | 1.0:1 |
| `world-night` | 0.002 | **100%** | 1 | 1.0:1 |

**The character does not read against the world. Anywhere.** Every shot lands
between 1.0 and 1.3:1 against a 3:1 target. The blue robot sits at very nearly
the same luminance as grass, as the building walls, and as the floor — so it is
separated from its background by hue alone, which is to say by nothing at a
glance, and by nothing at all for the ~4% of players who cannot tell red from
green.

I would not have found that by looking. The player-close shot looks *fine*: a
blue robot in front of a grey wall, plainly visible, no obvious problem. It
takes a number to notice that "plainly visible" is doing all its work in a
channel that stops working the moment the wall is a hillside instead.

**Night is not dark, it is absent.** 100% of the night frame is below the
readable floor and its mean luminance is 0.002. There is no ambient term at
night at all. **And dusk is already night** — 71% dark at the time of day that
should be the best-looking in the game.

The palette came out better than expected: two to five hues everywhere. Mostly
because the world is grass, so this is a rule that will get harder rather than
easier.

## Three attempts at one measurement

The subject-contrast number took three goes, and each wrong version was
plausible.

**A fixed disc** — sample a circle 4.5% of the frame height on the character,
and a ring around it. Reported 1.6:1 for the close-up and 1.0:1 for the wide
gameplay shot. The wide shot's player is perhaps twenty pixels tall at golden
size, so the disc was four times the size of the thing it was supposed to be
sampling, and dutifully measured grass against grass.

**A disc sized from the subject** — project the character's height into screen
space and take a quarter of it. Correct for the distant case, and it made the
*close-up* worse: 1.0:1, down from 1.6. With the background ring at three times
the disc radius, a character filling most of the frame has its "background" ring
still inside its own silhouette. It was comparing the robot against the robot.

**Both radii from the silhouette** — disc at 0.15 of the subject's height, ring
from 0.45 to 0.95, with the gap in between skipped because the pixels either
side of an edge are a blend of both and drag the two means together. That is the
one that survives, and it now reports 1.0–1.3:1 across every shot, which is the
honest answer.

Worth noting what happened in the middle: the second version made a number get
*worse* while making the method better. If the target had been "get this number
up" rather than "measure the right thing", that would have looked like a
regression and been reverted.

## Two rules that cost something

**No outlines** was the fork with the largest consequences. They are the easy
way to make a character read, and both implementations are cheap enough —
depth-edge costs one full-screen pass regardless of object count. They were
rejected because they draw a line around every facet of a low-poly silhouette,
and the models here are CC0 placeholders that do not deserve the attention.

The bill for that is rule 3: with no outline, silhouette has to come entirely
from luminance, which is the rule the project currently fails hardest. Choosing
the cheaper-looking option moved the cost rather than removing it, which is
worth writing down, because from the diff it will look like a free decision.

**No `min_subject_contrast` on any shot yet.** Every shot fails it. A target set
to what is currently wrong is a target that ratifies it, and a permanently red
tool is a tool nobody runs. So the figure lives in `ART.md` as what Phase 1 has
to reach, and the *check* is unit-tested now so it does not arrive untested on
the day it starts mattering.

Same reasoning for the two night shots, which carry no darkness ceiling: 71% and
100% are the numbers to beat, not the numbers to lock in. The golden image still
catches any change to them, so nothing is unguarded in the meantime.

## What is deliberately not here

**No `ArtTokens`.** Rule 8 says every colour, fog curve and ramp lives in one
generated place, the same as `UiTokens` is to the theme. It does not exist yet
and should not: a palette written before anything consumes it is a palette that
is wrong in ways nobody can see. It arrives in Phase 1 with the first thing that
needs it. The rule is written first so that it cannot arrive any other way.

**Nothing about character design.** Silhouette is most of what makes the
reference games work and it is the one part of this that is neither derivable
from a rule nor measurable afterwards.

**No claim that any of this makes the game look good.** These rules make it
coherent and legible. Both are prerequisites for looking good and neither is the
same thing.

---

Next: [044 — A night you can see in](044-a-night-you-can-see-in.md).
