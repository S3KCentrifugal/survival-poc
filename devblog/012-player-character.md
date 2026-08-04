# 012 — A character with legs

*2026-08-04 · commit `460bb9a`*

The player has been a red capsule with a small box stuck to the front of it since
movement landed. This post is about replacing it, and about the three things
that went wrong on the way — one of which had been quietly wrong for a day.

> **On the numbering:** this is post 012 because it is the twelfth *feature*.
> Posts 002–011 cover the vertical slice and are still to be written in arrears.
> Numbers follow the work, not the order the posts get typed.

## Sourcing: what I recommended, and what could actually be had

The shortlist was KayKit, Quaternius, Kenney, and a CC0 robot from the Godot
Asset Library — all CC0, all rigged, all with locomotion clips. Then I tried to
actually download them:

- **KayKit** sits behind itch.io's purchase flow. Even at a $0 minimum, getting
  the file means driving somebody's checkout. Not something to automate.
- **Quaternius** hosts on Google Drive. The page has no direct link at all; the
  download button opens a Drive folder.
- **Kenney's** pages render their download links client-side.
- The **[3D Godot Robot](https://github.com/AGChow/3D-Godot-Robot-Platformer-Character)**
  is a plain GitHub archive. `curl`, unzip, done.

So the robot it is. It is CC0, it is rigged, it has twenty animations, and it is
1.74 m tall — near enough to the 1.8 m collision capsule that nothing needed
scaling. It is also, unmistakably, a robot. It is a **placeholder**, and the
README beside it in `assets/characters/godot_robot/` says so along with its
provenance and licence.

The lesson worth keeping: *availability is a selection criterion.* The best asset
you cannot fetch loses to the adequate one you can, at least for a placeholder
whose entire job is to prove the pipeline works.

Files went where `CLAUDE.md` says they go — the untouched upstream archive to
`<games-root>/source/survival-poc/`, outside the repo, and only the
engine-ready `.glb` into `assets/`. Which is a reminder that `SYNC_REMOTE` is
still unset, so `source/` still has no backup path. It has contents now.

## The part that worked: no code changed

The entire swap was one scene edit and four strings:

```
idle_animation = &"Idle"
walk_animation = &"Run"
run_animation  = &"Sprint"
fall_animation = &"Fall"
```

That mapping looks like a mistake and is not. The rig came from a platformer,
where the base locomotion *is* a run — so its `Run` is our walk and its `Sprint`
is our run. Nothing in the codebase cares, because `AnimationConfig` exports the
clip name for each state separately. Post 008 argued that the state machine
should know nothing about rigs. This is what that buys: a character from a
different game, with different names, for a different genre, drops in without a
line of GDScript changing.

The `AnimationPlayer` reference was an optional `@export` that had been sitting
null since feature 8. It now points at `../Model/AnimationPlayer`.

## Trap 1: the importer eats part of the clip name

The `.glb` declares its animations as `Idle-loop`, `Run-loop`, `Sprint-loop`,
`Fall-loop`. I read those straight out of the file's JSON chunk and wrote them
into the config. Every one of them failed.

Godot's glTF importer treats a **`-loop` suffix as an instruction**: it sets the
animation's loop mode and then strips the suffix. In the engine the clips are
`Idle`, `Run`, `Sprint`, `Fall`.

What makes this worth a trap entry is the failure mode. A clip name that does
not exist is not an error. `AnimationPlayer.has_animation()` returns false, the
component skips the play call by design, and the character stands in a T-pose
sliding along the ground — which looks exactly like a physics bug, and would
have sent me looking in entirely the wrong file.

The fix was one line in a `.tres`. The insurance is a new test that asserts every
clip the config names exists in the rig, because nothing but a string connects
those two files.

## Trap 2: a 180° guess, and why you have to look

I wrote a 180° Y rotation onto the model node on the theory that the rig probably
faced `+Z`. The first close-up render showed it walking backwards.

There is no cleverness available here. Godot's convention is that a node faces
its local `-Z`, this rig already followed it, and my correction was the bug. I
deleted the transform and rendered again. `CLAUDE.md` already says to actually
look at visual changes rather than assume; this is the second time this week that
has caught something reasoning would not have.

Worth noting the game camera could not answer the question. At 18 m the character
is a smudge — the check needed a temporary close-up camera in the harness. Which
is its own finding, and moves "camera distance" from a matter of taste to the
strongest candidate for the next change.

## Trap 3: the test that had been passing on luck

Adding four strings to a `.tres` broke a **save registry** test written a day
earlier, three features away, that touches none of this.

`SaveRegistry.ids()` claimed to return ids in order:

```gdscript
var keys: Array[StringName] = _by_id.keys()
keys.sort()
```

`StringName` compares by **interned pointer, not by text**. That is the entire
point of the type — comparison is a pointer check rather than a string
walk — and it means `sort()` returns *allocation order*. Stable within a run, so
the test passed. Stable across runs, so it kept passing. Right up until four new
names — `Idle`, `Run`, `Sprint`, `Fall` — got interned during resource load and
shifted where the old ones sat.

The test was correct. The implementation was wrong, and had been wrong since it
was written; nothing in the test suite could distinguish "sorted" from "happened
to be in that order today". It now sorts through `String` explicitly, with a
comment saying why.

This is the good case of a flaky test: it flaked on a real bug rather than on
timing. If it had flaked a month from now, in a commit about something else
entirely, it would have cost an afternoon and probably been "fixed" by rewriting
the assertion.

## Where it leaves things

The robot walks, sprints with a visibly longer stride, idles, and falls, driven
by the same state machine that was driving nothing yesterday. The debug overlay
reads `state run` and `7.65 m/s (sprint)` while the legs move at a matching pace,
which is the first time any of this has been checkable by eye rather than by
assertion.

Next is almost certainly the camera. There is finally something down there worth
looking at, and at 18 m you cannot see it.
