class_name HurtReaction
extends Node
## What being hit looks like from the inside.
##
## Listens to a [HealthComponent] and holds a short "just took a hit" window.
## Animation shows a flinch while it lasts and whatever is driving the actor
## stops driving it, which is the whole of the reaction.
##
## Kept out of [HealthComponent] deliberately: health owns a number and the
## rules about that number, and how long a character reels is presentation.

## Emitted when the flinch starts, including when one hit interrupts another.
signal flinched

## Emitted when the actor is back in control.
signal recovered

@export var health: HealthComponent

## How long the actor reels, in seconds. Long enough to read, short enough that
## being hit twice is not being removed from the game.
@export_range(0.0, 5.0, 0.05) var stagger_seconds: float = 0.5

var _stagger: Cooldown


func _ready() -> void:
	_ensure_stagger()
	if health != null:
		health.damaged.connect(_on_damaged)


func _physics_process(delta: float) -> void:
	step(delta)


## Advances the flinch. Public so tests can run it without the physics clock.
func step(delta: float) -> void:
	_ensure_stagger()
	if _stagger.is_ready():
		return
	_stagger.advance(delta)
	if _stagger.is_ready():
		recovered.emit()


## Whether the actor is currently reeling.
func is_reacting() -> bool:
	_ensure_stagger()
	return not _stagger.is_ready()


## Whether there is anybody home. Nothing reacts once it is dead, and whatever
## drives the actor should stop driving it.
func is_alive() -> bool:
	return health == null or health.is_alive()


## Starts a flinch now, whatever caused it.
##
## The cooldown is cleared first on purpose: a second hit should restart the
## reel rather than be swallowed by the first one, which is the difference
## between a punch that lands and a punch that does nothing.
func flinch() -> void:
	_ensure_stagger()
	_stagger.clear()
	_stagger.use()
	flinched.emit()


func _on_damaged(_amount: float) -> void:
	flinch()


func _ensure_stagger() -> void:
	if _stagger == null:
		_stagger = Cooldown.new(stagger_seconds)
