class_name SnapshotInterpolator
extends RefCounted
## Turns 20 snapshots a second into smooth motion.
##
## A client that snapped every remote character to the last position it heard
## about would show them stepping twenty times a second. So it holds a short
## buffer and renders the world **slightly in the past**, interpolating between
## the two snapshots either side of that moment. The cost is a fixed delay; the
## benefit is that ordinary jitter and the occasional lost packet never show.
##
## The delay has to be at least one snapshot interval or there is nothing on the
## far side to interpolate toward, and the buffer runs dry every frame. Two
## intervals is the usual choice and what the default is.
##
## Node-free and clock-free -- it is handed times rather than reading one, so
## "what happens when a packet arrives late" is an assertion rather than
## something you see as a twitch.

## How far behind the newest snapshot to render, in seconds.
var delay: float

## Snapshots older than this behind the newest are dropped.
var history: float = 1.0

## Times and states, oldest first.
var _times: PackedFloat64Array = []
var _positions: PackedVector3Array = []
var _yaws: PackedFloat32Array = []


func _init(p_delay: float = 0.1) -> void:
	delay = maxf(p_delay, 0.0)


## Records where something was at [param at_time].
##
## Snapshots older than the newest already held are dropped: over an unreliable
## channel packets overtake each other, and an out-of-order one would otherwise
## drag the character backwards.
func add(at_time: float, position: Vector3, yaw: float) -> void:
	if not _times.is_empty() and at_time <= _times[_times.size() - 1]:
		return
	_times.append(at_time)
	_positions.append(position)
	_yaws.append(yaw)
	_forget_older_than(at_time - history)


## Where the thing should be drawn at [param now].
##
## Returns the last known state when there is nothing to interpolate between --
## a character that stops still is better than one that vanishes.
func sample(now: float) -> Dictionary:
	if _times.is_empty():
		return {}

	var wanted := now - delay
	var newest := _times.size() - 1

	# Not enough history yet, or the wanted moment is still in the future.
	if wanted <= _times[0]:
		return _state_at(0)
	# Nothing has arrived for a while: hold the last known state rather than
	# guessing. Extrapolation looks worse than a pause when it is wrong.
	if wanted >= _times[newest]:
		return _state_at(newest)

	var after := 1
	while after < newest and _times[after] < wanted:
		after += 1
	var before := after - 1

	var span := _times[after] - _times[before]
	var through := 0.0 if span <= 0.0 else float((wanted - _times[before]) / span)
	return {
		"position": _positions[before].lerp(_positions[after], through),
		# Through the short way round, or a character crossing north spins.
		"yaw": _yaws[before] + angle_difference(_yaws[before], _yaws[after]) * through,
	}


## How many snapshots are held.
func size() -> int:
	return _times.size()


func is_empty() -> bool:
	return _times.is_empty()


## Time of the newest snapshot, or -1 with nothing held.
func newest_time() -> float:
	return -1.0 if _times.is_empty() else _times[_times.size() - 1]


func clear() -> void:
	_times = PackedFloat64Array()
	_positions = PackedVector3Array()
	_yaws = PackedFloat32Array()


func _state_at(index: int) -> Dictionary:
	return {"position": _positions[index], "yaw": _yaws[index]}


## Drops what is too old to be interpolated through again.
##
## Always keeps two, so a connection that goes quiet still has something to
## interpolate between when it comes back.
func _forget_older_than(cutoff: float) -> void:
	var drop := 0
	while drop < _times.size() - 2 and _times[drop] < cutoff:
		drop += 1
	if drop <= 0:
		return
	_times = _times.slice(drop)
	_positions = _positions.slice(drop)
	_yaws = _yaws.slice(drop)
