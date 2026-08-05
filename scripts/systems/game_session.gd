class_name GameSession
extends Node
## What kind of session this process is running.
##
## Single-player is a **host with one local player and no socket**, not a
## separate mode with its own code path. Two paths diverge, and every
## multiplayer bug then becomes one that only reproduces in multiplayer. See
## MULTIPLAYER.md.
##
## Deliberately thin. It answers what kind of session this is; it does not open
## sockets, spawn players or replicate anything, because none of that exists
## yet and inventing it here would be guessing at what step 3 needs.

signal mode_changed(mode: Mode)

enum Mode {
	## One player, no socket. The default, and what `./run.sh` gives you.
	SINGLE_PLAYER,
	## Simulating for others as well as yourself.
	HOST,
	## Someone else is simulating; this process renders and sends intent.
	CLIENT,
}

## Players a server is built to hold. Not enforced here -- it is the number the
## architecture is sized against, recorded where the design can see it.
const TARGET_PLAYERS: int = 100

@export var mode: Mode = Mode.SINGLE_PLAYER


## Whether this process decides what happens.
##
## True for a single-player session as well as a host: they are the same thing
## with a different number of players.
func is_server() -> bool:
	return mode != Mode.CLIENT


func is_single_player() -> bool:
	return mode == Mode.SINGLE_PLAYER


## Whether other machines are involved. False in single-player even though it is
## a server, which is the distinction presentation cares about.
func is_networked() -> bool:
	return mode != Mode.SINGLE_PLAYER


## Switches mode. Public so a menu, a test or a launch flag can set it before
## anything else reads it.
func set_mode(new_mode: Mode) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	mode_changed.emit(mode)


static func mode_name(value: Mode) -> String:
	match value:
		Mode.HOST:
			return "host"
		Mode.CLIENT:
			return "client"
		_:
			return "single-player"
