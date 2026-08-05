# 034 — Music nobody wrote, and soup

*5 August 2026 — covers the music and crafting commit*

Two unrelated features that turned out to share a shape: both are a pure
`RefCounted` doing the interesting part, with a thin node on top.

## Music with no music file

The obvious way to add background music is to find a track and commit it. That
means a licence to check, a few megabytes in git, and — in a year — a file
nobody can explain the provenance of.

So the music is **synthesised at runtime**. `MusicComposer` is a `RefCounted`
that turns a `MusicConfig` into 16-bit PCM. Nothing ships but the numbers.

It is not sophisticated. Three voices that cannot clash:

- a **drone** on the root for the whole loop,
- a **pad** chord that changes once a bar,
- a sparse **melody** on a random walk.

All of them on a minor pentatonic scale, which is the trick that does most of
the work: a pentatonic scale has no semitones in it, so any two notes sounding
together are consonant. Most of the ways generated music goes wrong are simply
unavailable.

Two details that matter more than they sound:

**Notes wrap past the end of the buffer.** A note starting in the last bar has
to finish at the *beginning*, or the loop clicks every thirty seconds forever.
`_mix` writes at `(start + offset) % frames`.

**The drone never stops.** It runs the entire loop with no envelope, so the
lowest and loudest voice cannot click at the seam by construction.

There is a test for the seam, and its shape is the part worth copying:

```gdscript
var step := absf(samples[0] - samples[samples.size() - 1])
# ...largest ordinary sample-to-sample step...
assert_true(step <= largest, "the loop jumps %f at the seam...")
```

Compared against how far the waveform moves between *ordinary* neighbouring
samples, not against a fixed threshold. A magic number there would be a number
with no meaning; this asks the actual question, which is "is the seam more of a
discontinuity than the music already contains".

I should be straight about the limit of this: the tests prove it is not silent,
does not clip, stays on its scale, is deterministic and has no step at the loop
point. They cannot prove it is *pleasant*. That is what ears are for, and this
one was never going to be more than a placeholder that knows it is one.

### One second is fine once and not fine forty times

Rendering thirty seconds of audio in GDScript takes about 1.2 seconds. The test
suite mounts the world dozens of times.

The render is a pure function of the config, so the answer is cached — keyed on
the *values*, so editing a config at runtime regenerates rather than quietly
playing the old music. The cache holds the **bytes**, not the stream, because a
static variable holding a `Resource` is still holding it when the engine counts
objects on the way out and gets reported as a leak on an otherwise clean run.

Then there was a second leak: `AudioStreamPlaybackWAV` and `AudioStreamWAV`,
refcount 1, on every headless run. Godot's headless audio server takes a
playback and never mixes, so it never gives it back. Stopping the player did
not help; freeing it did not help.

The fix is not a test hack, which is why I am comfortable with it:

```gdscript
if not play_without_display and DisplayServer.get_name() == "headless":
	return
```

A headless run has no speakers. Synthesising thirty seconds of audio and
holding a megabyte of samples for a process that cannot play them is waste
independent of any test. The export exists because a headless *client* is a
thing that could exist and should be able to say so.

## Soup, and a second verb

The bench needed exactly what `PickupCollector` already did — find the nearest
thing in reach — so that search moved out into `Proximity`, which is duck-typed
on `world_position()` and `is_available()`. No base class, and none needed:
anything findable just has those two methods. Two near-identical proximity
searches is how a codebase ends up with one of them quietly using a different
reach.

**F and E are different keys on purpose.** F takes a thing away; E operates a
thing that stays. Folding both behind one key means deciding what a press means
when a mushroom is growing next to the bench, and that question has no good
answer. The HUD shows both prompts at once when both are in reach, on separate
lines — showing only the nearer one means a mushroom by your foot hides the
bench, and a prompt that comes and goes as you shuffle is worse than two lines.

Adding `use` to the input path cost one bool on `InputState`, one line in each
source, and bit 4 of the protocol's button byte. Four bits still spare.

### The rule that took the most thought

```gdscript
func has_room_for_result(inventory: Inventory) -> bool:
```

Crafting checks room for the output *after* notionally removing the
ingredients, because the ingredients usually free the room the output needs.
Three mushrooms in a one-slot bag can become one soup; refusing that because
"your bag is full" is a rule nobody could work out from the outside.

And the counterpart, which is the worst bug this system could have had:

```gdscript
func craft(inventory: Inventory) -> int:
	if not can_craft(inventory):
		return 0
	# only now remove the ingredients
```

All or nothing. A craft that took the mushrooms and then found nowhere to put
the soup would be unrecoverable and completely silent.

Recipes take a **list** of ingredients even though the only recipe today takes
one thing. The list costs a few lines now; discovering that soup also wants
water after the signature is load-bearing costs a refactor.

## A hard-coded height, buried

The bench went into the scene at `y = 0`. The building floor is wherever the
terrain and the pad put it — which, after feature 33 made the ground 44 metres
tall, was several metres up. The bench was under the floor, the player spawned
inside it and fell to y = -255.

Nothing errored. The screenshot was a featureless sky, and the only reason I
knew what had happened was the debug overlay reading `state fall`.

The bench is now placed by `WorldRoot` from a `Vector2`, exactly as the player
and companion already were — dropped onto the terrain at load. A hard-coded
height was correct for precisely as long as the terrain did not change. There
is a test asserting it stands within 20 cm of the floor, so the next terrain
change says so out loud.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
