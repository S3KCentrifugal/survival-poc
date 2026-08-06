class_name ExperienceTable
extends RefCounted
## Turns a total amount of experience into a level and a bar.
##
## Pure arithmetic over a config: no nodes, no signals, no state of its own.
## Which is what lets the properties that actually matter -- that the curve
## never goes backwards, that level N always costs more than level N-1, that a
## capped character does not show an empty bar forever -- be assertions instead
## of something noticed at level 12 by a player.
##
## Levels are 1-based. Level 1 costs nothing; you start there.

var _config: ExperienceConfig

## Cumulative cost to *reach* each level, indexed by level. Built once, because
## the alternative is a loop over the whole curve on every HUD redraw.
var _thresholds: PackedInt64Array = PackedInt64Array()


func _init(config: ExperienceConfig = null) -> void:
	_config = config if config != null else ExperienceConfig.new()
	_build()


## The level a character with [param total] experience has reached.
func level_for(total: int) -> int:
	var level := 1
	for candidate in range(2, _thresholds.size()):
		if total >= _thresholds[candidate]:
			level = candidate
		else:
			break
	return level


## Total experience needed to reach [param level] from nothing.
func total_for_level(level: int) -> int:
	var clamped := clampi(level, 1, max_level())
	return _thresholds[clamped]


## Experience needed to go from [param level] to the next one. Zero at the cap.
func cost_of_level(level: int) -> int:
	if level >= max_level():
		return 0
	return total_for_level(level + 1) - total_for_level(level)


## How far into the current level [param total] is, from 0 to 1.
##
## Returns 1 at the cap rather than 0. A maxed character with an empty bar looks
## like a character who just levelled and lost their progress.
func progress(total: int) -> float:
	var level := level_for(total)
	if level >= max_level():
		return 1.0
	var into := total - total_for_level(level)
	var cost := cost_of_level(level)
	return 0.0 if cost <= 0 else clampf(float(into) / cost, 0.0, 1.0)


## Experience still to go before the next level. Zero at the cap.
func remaining(total: int) -> int:
	var level := level_for(total)
	if level >= max_level():
		return 0
	return maxi(total_for_level(level + 1) - total, 0)


func max_level() -> int:
	return _config.max_level


func is_capped(total: int) -> bool:
	return level_for(total) >= max_level()


func _build() -> void:
	_thresholds = PackedInt64Array()
	_thresholds.resize(_config.max_level + 1)
	_thresholds[0] = 0
	_thresholds[1] = 0

	var cost := float(_config.first_level_cost)
	for level in range(2, _config.max_level + 1):
		# Rounded and floored at one more than the last step, so a growth of
		# exactly 1.0 still produces a strictly rising curve rather than a
		# plateau that makes every level after it instant.
		_thresholds[level] = _thresholds[level - 1] + maxi(int(round(cost)), 1)
		cost *= _config.growth
