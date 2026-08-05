class_name PlayerHud
extends CanvasLayer
## The player's health and stamina, on screen, all the time.
##
## Not the debug overlay. That is a readout for whoever is building the game and
## can say anything; this is for whoever is playing it and says two things. They
## are separate because they answer to different people, and because F3 should
## not take your health bar away with it.
##
## Driven by signals rather than polled every frame -- a bar only has to redraw
## when the number behind it moves.

@export var health: HealthComponent
@export var stamina: StaminaComponent

## What is in reach, so the HUD can say what F would do. Optional.
@export var collector: PickupCollector

@export var health_bar: ProgressBar
@export var stamina_bar: ProgressBar
@export var health_label: Label

## Says "Pick up Mushroom" when something is in reach. Hidden otherwise -- a
## prompt that is always on screen is a prompt nobody reads.
@export var prompt_label: Label

## Below this fraction the health bar turns urgent. A bar that looks the same at
## 90% and 9% is a bar you stop reading.
@export_range(0.0, 1.0, 0.05) var low_health_fraction: float = 0.3

@export var normal_health_colour: Color = Color(0.78, 0.22, 0.22)
@export var low_health_colour: Color = Color(0.95, 0.35, 0.15)
@export var stamina_colour: Color = Color(0.85, 0.72, 0.25)
@export var spent_stamina_colour: Color = Color(0.45, 0.42, 0.3)


func _ready() -> void:
	if health != null:
		health.changed.connect(_on_health_changed)
	if collector != null:
		collector.target_changed.connect(_on_target_changed)
		_on_target_changed(collector.target())
	if stamina != null:
		stamina.changed.connect(_on_stamina_changed)
		stamina.exhausted.connect(_refresh_stamina_colour)
		stamina.recovered.connect(_refresh_stamina_colour)
	refresh()


## Redraws both bars from the components. Call after anything the signals could
## not have seen -- a load, or a component swapped at runtime.
func refresh() -> void:
	if health != null:
		_on_health_changed(health.current(), health.maximum())
	if stamina != null:
		_on_stamina_changed(stamina.current(), stamina.maximum())
	_refresh_stamina_colour()


## Fraction the health bar is showing, 0 to 1. For tests, and for anything that
## wants to know what the player can see rather than what is true.
func health_fraction() -> float:
	return _fraction_of(health_bar)


func stamina_fraction() -> float:
	return _fraction_of(stamina_bar)


func _on_health_changed(current: float, maximum: float) -> void:
	_set_bar(health_bar, current, maximum)
	if health_label != null:
		health_label.text = "%d / %d" % [roundi(current), roundi(maximum)]
	if health_bar == null:
		return
	var low := maximum > 0.0 and current / maximum <= low_health_fraction
	_tint(health_bar, low_health_colour if low else normal_health_colour)


func _on_stamina_changed(current: float, maximum: float) -> void:
	_set_bar(stamina_bar, current, maximum)


## The bar says whether you may sprint, not just how much is left. An actor
## locked out with a quarter of a bar showing looks broken otherwise.
func _refresh_stamina_colour() -> void:
	if stamina_bar == null:
		return
	var spent := stamina != null and stamina.is_exhausted()
	_tint(stamina_bar, spent_stamina_colour if spent else stamina_colour)


func _set_bar(bar: ProgressBar, current: float, maximum: float) -> void:
	if bar == null:
		return
	bar.max_value = maxf(maximum, 0.0001)
	bar.value = clampf(current, 0.0, bar.max_value)


func _fraction_of(bar: ProgressBar) -> float:
	if bar == null or bar.max_value <= 0.0:
		return 0.0
	return bar.value / bar.max_value


## Recolours a bar's fill without touching the theme every other bar shares.
func _tint(bar: ProgressBar, colour: Color) -> void:
	var fill := bar.get_theme_stylebox(&"fill") as StyleBoxFlat
	if fill == null:
		return
	# Duplicated, or this edits the StyleBox both bars were handed -- the
	# resource cache trap from post 013, in its UI clothes.
	var own := fill.duplicate() as StyleBoxFlat
	own.bg_color = colour
	bar.add_theme_stylebox_override(&"fill", own)


## Shows what the interact key would do, or hides the prompt when nothing is in
## reach.
func _on_target_changed(pickup: PickupComponent) -> void:
	if prompt_label == null:
		return
	prompt_label.visible = pickup != null
	if pickup != null:
		prompt_label.text = "[F]  %s" % pickup.prompt_text()
