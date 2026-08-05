class_name MushroomPatch
extends Node3D
## Scatters mushrooms over the ground, and grows them back once they are picked.
##
## Deliberately the same shape as [WandererSpawner] -- scatter, keep clear of
## the buildings, top back up after a delay -- because a reader who has
## understood one has understood both. The differences are that a mushroom is
## removed by being *collected* rather than by dying, and that new ones sprout
## rather than appearing at full size.

## Emitted for each mushroom as it sprouts.
signal grown(mushroom: Node3D)

@export var scene: PackedScene

## Dropped onto the surface, so they sit on the ground rather than in the air
## over a hill or buried inside one.
@export var terrain: Terrain

@export_range(0, 200, 1) var count: int = 14

## Where they are scattered, in tile-local metres.
@export var area: Rect2 = Rect2(-22.0, -22.0, 44.0, 44.0)

## Kept clear, so none grow inside the building the player wakes up in.
@export var avoid: Rect2 = Rect2(-9.0, -7.0, 18.0, 14.0)

## Fixed rather than random, so a world looks the same twice. That is the
## difference between a bug you can chase and one you cannot.
@export var seed_value: int = 20260805

@export_group("Regrowth")
## Whether picked mushrooms come back. Off makes the patch finite, which is a
## legitimate design and not this one.
@export var regrow: bool = true

## Seconds between one being picked and the next sprouting.
@export_range(0.0, 600.0, 0.5) var regrow_seconds: float = 20.0

## Metres above the ground each one is dropped from. Small: they are 0.2 m tall
## and a drop reads as a hover.
const DROP_HEIGHT: float = 0.02

var _grown: Array[Node3D] = []

## Counts down between replacements. Fifth caller of this class now.
var _delay: Cooldown

## Kept going between sprouts so replacements do not repeat the first
## arrangement.
var _rng: RandomNumberGenerator

## Whether a wait is already running for the current gap.
##
## Without it the delay only ever applied *between* replacements, so the first
## one picked was replaced instantly -- a fresh cooldown is ready, not waiting.
## The same bug as the wanderer respawner's, avoided by copying the fix rather
## than by rediscovering it.
var _waiting: bool = false


func _ready() -> void:
	# The world's contents are the server's to decide. A client that invented
	# its own patch would show mushrooms nobody else can pick.
	if not NetworkAuthority.is_server(self):
		return
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_delay = Cooldown.new(regrow_seconds)
	fill()


func _process(delta: float) -> void:
	if not regrow or _delay == null:
		return
	_prune()
	if _grown.size() >= count:
		_waiting = false
		return

	if not _waiting:
		_waiting = true
		_delay.remaining = _delay.duration
		return

	_delay.advance(delta)
	if _delay.is_ready():
		_waiting = false
		_sprout(true)


## Grows the patch up to [member count], full size.
##
## The world should look established on the first frame, not like a field of
## seedlings that somebody planted as you arrived.
func fill() -> void:
	_prune()
	while _grown.size() < count:
		if _sprout(false) == null:
			return


## How many are standing.
func standing() -> int:
	_prune()
	return _grown.size()


## The mushrooms themselves, for a test.
func mushrooms() -> Array[Node3D]:
	_prune()
	return _grown.duplicate()


## Puts one down. [param sprouting] decides whether it grows in or is already
## there.
func _sprout(sprouting: bool) -> Node3D:
	if scene == null or _rng == null:
		return null
	var mushroom: Node3D = scene.instantiate()
	add_child(mushroom)
	mushroom.global_position = _somewhere()

	# A little turn each, so a patch does not read as a row of identical props.
	mushroom.rotation.y = _rng.randf() * TAU
	var scale := _rng.randfn(1.0, 0.18)
	mushroom.scale = Vector3.ONE * clampf(scale, 0.65, 1.4)

	var growth := mushroom as MushroomGrowth
	if growth != null and not sprouting:
		growth.finish()

	_grown.append(mushroom)
	grown.emit(mushroom)
	return mushroom


## Somewhere in [member area] that is not inside [member avoid], on the ground.
func _somewhere() -> Vector3:
	var where := Vector2.ZERO
	# Bounded rather than "until it works": a badly configured avoid rectangle
	# covering the whole area would otherwise hang the game on load.
	for _attempt in 24:
		where = Vector2(
			_rng.randf_range(area.position.x, area.end.x),
			_rng.randf_range(area.position.y, area.end.y)
		)
		if not avoid.has_point(where):
			break

	var position := Vector3(where.x, DROP_HEIGHT, where.y)
	if terrain != null:
		position.y = terrain.height_at_world(position) + DROP_HEIGHT
	return position


## Drops the ones that have been picked.
func _prune() -> void:
	var standing_now: Array[Node3D] = []
	for mushroom: Node3D in _grown:
		if is_instance_valid(mushroom) and not mushroom.is_queued_for_deletion():
			standing_now.append(mushroom)
	_grown = standing_now
