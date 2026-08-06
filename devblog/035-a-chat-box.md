# 035 — A chat box, and a range check that aged badly

*5 August 2026 — covers the chat commit*

F12 shows and hides a chat box. Type into it, press Enter, and what you said
appears — on your screen, and on everyone else's if there is anyone else.

## A chat that cannot reach anyone is not usable

The ask was for a "usable" chat box, and a message log that only ever talks to
itself does not meet that word. The networking has existed since feature 26, so
chat is wired through it: `ChatService` sits between `ChatLog` and
`NetworkService`, and in single-player it is the same path with the send
skipped. Not a special case — the same shape as the rest of this project's
networking, where single-player is a host with one local player.

Two rules in that service are worth more than the rest of it:

**Your own message appears immediately, before any round trip.** Waiting for
the server to echo it back makes your own words arrive a few hundred
milliseconds late, which reads as the chat being broken on a bad connection —
exactly when you most want to be sure it sent.

**The name comes from the peer id the packet arrived on, never from inside the
packet.** A sender who picks their own display name picks everyone else's too.

## The sanitiser is the feature

A chat log is a place where **other people's text ends up on your screen**, so
the trimming and the length cap are the security-shaped part of this, and they
live in `ChatLog` — a `RefCounted` — where they can be tested with hostile
input rather than by asking someone to type it.

```gdscript
static func sanitise(text: String) -> String:
```

Newlines and tabs become **spaces** rather than being removed. A message that
can contain a newline can draw a fake second line — "Player 2: `\n`
`Player 1: I'm giving you all my mushrooms`" — and one that can contain a lot of
them can push the whole log off the screen. Other control characters go
entirely: there is no legitimate chat message containing an escape or a delete.

The length cap is enforced here rather than on the text box, because the text
box is not the only way a message arrives. The other way is a stranger's peer.

Writing the test for that produced a small, pleasing correction: my first
version fed `String.chr(0)` in as a null byte. Godot hands back U+FFFD, the
replacement character, which is printable and correctly survives — so the test
was asserting something about a character that was never there. The control
characters that can actually exist in a GDScript `String` are the ones worth
testing.

## The wire message, and the check that has to be paranoid

CHAT is the first variable-length message in a protocol that is otherwise all
fixed layouts a Rust server can read with a struct cast. The length rides in
**one byte**, deliberately: a message cannot exceed 255 bytes, so the bounds
check is unmissable and the buffer it lands in has a known ceiling.

```gdscript
var length := bytes.decode_u8(5)
if bytes.size() != 6 + length:
	return {}
```

The declared length is checked against the bytes actually present, never
trusted. This is the one message whose size a stranger chooses, so it is the
one place a lie about length would be read past the end of a buffer.

Truncation cuts on a **character** boundary, not a byte one. Cutting UTF-8
mid-sequence produces bytes Godot cannot decode, and the far end sees an empty
message rather than a shortened one — a mushroom emoji repeated 200 times has a
test to prove it comes back readable.

## The range check that aged badly

Adding `Kind.CHAT = 6` broke every chat packet instantly, silently, and in a way
that would have been genuinely unpleasant to find in a running game. Here is
the whole bug:

```gdscript
if first < Kind.HELLO or first > Kind.DESPAWN:
	return Kind.NONE
```

A range check whose upper bound is *whichever kind happened to be last when the
check was written*. Add a kind and it falls outside the range, `kind_of` returns
`NONE`, and the message is ignored — which is precisely what an unrecognised
kind is *supposed* to do, so there is no error, no warning, and nothing in the
log. A message that silently does not arrive.

It is a membership test now:

```gdscript
if first == Kind.NONE or not Kind.values().has(first):
	return Kind.NONE
```

and there is a test that walks every value of the enum and asserts each one is
recognised, so the next kind added cannot repeat it. The only reason this was a
five-minute problem is that the very first chat test asserted `kind_of` on an
encoded message.

I wrote that range check in feature 26 and it was correct on the day. The
lesson is not "I made a mistake"; it is that **a bound named after the current
last item is a line that must be edited every time the list grows**, and the
failure when it is not is invisible.

## The bit everyone forgets

`PlayerInputSource` reads the keyboard directly — that is the whole point of
feature 4's rule. So without any special handling, typing "we should go west"
walks you west, jumps, and throws four punches.

The fix belongs in exactly one place:

```gdscript
func poll() -> InputState:
	var state := InputState.new()
	if suspended:
		return state
```

Every consumer — movement, jumping, punching, picking up, using — reads intent
through that one object, so suspending it there suspends all of them at once
rather than each of them separately learning what a chat box is. `WorldRoot`
exposes `set_input_suspended()`, and the box calls it on focus in and focus out.

Returned *before* anything is read, so a key held when the box opened is not
still held when it closes.

Two tests cover the ways this goes wrong: that the player stops moving while
typing, and — the one that matters more — that hiding the box while the entry
has focus gives the keyboard back. A character that cannot move with no visible
cause is a much worse bug than one that walks while you type.

Escape lets go of the entry rather than closing the box, so a mistyped key does
not throw away what is on screen; the pause menu still gets Escape when nothing
in the chat wants it.

---

Next: [036 — Gold, merchants, and one key with one
owner](036-gold-and-merchants.md). Posts 002–011 and 025–027 are still owed.
