# Art direction

What this game is supposed to look like, why, and which parts of that are a
number rather than an opinion. `CLAUDE.md` holds the enforceable short version;
this is the reasoning behind it.

The same bargain `UI.md` makes: every rule names where it comes from, and every
rule that *can* be measured is measured, because a guideline you cannot check is
a preference and preferences do not survive disagreement. `FrameLook` is the
measuring, `shots.sh check` is where it runs.

---

## The target

**Painterly and atmospheric.** The Breath of the Wild lineage: soft shading,
restrained colour, and depth carried by air rather than by detail. No outlines.

It is worth being precise about why this is the cheap option and not the
expensive one. Breath of the Wild ran on a 2015 mobile GPU. What makes that
family of games look the way they do is not fidelity, it is **cohesion** — a
small number of techniques applied with total consistency, and a palette
disciplined enough that nothing looks borrowed. Almost none of it costs draw
calls. All of it costs decisions, which is what this file is.

Three consequences follow immediately, and they are the whole direction:

- **Fog is not an effect, it is the art direction.** Depth comes from
  atmospheric perspective. If the fog is wrong the frame is wrong, and no amount
  of texture work will rescue it.
- **There are no outlines, so silhouette has to come from value.** This is the
  expensive half of choosing this look, and the project currently fails it
  completely — see *Where we actually are*.
- **The sky is the master colour.** Everything distant tends toward it and every
  shadow is tinted by it, so changing the sky changes the whole frame. That is a
  feature; it is also why the sky gets its own shot at three times of day.

**Explicitly not the target:** photoreal PBR, SDFGI, heavy post stacks, cel
bands, or black outlines. The character models are CC0 placeholders and will
stay that way; this is about how they are *lit*, not about replacing them.

---

## The sources

| Source | What it covers | Why this one |
|---|---|---|
| **Aerial perspective** — Leonardo da Vinci, and standard landscape painting practice since | Distant things lose contrast, lose saturation, and shift toward the colour of the sky | Five hundred years old, physically true, and free in a shader. It is the single technique that makes an open landscape read as large |
| **Notan / value structure** — traditional composition practice, Japanese and Western | A composition must read as a few flat masses of value before it reads as anything else | Explains *why* silhouette beats detail, rather than asserting it. Squint at a good frame and you see three or four shapes |
| **[Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/)** | Foreground/background separation; never saying anything in colour alone | Around 4% of players cannot separate red from green. Already a `UI.md` source, and the argument does not stop at the HUD |
| **[WCAG 2.2](https://www.w3.org/TR/WCAG22/) contrast arithmetic** | A measurable definition of "these two things are distinguishable" | Borrowed for its **maths**, not its scope. WCAG is about text on a background; using its 3:1 non-text figure for a character against grass is an analogy, and a defensible one, but it is not a compliance claim |
| **GDC 2017, "Breaking Conventions with The Legend of Zelda: Breath of the Wild"** | The design and art thinking behind the reference look | The clearest public account of the target, from the people who built it |

---

## The rules

### 1. Cohesion before everything

A frame is built from a **small number of hues**, and the same small number
across every frame. Four or five is designed; eleven is assembled from whatever
was to hand.

This is the rule that most distinguishes the target from "a renderer with good
settings", and it is countable: `FrameLook.hue_count` buckets the frame into 12
hues and counts the ones carrying real weight. Every shot sets a ceiling.

### 2. Depth is air, not detail

Distant geometry loses contrast, loses saturation, and shifts toward the sky
colour. Tuned per time of day, because the air is a different colour at dusk
than at noon.

The temptation this rule exists to refuse: making distant things *more* detailed
to make the world feel bigger. It does the opposite. A distant hill that is as
crisp as a near one reads as a painted backdrop.

*Aerial perspective.*

### 3. No outlines. Silhouette is value

Decided, and it is the fork with the largest consequences. Outlines are the easy
way to make a character read, and they were rejected because they expose every
facet of a low-poly silhouette and, in the inverted-hull form, cost a draw call
per object.

So separation has to come from **luminance** instead:

> **A character must sit at least 3:1 in luminance against what is immediately
> behind them.**

Not colour — luminance. Two things of equal luminance in different hues do not
separate at a glance for anybody, and separate for nobody at all among the ~4%
of players who cannot tell red from green. `FrameLook.subject_contrast` measures
exactly this, on a disc inside the character against a ring of what is behind
them.

**Rim light is not the answer, and saying it was here was a mistake.** Phase 1
did the whole environment — ambient, fog, tonemapping, a night and a dusk — and
moved this number by nothing at all: 1.0–1.3:1 before, 1.0–1.2:1 after. The
reason is that this rule is about *mass*, not edges. A rim is a bright line a
few pixels wide; it makes an outline legible against a busy background, which is
worth having, but it does not change what value the character reads as when you
squint at it. The blue robot sits at the luminance of grass, of the building
walls, and of the floor, and no amount of lighting the air around it changes
that.

The answer is the character's own albedo and shading. Phase 2 built it: every
surface is assigned a **value band** and pulled toward it, ground low and
characters high, so the gap between the bands is the silhouette.

At the palette level the structure separates **6.8:1**. On screen the same shot
measures **2.5:1**, up from 1.0:1 — the difference is lighting and AgX, which
compress a contrast on its way to the frame. That is why the bands aim well past
3:1 rather than at it, and it is why 2.5:1 is where this currently stands rather
than 3.0.

Rim light is here as an edge cue on top, at low strength. It is worth about
0.3:1 on the measurement and it is not what carries the rule.

*Notan; Game Accessibility Guidelines; WCAG 2.2 arithmetic.*

### 4. Shadows are the colour of the sky

A shadow is not an absence of light, it is a surface lit only by skylight — so
it takes the sky's hue. Blue shadows under a warm sun is what "painted" looks
like, and black shadows is what "untuned renderer" looks like.

Free, because it is a change to the ambient term rather than an extra pass.

### 5. A neutral base palette, tinted per region

The palette is defined **once**, neutrally, and a region applies a hue and
saturation shift to it. Verdant here, cold and slate further north, warm and dry
somewhere else — all the same palette, moved.

The alternative — a hand-picked palette per biome — is how a game ends up with
regions that do not look like they belong to each other. This keeps rule 1 while
allowing variety, and it is the reason the terrain shader needs region weights
before it needs anything else.

### 6. Night is blue, quiet, and playable

Night must **read** as night — cool, low-contrast, low-saturation, stars — and
still be a thing you can walk around in. The moon does by night what the sun
does by day: it is a key light, dimmer and bluer, not an absence of one.

> **No more than 45% of a night frame may sit below the readable floor.**

Met as of Phase 1, and enforced: `world-night` measures 14%.

The alternative was considered and rejected: genuinely dark nights make torches
matter enormously, and they need a portable light source the game does not have.
Until it does, an unlit night is not atmosphere, it is a black screen.

### 7. The frame uses less range than it could, and none of it is clipped

Painterly means **compressed values**: no crushed blacks, no blown highlights,
and a deliberate mid-range. Detail lost to either end is lost for good, and both
ends are where an untuned tonemapper puts things.

Measured as `dark_fraction` and `bright_fraction`; bounded per shot.

### 8. Every number lives in one place

The palette, the fog curve, the ramp, the rim strength: all of it belongs in a
single `ArtTokens`, generated into whatever resources consume it — exactly what
`UiTokens` is to the interface theme, and for exactly the same reason. Eighty-four
per-node overrides across ten scenes is what the interface looked like before
that rule; a colour typed into a shader is the same mistake one layer down.

`ArtTokens` does not exist yet. It arrives in Phase 1, with the first thing that
needs it. This rule is written first so that it cannot arrive any other way.

---

## How this is checked

`FrameLook` measures a rendered frame and `shots.sh check` enforces per-shot
targets alongside the golden image and the draw-call budget:

| Measure | Rule | Enforced by |
|---|---|---|
| `hue_count` | 1 | `max_hue_count`, on every shot |
| `dark_fraction` | 6, 7 | `max_dark_fraction`, on every daylit shot |
| `bright_fraction` | 7 | reported; no shot clips yet |
| `subject_contrast` | 3 | `min_subject_contrast`, on `player-close` — the only shot where the character is large enough for it to mean anything |
| `low/high_luminance` | 7 | reported only; the right range is style |

**Subject contrast needs a subject.** The measure samples a disc inside the
character against a ring of background, both sized from the character's own
on-screen height. When the character is ten pixels tall — every wide shot — those
are two- and four-pixel samples dominated by the antialiased edge, and the number
compresses toward 1:1 whatever is true. So only `player-close` enforces the
target; the figure is still reported everywhere, and should be read as
uninformative on the vistas.

**The readable floor is calibrated, not chosen.** `FrameLook.DARK` began at 0.015
relative luminance, guessed before there was any frame to check it against, and
it turned out not to discriminate: it called the pre-Phase-1 night — a black
screen — 100% dark, and the night that replaced it, which is plainly playable,
90% dark. A measure that gives the same answer either side of the fix it exists
to verify is not a measure. Re-derived against those two frames, 0.004 separates
them 78% to 11%. Anything from 0.008 up is measuring how dark a night is, which
is not the question; night is supposed to be dark.

What it cannot do is say whether a frame looks good. It catches four ways of
being objectively wrong — crushed, blown, incoherent, unreadable — which a
golden image cannot, because a golden only knows whether something *changed*.

---

## Where we actually are

After Phase 2. Every figure is enforced by `shots.sh check`.

| Shot | Dark | Hues | Subject contrast |
|---|---|---|---|
| `world-noon` | 0% | 7 | — *(subject too small to measure)* |
| `base-exterior` | 0% | 7 | — |
| `terrain-detail` | 0% | 4 | — |
| `hud-gameplay` | 0% | 6 | — |
| `player-close` | 0% | 6 | **3.5:1** *(was 1.0:1)* |
| `world-dusk` | 0% | 5 | — |
| `world-night` | 15% | 1 | — |

**Rule 3 is met.** `player-close` measures 3.5:1 against the 3:1 target, and the
target is enforced. It took two phases and the second one was not the one that
finished it: Phase 2's value structure got from 1.0:1 to 2.5:1, and Phase 3's
grass took it past 3:1 by darkening the ground a character is actually read
against. A value band moves the palette; foliage moves what is *behind* the
character, and that turned out to be worth as much.

It holds against grass, which is what a character is usually seen against. It
does not hold against a building wall — there the separation is shape, shadow
and rim rather than value, and no palette can give all three pairings 3:1 at
once.

**Night and dusk stay fixed** through a ground that is now materially darker,
which cost a higher night ambient to pay for.

**The palette held.** 1–7 hues, where the ceiling is 3–9 per shot. Sharing one
shader family across terrain, structures and characters is most of why: every
surface is now drawn from the same small set of decisions.

---

## What is deliberately not here

- **A shared *shader*, not a shared *look* for characters.** The stylised
  shader gives every surface the same ramp, rim and value band. It does not fix
  a model whose albedo is nearly white to begin with, which is why the robot
  still reads pale. `ART.md` cannot make a placeholder into a character.
- **`ArtTokens` covers the air, not the sun or the sky.** It arrived in Phase 1
  holding the ambient, fog and tonemapping numbers, which were previously
  nowhere at all. The sun's colour and energy stay in `DayNightConfig` and the
  sky's palette in `SkyConfig` — both are resources the light and the sky shader
  already read, and copying them into `ArtTokens` would put a second version of
  each somewhere nobody looks, which is the exact failure rule 8 exists to
  prevent.
- **No `min_subject_contrast` on any shot.** Every shot fails it today, and a
  target set to what is currently wrong is a target that ratifies it. It goes in
  when Phase 1 lands the rim light, and `test_a_character_nobody_can_pick_out_of_the_grass_is_caught`
  already covers the check itself so it does not arrive untested.
- **No biome definitions.** Rule 5 is the shape; the regions themselves need
  terrain work that belongs to Phase 3.
- **Nothing about characters.** Silhouette design is the one part of this that
  is not derivable from a rule and not measurable afterwards. The placeholders
  stay until there is a person to replace them.
- **No claim that any of this makes it look good.** These rules make it
  *coherent* and *legible*. Those are prerequisites for looking good and they
  are not the same thing.
