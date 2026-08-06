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

## What the level and the experience bar are drawn from.
@export var experience: ExperienceComponent

## What F would act on, so the HUD can say so. The **router**, not the
## collector: the router is what owns the key, and asking the collector means
## the prompt can never say "Trade with Merchant".
@export var router: InteractionRouter

@export var health_bar: ProgressBar
@export var stamina_bar: ProgressBar
@export var health_label: Label

@export var experience_bar: ProgressBar

## Reads "Level 4". Its own label rather than text inside the bar, because the
## number is the thing you glance at and the bar is the thing you watch.
@export var level_label: Label

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
	if router != null:
		router.target_changed.connect(_on_interact_target_changed)
	_refresh_prompt()
	if experience != null:
		experience.gained.connect(_on_experience_gained)
		experience.levelled_up.connect(_on_levelled_up)
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
	_refresh_experience()


## Fraction the health bar is showing, 0 to 1. For tests, and for anything that
## wants to know what the player can see rather than what is true.
func health_fraction() -> float:
	return _fraction_of(health_bar)


func stamina_fraction() -> float:
	return _fraction_of(stamina_bar)


func experience_fraction() -> float:
	return _fraction_of(experience_bar)


## What the level reads, for a test.
func level_text() -> String:
	return "" if level_label == null else level_label.text


## Redraws the level and the bar.
##
## The bar shows progress *through the current level*, not lifetime total. A bar
## that never resets tells you nothing about how close the next level is, which
## is the only question anyone asks of it.
func _refresh_experience() -> void:
	if experience == null:
		return
	if experience_bar != null:
		experience_bar.max_value = 1.0
		experience_bar.value = experience.progress()
	if level_label != null:
		level_label.text = (
			"Level %d  (max)" % experience.level()
			if experience.is_capped()
			else "Level %d      %d xp to next" % [experience.level(), experience.remaining()]
		)


func _on_experience_gained(_amount: int, _total: int) -> void:
	_refresh_experience()


func _on_levelled_up(_level: int) -> void:
	_refresh_experience()


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


## Shows what each key would do right now, or hides the prompt when there is
## nothing in reach.
##
## One line, because there is now one key. Two components each watching their
## own key is what this refactor removed; the router picks whichever thing is
## nearest and the prompt says what that one would do.
func _refresh_prompt() -> void:
	if prompt_label == null:
		return
	var lines: Array[String] = []
	var reachable := router.prompt_text() if router != null else ""
	if not reachable.is_empty():
		lines.append("[F]  %s" % reachable)
	prompt_label.visible = not lines.is_empty()
	prompt_label.text = "\n".join(lines)


func _on_interact_target_changed(_target: InteractableComponent) -> void:
	_refresh_prompt()



