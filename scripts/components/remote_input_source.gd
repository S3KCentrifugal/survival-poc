class_name RemoteInputSource
extends InputSource
## Intent that arrived over the network.
##
## The fourth driver, and the one feature 4 was actually built for:
##
## > That is what lets an enemy run the player\'s movement code, a test drive a
## > character with no keyboard, and **a server eventually receive intent from a
## > client**.
##
## A server holds one of these per connected player and feeds it decoded INPUT
## messages. [MovementComponent] cannot tell it from a keyboard, which is the
## whole point and the reason none of movement had to change.

## The last intent received. Held rather than consumed: a dropped packet should
## leave a player running in the direction they were last known to be running,
## not stop them dead.
var state: InputState = InputState.new()

## Ticks since the last packet, so a server can notice a player who has gone
## quiet and stop simulating them as though they were still holding W.
var _stale_ticks: int = 0

## After this many ticks with nothing, intent is dropped. A second at 60 Hz.
var stale_after: int = 60


func poll() -> InputState:
	return state


## Takes one decoded INPUT.
func accept(decoded: Dictionary) -> void:
	if decoded.is_empty():
		return
	state = NetworkProtocol.input_state_from(decoded)
	_stale_ticks = 0


## Counts a tick with nothing received, and clears intent once it has been
## quiet too long.
func age(ticks: int = 1) -> void:
	_stale_ticks += ticks
	if _stale_ticks >= stale_after:
		state = InputState.new()


func is_stale() -> bool:
	return _stale_ticks >= stale_after
