extends TestCase
## The wire format. Every assertion here is a promise to a future Rust server.


func test_a_hello_round_trips() -> void:
	var decoded := NetworkProtocol.decode_hello(NetworkProtocol.encode_hello())
	assert_eq(decoded.get("version"), NetworkProtocol.VERSION)


func test_a_welcome_round_trips() -> void:
	var decoded := NetworkProtocol.decode_welcome(NetworkProtocol.encode_welcome(7, 1234))
	assert_eq(decoded.get("peer_id"), 7)
	assert_eq(decoded.get("tick"), 1234)
	assert_eq(decoded.get("version"), NetworkProtocol.VERSION)


func test_an_input_round_trips() -> void:
	var bytes := NetworkProtocol.encode_input(
		99, Vector2(1.0, -1.0), PI, NetworkProtocol.BUTTON_SPRINT | NetworkProtocol.BUTTON_JUMP
	)
	var decoded := NetworkProtocol.decode_input(bytes)
	assert_eq(decoded.get("tick"), 99)
	assert_true(is_equal_approx(decoded["move"].x, 1.0))
	assert_true(is_equal_approx(decoded["move"].y, -1.0))
	assert_true(absf(decoded["yaw"] - PI) < 0.001, "yaw came back as %f" % decoded["yaw"])
	assert_eq(decoded.get("buttons"), NetworkProtocol.BUTTON_SPRINT | NetworkProtocol.BUTTON_JUMP)


## A reader that knows the kind knows the exact length. These are the numbers a
## Rust implementation would hard-code.
func test_the_documented_sizes_are_the_real_sizes() -> void:
	assert_eq(NetworkProtocol.encode_hello().size(), 3)
	assert_eq(NetworkProtocol.encode_welcome(1, 1).size(), 11)
	assert_eq(NetworkProtocol.encode_input(1, Vector2.ZERO, 0.0, 0).size(), 10)
	assert_eq(NetworkProtocol.encode_despawn(1).size(), 5)

	var one: Array[Dictionary] = [{"id": 1}]
	assert_eq(
		NetworkProtocol.encode_snapshot(1, one).size(),
		NetworkProtocol.SNAPSHOT_HEADER_SIZE + NetworkProtocol.ENTITY_SIZE
	)


func test_a_snapshot_round_trips() -> void:
	var entities: Array[Dictionary] = [
		{
			"id": 1,
			"position": Vector3(12.5, 3.25, -40.75),
			"yaw": 1.0,
			"flags": NetworkProtocol.FLAG_ON_FLOOR | NetworkProtocol.FLAG_SPRINTING,
			"health": 0.5,
			"kind": NetworkProtocol.EntityKind.PLAYER,
		},
		{"id": 2, "position": Vector3(-1.0, 0.0, 2.0), "yaw": 0.0, "flags": 0, "health": 1.0},
	]
	var decoded := NetworkProtocol.decode_snapshot(NetworkProtocol.encode_snapshot(77, entities))
	assert_eq(decoded.get("tick"), 77)

	var back: Array = decoded["entities"]
	assert_eq(back.size(), 2)
	assert_eq(back[0]["id"], 1)
	assert_true(back[0]["position"].is_equal_approx(Vector3(12.5, 3.25, -40.75)))
	assert_eq(back[0]["flags"], NetworkProtocol.FLAG_ON_FLOOR | NetworkProtocol.FLAG_SPRINTING)
	assert_eq(back[0]["kind"], NetworkProtocol.EntityKind.PLAYER, "the client would not know what to spawn")
	assert_true(absf(back[0]["health"] - 0.5) < 0.005)
	assert_eq(back[1]["id"], 2)


func test_an_empty_snapshot_is_valid() -> void:
	var none: Array[Dictionary] = []
	var decoded := NetworkProtocol.decode_snapshot(NetworkProtocol.encode_snapshot(5, none))
	assert_eq(decoded.get("tick"), 5)
	assert_eq((decoded["entities"] as Array).size(), 0)


func test_a_despawn_round_trips() -> void:
	assert_eq(NetworkProtocol.decode_despawn(NetworkProtocol.encode_despawn(4242)).get("id"), 4242)


## Positions stay full float32 because a centimetre of error reads as jitter.
func test_positions_keep_their_precision() -> void:
	var entities: Array[Dictionary] = [{"id": 1, "position": Vector3(1234.5, -0.125, 0.0625)}]
	var back: Array = NetworkProtocol.decode_snapshot(
		NetworkProtocol.encode_snapshot(1, entities)
	)["entities"]
	assert_true(
		back[0]["position"].distance_to(Vector3(1234.5, -0.125, 0.0625)) < 0.001,
		"position came back as %v" % back[0]["position"]
	)


func test_quantised_movement_stays_within_its_stated_error() -> void:
	for step in 41:
		var wanted := -1.0 + step * 0.05
		var back := NetworkProtocol.unquantise_axis(NetworkProtocol.quantise_axis(wanted))
		assert_true(absf(back - wanted) <= 0.004, "%f came back as %f" % [wanted, back])


func test_quantised_angles_stay_within_their_stated_error() -> void:
	for step in 64:
		var wanted := step / 64.0 * TAU
		var back := NetworkProtocol.unquantise_angle(NetworkProtocol.quantise_angle(wanted))
		assert_true(
			absf(angle_difference(back, wanted)) <= 0.0002, "%f came back as %f" % [wanted, back]
		)


func test_angles_outside_a_turn_wrap_rather_than_overflow() -> void:
	for wanted: float in [-PI, -0.1, TAU + 1.0, 100.0]:
		var value := NetworkProtocol.quantise_angle(wanted)
		assert_true(value >= 0 and value <= 0xFFFF, "%f quantised to %d" % [wanted, value])
		var back := NetworkProtocol.unquantise_angle(value)
		assert_true(absf(angle_difference(back, wanted)) <= 0.0002)


func test_quantised_health_stays_within_its_stated_error() -> void:
	for step in 21:
		var wanted := step * 0.05
		var back := NetworkProtocol.unquantise_fraction(NetworkProtocol.quantise_fraction(wanted))
		assert_true(absf(back - wanted) <= 0.002)


func test_out_of_range_values_are_clamped_rather_than_wrapped() -> void:
	# A wrapped value is a character sprinting backwards; a clamped one is a
	# character at full tilt.
	assert_eq(NetworkProtocol.quantise_axis(50.0), 127)
	assert_eq(NetworkProtocol.quantise_axis(-50.0), -127)
	assert_eq(NetworkProtocol.quantise_fraction(9.0), 255)
	assert_eq(NetworkProtocol.quantise_fraction(-9.0), 0)


## A malformed packet is a thing a server receives from strangers, so every
## decoder has to reject rather than read out of bounds.
func test_rubbish_is_rejected_rather_than_read() -> void:
	var rubbish := PackedByteArray([9, 9, 9, 9, 9, 9, 9, 9])
	assert_true(NetworkProtocol.decode_input(rubbish).is_empty())
	assert_true(NetworkProtocol.decode_snapshot(rubbish).is_empty())
	assert_true(NetworkProtocol.decode_welcome(rubbish).is_empty())
	assert_true(NetworkProtocol.decode_despawn(rubbish).is_empty())
	assert_true(NetworkProtocol.decode_hello(rubbish).is_empty())


func test_an_empty_packet_is_rejected() -> void:
	var nothing := PackedByteArray()
	assert_eq(NetworkProtocol.kind_of(nothing), NetworkProtocol.Kind.NONE)
	assert_true(NetworkProtocol.decode_input(nothing).is_empty())


## A count is a stranger's number until the length agrees with it.
func test_a_lying_entity_count_is_rejected() -> void:
	var bytes := NetworkProtocol.encode_snapshot(1, [{"id": 1}] as Array[Dictionary])
	bytes.encode_u16(5, 9999)
	assert_true(
		NetworkProtocol.decode_snapshot(bytes).is_empty(),
		"a snapshot claiming 9999 entities in 27 bytes was accepted"
	)


func test_a_truncated_message_is_rejected() -> void:
	var bytes := NetworkProtocol.encode_input(1, Vector2.ONE, 1.0, 0)
	assert_true(NetworkProtocol.decode_input(bytes.slice(0, 6)).is_empty())


func test_the_kind_byte_identifies_the_message() -> void:
	assert_eq(NetworkProtocol.kind_of(NetworkProtocol.encode_hello()), NetworkProtocol.Kind.HELLO)
	assert_eq(
		NetworkProtocol.kind_of(NetworkProtocol.encode_input(1, Vector2.ZERO, 0.0, 0)),
		NetworkProtocol.Kind.INPUT
	)
	assert_eq(
		NetworkProtocol.kind_of(PackedByteArray([200])),
		NetworkProtocol.Kind.NONE,
		"an unknown kind must not be mistaken for a known one"
	)


## The whole point of the abstraction: intent off the wire is intent.
func test_intent_survives_the_round_trip_as_an_input_state() -> void:
	var sent := InputState.new()
	sent.move = Vector2(0.5, -0.5)
	sent.sprint = true
	sent.attack = true

	var bytes := NetworkProtocol.encode_input(
		1, sent.move, 0.0, NetworkProtocol.buttons_of(sent)
	)
	var got := NetworkProtocol.input_state_from(NetworkProtocol.decode_input(bytes))

	assert_true(got.move.distance_to(sent.move) < 0.01)
	assert_true(got.sprint)
	assert_true(got.attack)
	assert_false(got.jump)


func test_a_rejected_packet_yields_a_harmless_input_state() -> void:
	var got := NetworkProtocol.input_state_from({})
	assert_eq(got.move, Vector2.ZERO)
	assert_false(got.sprint or got.jump or got.attack)


## The budget that decides whether interest management is optional. It is not.
func test_the_snapshot_budget_is_what_the_design_assumes() -> void:
	var entities: Array[Dictionary] = []
	for index in 50:
		entities.append({"id": index, "position": Vector3.ZERO})
	var size := NetworkProtocol.encode_snapshot(1, entities).size()
	var per_second := size * 20
	assert_true(
		per_second < 25_000,
		"50 entities at 20 Hz is %d bytes/s to each client, over the 20 kB budget" % per_second
	)
