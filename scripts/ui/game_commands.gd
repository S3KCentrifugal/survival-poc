class_name GameCommands
extends RefCounted
## The commands this particular game offers its developer console.
##
## Kept apart from [DevConsole] so the console stays a parser and a registry
## with no opinion about survival games. Everything it needs is handed to it;
## anything missing produces a sentence saying so rather than a crash, because
## the console is most useful in a half-built scene.

var player: CharacterBody3D
var health: HealthComponent
var stamina: StaminaComponent
var movement: MovementComponent
var day_night: DayNightComponent
var terrain: Terrain
var tree: SceneTree

## Optional -- without one the networking commands say so rather than crash.
var network: NetworkService
var session: GameSession


## Registers everything into [param console].
func install(console: DevConsole) -> void:
	console.register(
		DevCommand.new(&"where", "where", "print where the player is standing", 0, 0, _where)
	)
	console.register(
		DevCommand.new(&"tp", "tp <x> <z>", "teleport to a spot on the ground", 2, 2, _teleport)
	)
	console.register(
		DevCommand.new(
			&"time", "time <hh:mm|hours>", "set the time of day", 1, 1, _set_time
		)
	)
	console.register(
		DevCommand.new(&"heal", "heal [amount]", "heal, or fully heal", 0, 1, _heal)
	)
	console.register(DevCommand.new(&"hurt", "hurt <amount>", "take damage", 1, 1, _hurt))
	console.register(DevCommand.new(&"kill", "kill", "take enough damage to die", 0, 0, _kill))
	console.register(
		DevCommand.new(
			&"stamina", "stamina [amount]", "set stamina, or refill it", 0, 1, _set_stamina
		)
	)
	console.register(
		DevCommand.new(&"speed", "speed <m/s>", "set walk speed", 1, 1, _set_speed)
	)
	console.register(DevCommand.new(&"quit", "quit", "close the game", 0, 0, _quit))
	console.register(
		DevCommand.new(&"host", "host [port]", "open a server on this machine", 0, 1, _host)
	)
	console.register(
		DevCommand.new(&"join", "join <address> [port]", "connect to a server", 1, 2, _join)
	)
	console.register(
		DevCommand.new(&"net", "net", "who is connected, and as what", 0, 0, _net)
	)
	console.register(
		DevCommand.new(
			&"tuning", "tuning [path]", "export tuning as JSON for a server", 0, 1, _tuning
		)
	)


func _where(_arguments: PackedStringArray) -> String:
	if player == null:
		return "no player"
	var at := player.global_position
	var ground := "?" if terrain == null else "%.2f" % terrain.height_at_world(at)
	return "x %.2f  y %.2f  z %.2f   (ground %s)" % [at.x, at.y, at.z, ground]


## Teleports to a spot on the ground plane, putting the player *on* the terrain
## rather than at whatever height they happened to be, which is almost always
## what you meant and saves a second command to stop falling.
func _teleport(arguments: PackedStringArray) -> String:
	if player == null:
		return "no player"
	var x := DevConsole.number(arguments[0])
	var z := DevConsole.number(arguments[1])
	if is_nan(x) or is_nan(z):
		return "x and z must be numbers"

	var destination := Vector3(x, 0.0, z)
	if terrain != null:
		destination.y = terrain.height_at_world(destination) + 0.2
	player.global_position = destination
	player.velocity = Vector3.ZERO
	return "moved to %.1f, %.1f" % [x, z]


func _set_time(arguments: PackedStringArray) -> String:
	if day_night == null:
		return "no day/night cycle"
	var time := DayNightCycle.time_from_clock(arguments[0])
	if time < 0.0:
		return "not a time: %s (try 07:30 or 19)" % arguments[0]
	day_night.set_time_of_day(time)
	return "time is now %s" % day_night.time_string()


func _heal(arguments: PackedStringArray) -> String:
	if health == null:
		return "no health component"
	var amount := health.maximum() if arguments.is_empty() else DevConsole.number(arguments[0])
	if is_nan(amount):
		return "amount must be a number"
	health.heal(amount)
	return "health %.0f / %.0f" % [health.current(), health.maximum()]


func _hurt(arguments: PackedStringArray) -> String:
	if health == null:
		return "no health component"
	var amount := DevConsole.number(arguments[0])
	if is_nan(amount):
		return "amount must be a number"
	health.take_damage(amount)
	var state := "alive" if health.is_alive() else "dead"
	return "health %.0f / %.0f  (%s)" % [health.current(), health.maximum(), state]


func _kill(_arguments: PackedStringArray) -> String:
	if health == null:
		return "no health component"
	health.take_damage(health.maximum())
	# Nothing handles death yet, so say so rather than leave you wondering why
	# the world carried on.
	return "health 0 -- the died signal fired, but nothing listens to it yet"


func _set_stamina(arguments: PackedStringArray) -> String:
	if stamina == null:
		return "no stamina component"
	var amount := stamina.maximum() if arguments.is_empty() else DevConsole.number(arguments[0])
	if is_nan(amount):
		return "amount must be a number"
	stamina.set_current(amount)
	return "stamina %.0f / %.0f" % [stamina.current(), stamina.maximum()]


func _set_speed(arguments: PackedStringArray) -> String:
	if movement == null or movement.config == null:
		return "no movement component"
	var speed := DevConsole.number(arguments[0])
	if is_nan(speed) or speed <= 0.0:
		return "speed must be a positive number"
	# Duplicated, or this edits the .tres every actor shares -- see post 013.
	movement.config = movement.config.duplicate()
	movement.config.walk_speed = speed
	return "walk speed %.2f m/s (sprint %.2f)" % [
		speed, speed * movement.config.sprint_multiplier
	]


func _host(arguments: PackedStringArray) -> String:
	if network == null:
		return "no network service"
	var port := (
		int(DevConsole.number(arguments[0], NetworkService.DEFAULT_PORT))
		if not arguments.is_empty()
		else NetworkService.DEFAULT_PORT
	)
	var error := network.host(port)
	if error != OK:
		return "could not host on %d: %s" % [port, error_string(error)]
	return "hosting on %d for up to %d players" % [port, NetworkService.MAX_PLAYERS]


func _join(arguments: PackedStringArray) -> String:
	if network == null:
		return "no network service"
	var port := (
		int(DevConsole.number(arguments[1], NetworkService.DEFAULT_PORT))
		if arguments.size() > 1
		else NetworkService.DEFAULT_PORT
	)
	var error := network.join(arguments[0], port)
	if error != OK:
		return "could not reach %s:%d: %s" % [arguments[0], port, error_string(error)]
	return "connecting to %s:%d" % [arguments[0], port]


func _net(_arguments: PackedStringArray) -> String:
	if session == null and network == null:
		return "no networking"
	var mode := "?" if session == null else GameSession.mode_name(session.mode)
	if network == null:
		return "mode %s" % mode
	return "mode %s  players %d/%d  peers %s" % [
		mode, network.player_count(), NetworkService.MAX_PLAYERS, network.peers()
	]


## Dumps the .tres tuning so something that is not Godot can read the same
## numbers. See MULTIPLAYER.md.
func _tuning(arguments: PackedStringArray) -> String:
	var path := arguments[0] if not arguments.is_empty() else TuningExport.DEFAULT_OUTPUT
	if not TuningExport.write(path):
		return "could not write %s" % path
	return "exported %d resources to %s" % [TuningExport.count(), path]


func _quit(_arguments: PackedStringArray) -> String:
	if tree == null:
		return "no scene tree"
	tree.quit()
	return "closing"
