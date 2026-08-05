class_name InputSource
extends RefCounted
## Where an actor's intent comes from.
##
## The whole point of the abstraction: gameplay code never touches the [Input]
## singleton. It holds an [InputSource] and asks it what the actor wants. Swap
## the source and the same movement code drives a player, an enemy, a replay,
## or a networked client.
##
## This is an interface rather than a component because there is exactly one
## method and no state to compose. Subclasses override [method poll].

## Intent for this tick. The returned object may be reused between calls --
## copy it (see [method InputState.copy]) before storing it.
func poll() -> InputState:
	return InputState.new()


## Mouse movement asked for since the last call, in pixels: x right, y down.
## Cleared by reading it.
##
## Deliberately not part of [InputState]. That is a snapshot of what is being
## *held*, and two components can read it in the same tick without harm. Look
## and zoom are *deltas* -- read one twice and the camera turns twice for a
## single flick of the wrist -- so they are drained by whoever acts on them, and
## exactly one thing should.
func consume_look() -> Vector2:
	return Vector2.ZERO


## Zoom asked for since the last call, in wheel notches, positive pulling the
## camera out. Cleared by reading it.
func consume_zoom() -> float:
	return 0.0
