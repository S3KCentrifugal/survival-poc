extends TestCase
## The air: the ambient term, the fog, and the curve that decides how long the
## sky stays lit after the sun has gone.

const MAIN_SCENE: String = "res://scenes/main.tscn"

## The elevation the `world-dusk` shot actually renders at -- a little under the
## horizon, with the sky still orange. The number the whole afterglow curve
## exists to serve, so it is named rather than approximated.
const DUSK_ELEVATION: float = -0.059

## `world-night`, which is properly under.
const NIGHT_ELEVATION: float = -0.89

const NOON_ELEVATION: float = 0.60


func _air() -> Atmosphere:
	return Atmosphere.new(load("res://resources/sky/default_sky.tres"))


func test_it_works_without_a_config_at_all() -> void:
	# A lighting test builds one of these with nothing; it must not crash before
	# it can say anything.
	assert_true(Atmosphere.new(null).ambient_energy(NOON_ELEVATION) > 0.0)


# --- The skylight curve -------------------------------------------------------

func test_full_daylight_is_full_skylight() -> void:
	assert_eq(_air().skylight_amount(1.0), 1.0)
	assert_eq(_air().skylight_amount(ArtTokens.TWILIGHT_BAND), 1.0)


func test_the_middle_of_the_night_has_none() -> void:
	assert_eq(_air().skylight_amount(NIGHT_ELEVATION), 0.0)
	assert_eq(_air().skylight_amount(-1.0), 0.0)


## The whole point of the phase. The sun's own light stops the instant it
## crosses the horizon, and the previous code took the world with it -- 71% of
## the dusk frame below the readable floor while the sky above it was still
## orange. A lit sky is a lit dome, and the ground is lit by the dome.
func test_the_sky_is_still_lit_at_the_moment_of_sunset() -> void:
	assert_true(
		_air().skylight_amount(0.0) > 0.4,
		"sunset kept only %f of its skylight" % _air().skylight_amount(0.0)
	)


func test_dusk_keeps_enough_light_to_see_by() -> void:
	assert_true(
		_air().skylight_amount(DUSK_ELEVATION) > 0.25,
		"the dusk shot renders at %f skylight" % _air().skylight_amount(DUSK_ELEVATION)
	)


func test_it_never_goes_backwards_as_the_sun_rises() -> void:
	var air := _air()
	var previous := -1.0
	for step in 40:
		var elevation := -1.0 + step / 20.0
		var amount := air.skylight_amount(elevation)
		assert_true(amount >= previous, "skylight fell at elevation %f" % elevation)
		previous = amount


# --- Ambient ------------------------------------------------------------------

## The bug, as an assertion. Godot's sky ambient reads the rendered sky, and
## this project's night sky is very nearly black by design -- so an ambient
## taken entirely from it is an ambient of nothing, and every surface not facing
## the moon renders black.
func test_night_takes_its_ambient_from_the_moon_rather_than_the_black_sky() -> void:
	assert_eq(_air().sky_contribution(NIGHT_ELEVATION), 0.0)


func test_day_takes_its_ambient_from_the_sky_because_the_sky_is_right() -> void:
	assert_eq(_air().sky_contribution(NOON_ELEVATION), 1.0)


func test_there_is_ambient_light_at_night_at_all() -> void:
	assert_true(_air().ambient_energy(NIGHT_ELEVATION) > 0.0, "night has no ambient term")
	assert_eq(_air().ambient_energy(NIGHT_ELEVATION), ArtTokens.AMBIENT_NIGHT)


func test_night_is_never_brighter_than_day() -> void:
	assert_true(_air().ambient_energy(NIGHT_ELEVATION) < _air().ambient_energy(NOON_ELEVATION))


## `ART.md` rule 6: night is blue and quiet, never black, and never warm -- a
## warm night reads as a fire rather than as moonlight.
func test_the_night_ambient_is_blue() -> void:
	var colour := _air().ambient_color(NIGHT_ELEVATION)
	assert_true(colour.b > colour.r, "night ambient is warmer than it is cool")
	assert_true(colour.b > colour.g, "night ambient is not blue")


func test_the_day_ambient_is_the_colour_of_the_sky() -> void:
	# Never a colour the sky is not wearing -- the same argument
	# SkyGradient.ground_color makes.
	var sky := SkyGradient.new(load("res://resources/sky/default_sky.tres"))
	assert_eq(_air().ambient_color(NOON_ELEVATION), sky.horizon_color(NOON_ELEVATION))


# --- Fog ----------------------------------------------------------------------

func test_the_fog_is_made_of_the_sky() -> void:
	var sky := SkyGradient.new(load("res://resources/sky/default_sky.tres"))
	var horizon := sky.horizon_color(NOON_ELEVATION)
	var fog := _air().fog_color(NOON_ELEVATION)
	# Same family, not the same colour: pulled most of the way and desaturated.
	assert_true(fog.b > fog.r, "daytime fog is not drawn from a blue sky")
	assert_true(
		absf(UiTokens.luminance(fog) - UiTokens.luminance(horizon)) < 0.35,
		"the fog is nowhere near the sky it is supposed to be made of"
	)


## Fog exactly matching the horizon swallows the skyline of every distant hill,
## which is the silhouette the depth cue depends on.
func test_the_fog_is_darker_than_the_horizon_so_the_skyline_survives() -> void:
	var sky := SkyGradient.new(load("res://resources/sky/default_sky.tres"))
	assert_true(
		UiTokens.luminance(_air().fog_color(NOON_ELEVATION))
			< UiTokens.luminance(sky.horizon_color(NOON_ELEVATION)),
		"fog is as bright as the sky, so the horizon has no edge"
	)


## A fully saturated orange fog at sunset reads as a filter over the lens.
func test_the_fog_is_less_colourful_than_the_sky_it_scatters() -> void:
	var sky := SkyGradient.new(load("res://resources/sky/default_sky.tres"))
	assert_true(
		_air().fog_color(0.0).s < sky.horizon_color(0.0).s,
		"the sunset fog is as saturated as the sunset"
	)


## Desaturating through linear luminance and back would darken the fog as it
## drained it, so the fog would be doing two things when asked to do one.
func test_desaturating_does_not_also_darken() -> void:
	var vivid := Color(0.9, 0.35, 0.15)
	var drained := Atmosphere._desaturated(vivid, 1.0)
	assert_true(drained.s < 0.05, "it did not desaturate")
	assert_true(
		absf(UiTokens.luminance(drained) - UiTokens.luminance(vivid)) < 0.08,
		"desaturating moved the brightness from %f to %f"
			% [UiTokens.luminance(vivid), UiTokens.luminance(drained)]
	)


func test_the_air_is_thicker_at_sunset_than_at_noon() -> void:
	assert_true(
		_air().fog_density(0.0) > _air().fog_density(NOON_ELEVATION),
		"a low sun through thick air is not hazier than a high one"
	)


func test_there_is_always_some_air() -> void:
	# Zero density is no aerial perspective, which is the art direction switched
	# off rather than turned down.
	for step in 40:
		assert_true(_air().fog_density(-1.0 + step / 20.0) > 0.0)


# --- Exposure -----------------------------------------------------------------

func test_night_is_exposed_up() -> void:
	# Not papering over the ambient term: a night frame sits in the bottom
	# eighth of the range and a tonemapper handed that has no curve left.
	assert_true(_air().exposure(NIGHT_ELEVATION) > _air().exposure(NOON_ELEVATION))


# --- The component ------------------------------------------------------------

func test_the_world_carries_one_wired_to_the_clock_and_the_environment() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var air: AtmosphereComponent = world.get_node_or_null("Atmosphere")
	assert_not_null(air, "the world has no atmosphere")
	assert_eq(air.day_night, world.get_node("DayNight"), "it cannot see the sun")
	assert_eq(air.environment, world.get_node("WorldEnvironment"), "it has nothing to write to")


## The same resource the sky shader is drawn with. A second copy is how fog ends
## up a colour the sky is not wearing.
func test_it_reads_the_same_sky_the_shader_does() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var air: AtmosphereComponent = world.get_node("Atmosphere")
	var sky: SkyComponent = world.get_node("Sky")
	assert_eq(air.sky_config, sky.config)


## Written from [ArtTokens] rather than left in the .tscn, because a tonemapper
## chosen in a scene file is a number nobody will think to look for.
func test_it_sets_the_tonemapper_and_the_fog_from_the_tokens() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var air: AtmosphereComponent = world.get_node("Atmosphere")
	var settings := air.environment_settings()
	assert_eq(settings.tonemap_mode, ArtTokens.TONEMAP)
	assert_true(settings.fog_enabled, "there is no air")
	assert_eq(settings.fog_aerial_perspective, ArtTokens.FOG_AERIAL_PERSPECTIVE)


func test_moving_the_clock_to_night_moves_the_air_with_it() -> void:
	var world: Node = mount(load(MAIN_SCENE).instantiate())
	var clock: DayNightComponent = world.get_node("DayNight")
	var air: AtmosphereComponent = world.get_node("Atmosphere")

	clock.set_time_of_day(0.5)
	var by_day := air.environment_settings().ambient_light_sky_contribution
	clock.set_time_of_day(0.0)
	var at_night := air.environment_settings().ambient_light_sky_contribution

	assert_true(by_day > at_night, "the ambient source did not follow the sun")
	assert_eq(at_night, 0.0, "midnight still takes its ambient from a black sky")


## Two worlds must not share one Environment, or one test's midnight recolours
## another's noon -- the sub-resource trap that has caught this project four
## times.
func test_two_worlds_do_not_share_one_environment() -> void:
	var first: Node = mount(load(MAIN_SCENE).instantiate())
	var second: Node = mount(load(MAIN_SCENE).instantiate())
	(first.get_node("DayNight") as DayNightComponent).set_time_of_day(0.0)
	(second.get_node("DayNight") as DayNightComponent).set_time_of_day(0.5)

	var first_air: AtmosphereComponent = first.get_node("Atmosphere")
	var second_air: AtmosphereComponent = second.get_node("Atmosphere")
	var midnight := first_air.environment_settings()
	var noon := second_air.environment_settings()
	assert_ne(
		midnight.ambient_light_sky_contribution,
		noon.ambient_light_sky_contribution,
		"both worlds are writing the same environment"
	)


func test_the_moon_is_a_light_rather_than_the_absence_of_one() -> void:
	# 0.05 was not a dim night, it was no night: the world went black the moment
	# the sun crossed the horizon and stayed that way until dawn.
	var config: DayNightConfig = load("res://resources/day_night/default_day_night.tres")
	assert_true(config.night_energy >= 0.15, "the moon is %f" % config.night_energy)
	assert_true(config.night_color.b > config.night_color.r, "moonlight is not cool")
