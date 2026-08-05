# 016 — Over the shoulder, and a correction

*2026-08-04 · commit pending*

The camera was fixed-yaw isometric from feature 3. It is now third-person: five
metres behind the character, twenty degrees down, mouse to turn, wheel to zoom.

The interesting parts are a design trap that would have made the obvious
implementation unusable, a distinction in the input abstraction that turned out
to be load-bearing, and a bug this feature exposed that has been in the game
since post 012 — sitting in plain sight, invisible to the camera we had.

## The trap: do not let the camera follow the character

The obvious build is: put the camera behind the character, keep it there as they
turn, and make WASD relative to the camera. Every part of that is reasonable and
together they chase their own tail.

Hold a sideways key. The character turns to face where it is travelling (post
013). The camera swings to stay behind it. But the camera is what *defines* the
direction that key means — so the key now points somewhere new, the character
turns again, and you walk in a circle for as long as you hold it.

The fix is the thing every third-person game already does: **the player owns the
yaw**. The mouse turns the camera, the camera never turns itself, and the loop
is cut because one end of it is a human. The camera still swings behind the
character on spawn and on teleport, where there is no loop to close.

Numbers are the usual ones: 5 m back, 20° down, zoom 1.5–14 m, 0.22° per pixel.
Far enough to see what is around you, close enough that the character is the
subject.

## The distinction that turned out to matter

`InputState` is described in post 004 as "one tick of intent". The obvious move
was to add `look` and `zoom` to it. I did, and then noticed the bug before
running it:

**Movement and the camera share one input source.** Movement polls in
`_physics_process`, the camera in `_process`. If `poll()` drains the accumulated
mouse movement, whichever ran first gets the flick and the other gets nothing —
alternating unpredictably with frame timing.

The real distinction is that `move` and `sprint` are **states**. They describe
what is being held right now, two things can read them in the same tick, and
reading is free. `look` and `zoom` are **deltas** — they describe what happened
since someone last asked, and reading one twice turns the camera twice for a
single flick of the wrist.

So they are not in `InputState` at all. `InputSource` grew
`consume_look()` / `consume_zoom()`, named for the fact that reading them
destroys them, and exactly one thing is supposed to call each. That is a
sharper abstraction than the one I started with, and it came from a
frame-ordering bug rather than from taste.

A `RefCounted` cannot receive input events, so `WorldRoot` forwards them to the
source. Slightly awkward, and better than the alternative: the rule that only
`PlayerInputSource` may touch a device is worth more than letting the camera
listen for itself.

## Camera collision was not optional

The player starts inside a 12 × 8 m building with three-metre walls. A camera
five metres behind them is five metres inside a wall, and the first minute of
the game renders the inside of the brickwork.

So the camera casts a ray from the character to where it wants to be and stops
short of whatever it hits. One ray, one margin — the cheap version. It is enough
for boxes, and a proper spring arm can come when there is geometry that needs
one.

## The correction: the character has been backwards since post 012

Post 012 says I put a 180° rotation on the model, saw it walk backwards,
removed it, and confirmed the fix by rendering.

**That was wrong.** The first third-person frame I rendered showed the robot's
face while it walked *away* from the camera. The mesh is authored facing +Z, the
rotation was correct, and I deleted it on the strength of a screenshot I
misread.

Worth being precise about why the misreading survived. From thirty metres up, at
a fifty-degree pitch, a stylised robot's front and back are both a blue blob
about ninety pixels tall. I looked at the image — which is the right instinct,
and is what `CLAUDE.md` demands — but the image could not answer the question I
was asking it. **Looking is not enough if the view cannot show the thing.**

The third-person camera cannot fail to show it: the character fills a third of
the screen with the back of its head. The rotation is restored.

Per this folder's rule, post 012 stands as written. This is the correction.

## Cleanups

`prefabs/isometric_camera.tscn` is now `third_person_camera.tscn`, and the node
in `main.tscn` is `PlayerCamera`. The old name described a camera that no longer
exists, and a name that lies is worse than no name.

`PROGRESS.md`'s section on feature 3 still describes a fixed isometric camera,
because that is what feature 3 was. Section 16 says what replaced it.

## What is left rough

Mouse capture is on by default, with Escape to release, a click to take it back,
and the console releasing it while open. If capture misbehaves on a particular
desktop, `CameraConfig.mouse_look` switches to hold-right-button instead.

Obstruction is a **single ray** from the character to the camera. The terrain is
a `StaticBody3D` on the default layer, so hillsides stop the camera as walls do
— but one ray only knows about what is directly between two points. The camera's
near plane has corners, and a wall edge that misses the ray can still clip
through one of them. A real spring arm sweeps a shape rather than a line; that
is the upgrade when geometry gets more complicated than boxes.
