class_name ExperienceComponent
extends Node
## What a character has earned, and what level that makes them.
##
## Holds one number. Everything about what that number *means* is
## [ExperienceTable]'s, and everything about what earns it is in the signals it
## listens to -- so awarding experience for crafting later is a connection, not
## a change to this file.

## Emitted whenever experience is earned, with the amount and the new total.
signal gained(amount: int, total: int)

## Emitted once per level crossed, in order. A single kill that crosses two
## levels emits twice, because a UI that plays a fanfare should play two.
signal levelled_up(level: int)

@export var config: ExperienceConfig

## Where combat experience comes from. Optional -- a character with no fists
## still has a level.
@export var attack: AttackComponent

var _total: int = 0
var _table: ExperienceTable


func _ready() -> void:
	_ensure_table()
	if attack != null:
		attack.hit.connect(_on_hit)
		attack.killed.connect(_on_killed)


## Adds experience and announces any levels it bought.
##
## Negative awards are ignored rather than clamped: experience going *down* is
## a bug somewhere else, and silently applying it hides that.
func award(amount: int) -> int:
	if amount <= 0:
		return 0
	_ensure_table()
	var before := level()
	_total += amount
	gained.emit(amount, _total)

	var after := level()
	for crossed in range(before + 1, after + 1):
		levelled_up.emit(crossed)
	return amount


func total() -> int:
	return _total


func level() -> int:
	_ensure_table()
	return _table.level_for(_total)


## How far into the current level, 0 to 1. What the bar draws.
func progress() -> float:
	_ensure_table()
	return _table.progress(_total)


func remaining() -> int:
	_ensure_table()
	return _table.remaining(_total)


func is_capped() -> bool:
	_ensure_table()
	return _table.is_capped(_total)


func table() -> ExperienceTable:
	_ensure_table()
	return _table


## Sets the total outright, for a save file later or a console command now.
func set_total(value: int) -> void:
	_ensure_table()
	var before := level()
	_total = maxi(value, 0)
	gained.emit(0, _total)
	for crossed in range(before + 1, level() + 1):
		levelled_up.emit(crossed)


func _on_hit(_target: Node3D, damage: float) -> void:
	award(int(round(damage * _config_or_default().per_damage)))


func _on_killed(_target: Node3D) -> void:
	award(int(round(_config_or_default().per_kill)))


func _config_or_default() -> ExperienceConfig:
	if config == null:
		config = ExperienceConfig.new()
	return config


func _ensure_table() -> void:
	if _table == null:
		_table = ExperienceTable.new(_config_or_default())
