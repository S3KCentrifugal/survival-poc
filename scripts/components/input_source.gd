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
