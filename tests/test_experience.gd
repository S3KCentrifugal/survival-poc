extends TestCase
## Levels: the shape of the curve, what earns experience, and what the HUD says.
##
## The curve is three numbers producing thirty levels, so the properties that
## matter -- that it never goes backwards, that each level costs more than the
## last, that a capped character does not show an empty bar -- are assertions
## here rather than something noticed at level 12 by a player.

const CONFIG_PATH: String = "res://resources/progression/player_experience.tres"
const MAIN_SCENE: String = "res://scenes/main.tscn"


func _table() -> ExperienceTable:
	return ExperienceTable.new(load(CONFIG_PATH))


func test_the_config_resource_loads() -> void:
	var config: ExperienceConfig = load(CONFIG_PATH)
	assert_not_null(config, "%s is missing or malformed" % CONFIG_PATH)
	assert_true(config.max_level > 1, "there is only one level")
	assert_true(config.first_level_cost > 0)


func test_you_start_at_level_one_with_nothing() -> void:
	var table := _table()
	assert_eq(table.level_for(0), 1)
	assert_eq(table.total_for_level(1), 0, "level 1 costs something")
	assert_eq(table.progress(0), 0.0)


func test_the_first_level_costs_what_the_config_says() -> void:
	var config: ExperienceConfig = load(CONFIG_PATH)
	var table := ExperienceTable.new(config)
	assert_eq(table.cost_of_level(1), config.first_level_cost)
	assert_eq(table.level_for(config.first_level_cost - 1), 1, "it levelled one short")
	assert_eq(table.level_for(config.first_level_cost), 2, "it did not level on the exact cost")


## Never backwards. A curve that dips means a kill can cost you a level.
func test_the_curve_never_goes_backwards() -> void:
	var table := _table()
	var previous := -1
	for level in range(1, table.max_level() + 1):
		var total := table.total_for_level(level)
		assert_true(total > previous, "level %d costs less in total than level %d" % [level, level - 1])
		previous = total


## Each level should cost more than the last, or the curve is flat and level 30
## is as easy as level 2.
func test_each_level_costs_more_than_the_last() -> void:
	var table := _table()
	for level in range(1, table.max_level() - 1):
		assert_true(
			table.cost_of_level(level + 1) >= table.cost_of_level(level),
			"level %d costs less than level %d" % [level + 1, level]
		)


## A growth of exactly 1.0 would otherwise produce a plateau, and every level
## after it would be instant.
func test_a_flat_growth_still_rises() -> void:
	var config := ExperienceConfig.new()
	config.growth = 1.0
	config.first_level_cost = 10
	var table := ExperienceTable.new(config)
	for level in range(1, table.max_level() - 1):
		assert_true(table.cost_of_level(level) > 0, "level %d was free" % level)


func test_the_level_matches_the_total_all_the_way_up() -> void:
	var table := _table()
	for level in range(1, table.max_level() + 1):
		assert_eq(
			table.level_for(table.total_for_level(level)),
			level,
			"the exact total for level %d reads as a different level" % level
		)


func test_progress_runs_from_zero_to_one_within_a_level() -> void:
	var table := _table()
	var start := table.total_for_level(3)
	var cost := table.cost_of_level(3)

	assert_eq(table.progress(start), 0.0, "a fresh level starts part-full")
	assert_true(is_equal_approx(table.progress(start + cost / 2), 0.5))
	assert_eq(table.progress(start + cost), 0.0, "it did not roll over into the next level")


## A maxed character with an empty bar looks like one who just levelled and lost
## their progress.
func test_a_capped_character_shows_a_full_bar() -> void:
	var table := _table()
	var beyond := table.total_for_level(table.max_level()) + 100000
	assert_true(table.is_capped(beyond))
	assert_eq(table.level_for(beyond), table.max_level(), "it levelled past the cap")
	assert_eq(table.progress(beyond), 1.0, "a maxed character has an empty bar")
	assert_eq(table.remaining(beyond), 0)


func test_remaining_counts_down_to_the_next_level() -> void:
	var table := _table()
	var config: ExperienceConfig = load(CONFIG_PATH)
	assert_eq(table.remaining(0), config.first_level_cost)
	assert_eq(table.remaining(config.first_level_cost - 1), 1)


func _component() -> ExperienceComponent:
	var component := ExperienceComponent.new()
	component.config = load(CONFIG_PATH)
	mount(component)
	return component


func test_awarding_experience_raises_the_total() -> void:
	var component := _component()
	var seen: Array[int] = []
	component.gained.connect(func(amount: int, _total: int) -> void: seen.append(amount))

	component.award(25)
	assert_eq(component.total(), 25)
	assert_eq(seen, [25] as Array[int])


func test_a_negative_award_is_ignored() -> void:
	var component := _component()
	component.award(40)
	assert_eq(component.award(-100), 0, "experience went backwards")
	assert_eq(component.total(), 40)


func test_levelling_up_is_announced() -> void:
	var component := _component()
	var levels: Array[int] = []
	component.levelled_up.connect(func(level: int) -> void: levels.append(level))

	component.award(load(CONFIG_PATH).first_level_cost)
	assert_eq(levels, [2] as Array[int], "levelling up was not announced")
	assert_eq(component.level(), 2)


## One award crossing two levels should announce both, in order -- a UI that
## plays a fanfare should play two.
func test_crossing_two_levels_announces_both() -> void:
	var component := _component()
	var levels: Array[int] = []
	component.levelled_up.connect(func(level: int) -> void: levels.append(level))

	component.award(component.table().total_for_level(4))
	assert_eq(levels, [2, 3, 4] as Array[int], "it announced %s" % [levels])


func test_earning_without_levelling_announces_nothing() -> void:
	var component := _component()
	var levels: Array[int] = []
	component.levelled_up.connect(func(level: int) -> void: levels.append(level))
	component.award(1)
	assert_eq(levels.size(), 0, "a single point of experience levelled the character")


## Damage rather than kills alone, so a fight you lose is not worth nothing and
## the number moves while you are watching it.
func test_damage_earns_experience() -> void:
	var component := _component()
	var attack := AttackComponent.new()
	component.attack = attack
	mount(attack)
	component._ready()

	attack.hit.emit(null, 20.0)
	assert_eq(component.total(), int(round(20.0 * load(CONFIG_PATH).per_damage)))


func test_a_kill_earns_a_bonus_on_top() -> void:
	var component := _component()
	var attack := AttackComponent.new()
	component.attack = attack
	mount(attack)
	component._ready()

	attack.killed.emit(null)
	assert_eq(component.total(), int(round(load(CONFIG_PATH).per_kill)))


func test_the_player_is_assembled_to_earn_experience() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)

	var experience: ExperienceComponent = world.get_node_or_null("Player/Experience")
	assert_not_null(experience, "the player cannot earn experience")
	assert_eq(experience.attack, world.get_node("Player/Attack"), "fighting earns nothing")
	assert_not_null(experience.config, "it is running on code defaults")
	assert_eq(experience.level(), 1, "the player does not start at level 1")


func test_the_hud_shows_the_level_and_the_bar() -> void:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	var hud: PlayerHud = world.get_node("PlayerHud")
	var experience: ExperienceComponent = world.get_node("Player/Experience")

	assert_eq(hud.experience, experience, "the HUD cannot see the player's experience")
	assert_not_null(hud.experience_bar, "there is no experience bar")
	assert_true(hud.level_text().contains("Level 1"), "the HUD reads '%s'" % hud.level_text())
	assert_eq(hud.experience_fraction(), 0.0)

	experience.award(experience.table().cost_of_level(1) / 2)
	assert_true(hud.experience_fraction() > 0.4, "the bar did not follow the award")
	assert_true(hud.level_text().contains("Level 1"), "it levelled early")

	experience.award(experience.table().cost_of_level(1))
	assert_true(hud.level_text().contains("Level 2"), "the HUD reads '%s'" % hud.level_text())
