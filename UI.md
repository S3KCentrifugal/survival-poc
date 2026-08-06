# Interface guidelines

What this project's screens follow, and why. `CLAUDE.md` holds the enforceable
short version; this is the reasoning behind it.

The rules below are not invented. Each one names where it comes from, because a
guideline you cannot trace is a preference, and preferences do not survive
disagreement.

---

## The sources

Four, chosen because they cover different things and none of them is a matter
of taste.

| Source | What it covers | Why this one |
|---|---|---|
| [Nielsen's 10 usability heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/) (1994, revised 2020) | Behaviour: feedback, recovery, consistency | Forty years old and still the shortest list that catches most interface mistakes |
| [WCAG 2.2](https://www.w3.org/TR/WCAG22/) level AA | Contrast, target size, focus visibility | The only widely agreed *measurable* accessibility bar. A number can be tested; "looks readable" cannot |
| [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/) | Games specifically: text size, colour-blindness, remapping | WCAG assumes a document. A HUD over a moving 3D scene is not a document |
| Fitts's law (1954) | Target size and distance | Explains *why* a 40 px button beats a 24 px one, rather than asserting it |

Godot's own [UI design](https://docs.godotengine.org/en/stable/tutorials/ui/index.html)
docs supply the mechanism — themes, type variations, containers — not the
principles.

---

## The rules

### 1. One theme, no per-screen styling

**The theme owns appearance. A scene owns arrangement.**

`resources/ui/game_theme.tres` is the project-wide theme
(`gui/theme/custom`). Godot walks up the tree for a theme item, so setting one
there styles every button in the game — including buttons written next year by
somebody who has not read this file. That is the point: the default has to be
right, because the default is what most things will use.

- Setting `theme_override_colors/*`, `theme_override_fonts/*`,
  `theme_override_font_sizes/*` or `theme_override_styles/*` in a scene is a
  bug. `test_no_screen_restyles_itself` fails on it.
- Setting `theme_override_constants/separation` **is** allowed: that is a panel
  saying its columns sit further apart than the default, which is layout.
- Need a different look? Add a **type variation** to the theme
  (`Title`, `Card`, `PrimaryButton`, `HealthBar`) and ask for it by name.

Before this rule there were 84 per-node overrides across 10 scenes, 6 arbitrary
font sizes and 10 near-identical panel colours — which is what "each screen was
styled when it was written" produces.

*Nielsen #4, consistency and standards.*

### 2. Every number comes from the scale

`UiTokens` holds the spacing scale (4 px grid), the type scale (12/14/16/20/24/32),
the palette, radii, control sizes and durations. Nothing else defines a number.

Inconsistent spacing is the most legible sign of an unconsidered interface: the
eye reads 12 next to 14 as a mistake long before it can say why. A scale removes
the decision, which is the point — fewer decisions, more consistency.

A screen should rarely use more than three type sizes.

### 3. Contrast is measured, not judged

WCAG 2.2 AA: **4.5:1** for body text, **3:1** for large text (≥24 px) and for
the boundary of anything interactive.

Every palette colour is checked against **every** surface it can appear on, by
`test_every_text_colour_passes_contrast_on_every_surface`. The first version of
this palette passed on the panel surface and failed at 4.25:1 on the raised
surface, which is the one buttons and rows are drawn on — a palette verified
against one background is a palette verified for one screen.

### 4. Colour means one thing, and never means it alone

`DANGER` is damage and loss. `WARNING` is stamina. `INFO` is progress. `GOLD` is
currency. `SUCCESS` is a completed action. A red that sometimes means damage and
sometimes means "this row is different" means nothing.

Around 4% of players cannot separate red from green, so **anything said in
colour is also said in text or shape**. A greyed-out button says why in its
tooltip; a low health bar shows a number as well as a colour.

*Game Accessibility Guidelines: "Ensure no essential information is conveyed by
colour alone."*

### 5. Hierarchy: say what to read first

Every panel reads top-down in the same order: **title → the numbers a decision
depends on → the choices → status → how to leave.**

The shop is the worked example. Both purses moved from a line under the buttons
into the header, because "how much gold do I have" is the first thing anyone
checks and the last place they should have to look for it.

### 6. Targets you can hit

Fitts's law: acquisition time falls with target size. Buttons are 40 px tall,
inventory slots 72 px square. WCAG 2.2's minimum pointer target is 24 px; 40
clears it with room, and a slot you drag from needs more than a slot you click.

Rows are full-width and left-aligned, so a list can be scanned down an edge
rather than re-read line by line.

### 7. Every state is visible, including the ones nobody designs

- **Hover** — lighter fill, stronger border.
- **Pressed** — sunken.
- **Disabled** — dimmed text but the border **stays**. A disabled control with
  no border reads as a label, and then nobody knows there was anything to
  enable.
- **Focus** — a 2 px ring, visibly different from hover, and light enough to
  clear the accent it may sit on. A player on a keyboard or a pad has nothing
  else telling them where they are.

*WCAG 2.2 §2.4.11 focus appearance; Nielsen #1, visibility of system status.*

### 8. Say why, next to the thing

A disabled action explains itself where it is disabled — "Not enough gold", "You
have none to sell", "Need 2 more Mushroom". Never a message elsewhere on screen,
and never silence.

*Nielsen #9, help users recognise and recover from errors.*

### 9. Every modal behaves the same way

`ModalPanel` gives all of them: a scrim, the cursor released, gameplay input
suspended, Escape closes, and the key that opened it closes it. One component,
so a fix lands once — devblog 038 is what happens otherwise.

Modals do **not** pause the game. Pausing is for the pause menu; a shop that
stops the world cannot exist in multiplayer.

*Nielsen #3, user control and freedom.*

### 10. Motion is fast or absent

120 ms for a state change, 160 ms for a panel. Anything past ~250 ms reads as
lag rather than polish. No motion is better than slow motion.

---

## What is not done yet

Honest list, so nobody assumes otherwise.

- **No scaling for display size.** The theme is tuned for 1080p and the project
  stretches with `canvas_items`. A 4K player gets a small interface.
- **No text-size setting.** Game Accessibility Guidelines asks for one and the
  settings menu does not have it.
- **No reduced-motion setting.** Nothing animates enough to need one *yet*,
  which will stop being true the moment anything does.
- **No controller navigation.** Focus styling is in place and correct; nothing
  sets up focus neighbours, so a pad cannot walk the UI.
- **The debug overlay and dev console deliberately opt out.** They are
  developer tools with their own monospace look, and holding them to a player
  interface's rules would make them worse at their job.
