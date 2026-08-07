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

Rim light is the intended answer, and it is free.

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
| `subject_contrast` | 3 | `min_subject_contrast` — **not set on any shot yet**, see below |
| `low/high_luminance` | 7 | reported only; the right range is style |

What it cannot do is say whether a frame looks good. It catches four ways of
being objectively wrong — crushed, blown, incoherent, unreadable — which a
golden image cannot, because a golden only knows whether something *changed*.

---

## Where we actually are

Measured on the committed shots, before any of the rules above have been
implemented. These are the numbers Phase 1 has to move.

| Shot | Mean luminance | Dark | Hues | Subject contrast |
|---|---|---|---|---|
| `world-noon` | 0.232 | 0% | 5 | **1.2:1** |
| `base-exterior` | 0.235 | 0% | 5 | **1.2:1** |
| `terrain-detail` | 0.202 | 0% | 4 | — |
| `hud-gameplay` | 0.189 | 2% | 4 | **1.1:1** |
| `player-close` | 0.324 | 0% | 2 | **1.1:1** |
| `world-dusk` | 0.037 | **71%** | 2 | 1.0:1 |
| `world-night` | 0.002 | **100%** | 1 | 1.0:1 |

Three things fall out of that table, and none of them were visible before it
existed.

**The character does not read against the world, anywhere.** 1.0–1.3:1 in every
shot, against a target of 3:1. The blue robot sits at very nearly the luminance
of grass, of the building walls, and of the floor — so it is separated from the
background by hue alone, which is to say by nothing at a glance. This is the
single largest failing and it is rule 3.

**Night is not dark, it is absent.** 100% of `world-night` is below the readable
floor and its mean luminance is 0.002. It is not a stylistic choice that went
too far; there is simply no ambient term at night.

**Dusk is already night.** 71% dark at a time of day that should be the most
attractive lighting in the game. The day/night curve falls off far too early,
which means the sunset — the cheapest beautiful thing in any outdoor game — is
currently a few minutes of brown before black.

The palette is in better shape than expected: 2–5 hues everywhere, 43–76%
sitting in one dominant hue. Rule 1 is close to satisfied by accident, mostly
because the world is grass. It will get harder, not easier.

---

## What is deliberately not here

- **No `ArtTokens` yet.** Rule 8 says where the numbers go; Phase 1 puts them
  there. Writing a palette before anything consumes it produces a palette that
  is wrong in ways nobody can see.
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
