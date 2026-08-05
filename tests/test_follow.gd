extends TestCase
## Deciding whether to set off after someone, keep going, or stop.

const STEP: float = 1.0 / 60.0

var _config: FollowConfig


func before_each() -> void:
	_config = FollowConfig.new()
	_config.start_delay = 0.5
	_config.stop_distance = 2.0
	_config.resume_distance = 3.0
	_config.sprint_distance = 9.0


func _follow() -> Follow:
	return Follow.new(_config)


## Runs [param seconds] at a fixed distance and returns the state it lands in.
func _hold(follower: Follow, distance: float, seconds: float) -> Follow.State:
	var state := follower.state()
	for _frame in int(round(seconds / STEP)):
		state = follower.tick(distance, STEP)
	return state


func test_it_starts_settled() -> void:
	var follower := _follow()
	assert_eq(follower.state(), Follow.State.ARRIVED)
	assert_false(follower.is_moving())


func test_it_stays_put_while_you_are_close() -> void:
	var follower := _follow()
	assert_eq(_hold(follower, 1.0, 3.0), Follow.State.ARRIVED)
	assert_false(follower.is_moving())


## A companion that moves on the same frame you do is glued to you rather than
## following you.
func test_it_waits_before_setting_off() -> void:
	var follower := _follow()
	assert_eq(follower.tick(10.0, STEP), Follow.State.WAITING, "it set off instantly")
	assert_false(follower.is_moving())


func test_it_sets_off_once_the_delay_is_up() -> void:
	var follower := _follow()
	assert_eq(_hold(follower, 10.0, 0.6), Follow.State.FOLLOWING)
	assert_true(follower.is_moving())


func test_the_delay_is_about_as_long_as_configured() -> void:
	var follower := _follow()
	var ticks := 0
	while follower.tick(10.0, STEP) != Follow.State.FOLLOWING and ticks < 600:
		ticks += 1
	var waited := ticks * STEP
	assert_true(absf(waited - 0.5) < 0.1, "set off after %f seconds, expected about 0.5" % waited)


func test_it_counts_down_visibly() -> void:
	var follower := _follow()
	follower.tick(10.0, STEP)
	assert_true(follower.delay_left() > 0.0)
	_hold(follower, 10.0, 0.6)
	assert_eq(follower.delay_left(), 0.0)


func test_it_stops_when_it_catches_up() -> void:
	var follower := _follow()
	_hold(follower, 10.0, 0.6)
	assert_true(follower.is_moving())
	assert_eq(follower.tick(1.0, STEP), Follow.State.ARRIVED)


## With one threshold a companion hovering at exactly that range starts and
## stops every frame.
func test_it_does_not_twitch_at_the_boundary() -> void:
	var follower := _follow()
	_hold(follower, 10.0, 0.6)
	follower.tick(1.0, STEP)  # arrived

	var changes := 0
	var previous := follower.state()
	for frame in 200:
		# Straddles the stop distance by a hair.
		var distance := 2.0 + (0.05 if frame % 2 == 0 else -0.05)
		var state := follower.tick(distance, STEP)
		if state != previous:
			changes += 1
			previous = state
	assert_eq(changes, 0, "state changed %d times hovering at the stop distance" % changes)


func test_a_real_gap_starts_it_again() -> void:
	var follower := _follow()
	_hold(follower, 10.0, 0.6)
	follower.tick(1.0, STEP)
	assert_eq(_hold(follower, 6.0, 0.6), Follow.State.FOLLOWING, "it never set off again")


func test_walking_away_during_the_wait_is_not_forgotten() -> void:
	var follower := _follow()
	follower.tick(5.0, STEP)
	assert_eq(_hold(follower, 20.0, 0.6), Follow.State.FOLLOWING)


func test_coming_back_during_the_wait_cancels_it() -> void:
	var follower := _follow()
	follower.tick(5.0, STEP)
	assert_eq(follower.tick(1.0, STEP), Follow.State.ARRIVED, "it set off after you came back")


func test_it_sprints_when_it_falls_a_long_way_behind() -> void:
	var follower := _follow()
	_hold(follower, 20.0, 0.6)
	assert_true(follower.should_sprint(20.0))
	assert_false(follower.should_sprint(4.0), "sprinting to cross four metres")


func test_it_does_not_sprint_while_standing_still() -> void:
	var follower := _follow()
	assert_false(follower.should_sprint(50.0), "sprinting while it has not set off")


func test_an_inverted_distance_pair_is_straightened_out() -> void:
	_config.stop_distance = 6.0
	_config.resume_distance = 2.0
	var limits := _config.distances()
	assert_true(limits.x <= limits.y)


func test_settling_drops_it_back_to_standing() -> void:
	var follower := _follow()
	_hold(follower, 10.0, 0.6)
	follower.settle()
	assert_eq(follower.state(), Follow.State.ARRIVED)
	assert_false(follower.is_moving())
