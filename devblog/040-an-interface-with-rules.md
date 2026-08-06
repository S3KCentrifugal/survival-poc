# 040 — An interface with rules

*6 August 2026 — covers the design system commit*

> "I want the user interfaces and popups like vendor screens to look a lot more
> professional. follow user experience design guidelines. and also identify
> which user experience design guidelines to follow."

The second sentence is the harder one, and it is the right thing to have asked
for. "Make it look better" is a preference and dies in the first disagreement
about it. "Follow *these* guidelines" is a standard, and a standard can be
tested.

## The diagnosis

Before touching anything:

```
84  per-node theme_override entries across 10 scenes
 6  arbitrary font sizes (12, 13, 14, 15, 20, 22)
10  near-identical panel background colours
```

None of that is a mistake anyone made. It is what happens when each screen is
styled on the day it is written: the store got `Color(0.11, 0.12, 0.14, 0.97)`
because that looked right, and the chat box got `Color(0.06, 0.07, 0.08, 0.72)`
three features later because *that* looked right, and neither knew about the
other.

## The four sources

Written down in `UI.md` with what each is for, because a guideline you cannot
trace is a preference wearing a lanyard.

- **Nielsen's 10 usability heuristics** — behaviour. Feedback, recovery,
  consistency. Forty years old and still the shortest list that catches most
  interface mistakes.
- **WCAG 2.2 AA** — contrast, target size, focus visibility. The only widely
  agreed *measurable* accessibility bar, which is the whole reason to pick it: a
  number can be tested and "looks readable" cannot.
- **Game Accessibility Guidelines** — the games-specific parts. WCAG assumes a
  document; a HUD over a moving 3D scene is not a document.
- **Fitts's law** — explains *why* a 40 px button beats a 24 px one rather than
  asserting it.

## Tokens, then a theme

`UiTokens` holds every number: a 4 px spacing grid, a six-step type scale, the
palette, radii, control heights, durations. `UiThemeBuilder` turns those into a
Godot `Theme` registered as `gui/theme/custom`, which every `Control` inherits.

The theme is **generated and committed**, not hand-authored. A `.tres` theme is
several hundred lines of `Button/styles/normal = SubResource(...)` that nobody
can review, and every value in it would be a second copy of a token.

The rule that falls out, and the one worth remembering:

> **The theme owns appearance. A scene owns arrangement.**

`theme_override_colors/font_color` in a scene is a bug — that is a screen
deciding what a label looks like. `theme_override_constants/separation = 24` is
fine — that is a panel saying its two columns sit further apart than the
default. A test enforces exactly that split, and only that split.

## The tests found three things I had got wrong

This is the part I did not expect. I wrote `test_ui_theme.gd` to stop the
palette drifting later; it failed on the palette I had just shipped.

**Danger red was 4.25:1 on the raised surface.** I had checked every colour
against the panel background and none against the surface buttons and rows are
actually drawn on. A palette verified against one background is a palette
verified for one screen.

**The focus ring was 2.16:1 against the accent.** It cleared every grey
comfortably and vanished on the one blue button in the game — which is to say,
on the button most likely to have focus.

**The pause menu had no root `Control`.** A structural assumption in my own test,
wrong about my own scene.

None of these is subtle once measured. All three are invisible to the eye at a
glance, which is exactly why the numbers are in a test rather than in my head.

## The shop, specifically

The screen the request named. What changed, and why each one:

- **Both purses moved into the header.** "How much gold do I have" and "how much
  do they have" are the first things anyone checks and were in a single line
  under the buttons — the last place you look. Hierarchy is telling the eye what
  to read first, and size and position are how you say it.
- **Rows are full-width and left-aligned**, in one order: item, price, then the
  number that decides whether you can. A column of prices can now be scanned
  down an edge instead of re-read line by line.
- **Sold-out and unaffordable rows keep their border.** A disabled control with
  no border reads as a label, and then nobody knows there was anything to
  enable. It says *why* in its tooltip, next to itself, rather than in a status
  line elsewhere.
- **The accent got removed from the rows.** My first pass made every sell row
  the accent colour, which is precisely the mistake the token comments warn
  about: the accent means "this is the answer", and a shop has no single answer.
  Spending it on every row spends it on nothing.

## What is deliberately not done

In `UI.md` so nobody assumes otherwise: no display-size scaling, no text-size
setting, no reduced-motion setting, and no controller navigation — focus
*styling* is correct but nothing sets up focus neighbours, so a pad cannot walk
the UI yet.

The debug overlay and dev console opt out on purpose. They are developer tools
with a monospace look, and holding them to a player interface's rules would make
them worse at their job.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
