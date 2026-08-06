extends TestCase
## The chat: what a line may contain, what goes on the wire, and that typing
## into it does not walk you across the map.

const MAIN_SCENE: String = "res://scenes/main.tscn"


func test_a_line_goes_in_and_comes_back_out() -> void:
	var chat := ChatLog.new()
	assert_true(chat.is_empty())

	var entry := chat.add("Rob", "hello")
	assert_not_null(entry)
	assert_eq(entry.line(), "Rob: hello")
	assert_eq(chat.size(), 1)


## A system line carries no author, so nothing the game says can be made to
## look like something a player said.
func test_a_system_line_has_no_author() -> void:
	var chat := ChatLog.new()
	var entry := chat.add_system("Player 2 joined.")
	assert_eq(entry.kind, ChatLog.Kind.SYSTEM)
	assert_eq(entry.line(), "Player 2 joined.", "a system line was attributed to someone")


func test_empty_and_whitespace_messages_are_not_lines() -> void:
	var chat := ChatLog.new()
	assert_null(chat.add("Rob", ""))
	assert_null(chat.add("Rob", "     "))
	assert_null(chat.add("Rob", "\n\n"))
	assert_true(chat.is_empty(), "an empty message became a line")


## A message that can contain a newline can draw a fake second line, and one
## that can contain a lot of them can push the whole log off the screen.
func test_newlines_become_spaces_rather_than_lines() -> void:
	var clean := ChatLog.sanitise("first\nsecond\r\nthird")
	assert_false(clean.contains("\n"), "a newline survived: %s" % clean)
	assert_false(clean.contains("\r"), "a carriage return survived")
	assert_true(clean.contains("first"), "the message was destroyed rather than cleaned")
	assert_true(clean.contains("third"))


## No null byte in the hostile string, because `String.chr(0)` does not produce
## one -- Godot hands back U+FFFD, the replacement character, which is printable
## and correctly survives. The control characters that can actually exist in a
## String are the ones worth testing.
func test_control_characters_are_removed() -> void:
	var hostile := "safe" + String.chr(27) + String.chr(127) + String.chr(7) + "text"
	var clean := ChatLog.sanitise(hostile)
	assert_eq(clean, "safetext", "a control character survived: %s" % clean.to_utf8_buffer())


## Enforced in the log, not on the text box: the box is not the only way a
## message arrives, and the other way is a stranger's peer.
func test_a_very_long_message_is_cut_to_the_limit() -> void:
	var chat := ChatLog.new()
	var entry := chat.add("Rob", "a".repeat(5000))
	assert_eq(entry.text.length(), ChatLog.MAX_LENGTH, "a 5000-character message went in whole")


func test_a_very_long_name_is_cut_too() -> void:
	var entry := ChatLog.new().add("n".repeat(500), "hello")
	assert_eq(entry.author.length(), ChatLog.MAX_AUTHOR_LENGTH)


## The log is bounded, or a long session is a memory leak with a scrollbar.
func test_old_lines_fall_off_the_top() -> void:
	var chat := ChatLog.new(5)
	for index in 12:
		chat.add("Rob", "message %d" % index)

	assert_eq(chat.size(), 5, "the log kept %d lines with a capacity of 5" % chat.size())
	assert_true(chat.text().contains("message 11"), "the newest line was dropped")
	assert_false(chat.text().contains("message 0"), "the oldest line was kept")


func test_the_log_reads_oldest_first() -> void:
	var chat := ChatLog.new()
	chat.add("Rob", "one")
	chat.add("Rob", "two")
	assert_true(chat.text().find("one") < chat.text().find("two"), "the log reads backwards")


func test_a_chat_message_survives_the_wire() -> void:
	var bytes := NetworkProtocol.encode_chat(7, "hello there")
	assert_eq(NetworkProtocol.kind_of(bytes), NetworkProtocol.Kind.CHAT)

	var decoded := NetworkProtocol.decode_chat(bytes)
	assert_eq(decoded.get("sender"), 7)
	assert_eq(decoded.get("text"), "hello there")


func test_unicode_survives_the_wire() -> void:
	for text: String in ["héllo", "日本語のテキスト", "emoji 🍄 soup"]:
		var decoded := NetworkProtocol.decode_chat(NetworkProtocol.encode_chat(1, text))
		assert_eq(decoded.get("text"), text, "'%s' did not survive" % text)


## Truncation has to land on a character boundary. Cutting UTF-8 mid-sequence
## produces bytes Godot cannot decode, and the far end sees an empty message
## rather than a shortened one.
func test_a_long_unicode_message_truncates_without_breaking() -> void:
	var decoded := NetworkProtocol.decode_chat(NetworkProtocol.encode_chat(1, "🍄".repeat(200)))
	var text: String = decoded.get("text", "")
	assert_false(text.is_empty(), "truncation broke the encoding and lost the whole message")
	assert_true(text.begins_with("🍄"), "the message came back as rubbish")


## The one message whose length a stranger chooses is the one place a lie about
## length would be read past the end of a buffer.
func test_a_lying_length_byte_is_refused() -> void:
	var bytes := NetworkProtocol.encode_chat(1, "hello")
	bytes.encode_u8(5, 200)
	assert_true(
		NetworkProtocol.decode_chat(bytes).is_empty(),
		"a packet claiming 200 bytes of payload it does not have was accepted"
	)


func test_a_truncated_packet_is_refused() -> void:
	var bytes := NetworkProtocol.encode_chat(1, "hello there")
	assert_true(NetworkProtocol.decode_chat(bytes.slice(0, 8)).is_empty())
	assert_true(NetworkProtocol.decode_chat(PackedByteArray()).is_empty())


## The kind byte is checked by membership, not by a range ending at whichever
## kind was last when the check was written. That version silently dropped every
## CHAT packet the moment the kind was added.
func test_every_kind_is_recognised() -> void:
	for kind: int in NetworkProtocol.Kind.values():
		if kind == NetworkProtocol.Kind.NONE:
			continue
		var bytes := PackedByteArray()
		bytes.resize(1)
		bytes.encode_u8(0, kind)
		assert_eq(NetworkProtocol.kind_of(bytes), kind, "kind %d is not recognised" % kind)


func test_an_unknown_kind_is_ignored_rather_than_guessed() -> void:
	var bytes := PackedByteArray()
	bytes.resize(1)
	bytes.encode_u8(0, 99)
	assert_eq(NetworkProtocol.kind_of(bytes), NetworkProtocol.Kind.NONE)


func test_another_message_is_not_read_as_chat() -> void:
	assert_true(NetworkProtocol.decode_chat(NetworkProtocol.encode_despawn(4)).is_empty())


## Adding a kind must not break peers that predate it.
func test_the_protocol_version_did_not_move() -> void:
	assert_eq(NetworkProtocol.VERSION, 2, "adding a message kind moved the version")


func _service() -> ChatService:
	var service := ChatService.new()
	service.player_name = "You"
	mount(service)
	return service


## Single-player is the same path with the send skipped, not a special case.
func test_saying_something_with_no_socket_still_says_it() -> void:
	var service := _service()
	var seen: Array[String] = []
	service.line_added.connect(func(e: ChatLog.Entry) -> void: seen.append(e.line()))

	assert_true(service.say("hello"))
	assert_eq(seen, ["You: hello"] as Array[String])
	assert_eq(service.chat_log().size(), 1)


func test_saying_nothing_says_nothing() -> void:
	var service := _service()
	assert_false(service.say("   "), "whitespace was accepted as a message")
	assert_true(service.chat_log().is_empty())


func test_announcements_are_system_lines() -> void:
	var service := _service()
	service.announce("Disconnected.")
	assert_eq(service.chat_log().entries()[0].kind, ChatLog.Kind.SYSTEM)


func _world() -> Node:
	var world: Node = load(MAIN_SCENE).instantiate()
	mount(world)
	return world


func test_the_world_carries_a_chat_box_wired_to_a_service() -> void:
	var world := _world()
	var box: ChatBox = world.get_node_or_null("ChatBox")
	assert_not_null(box, "there is no chat box")
	assert_eq(box.service, world.get_node("Chat"), "the box has no service")
	assert_eq(box.world_root, world, "it cannot stop the player walking while you type")
	assert_not_null(box.entry, "there is nothing to type into")
	assert_not_null(box.log_label, "there is nothing to read")


func test_it_starts_hidden() -> void:
	assert_false((_world().get_node("ChatBox") as ChatBox).is_open())


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func test_f12_shows_and_hides_it() -> void:
	var box: ChatBox = _world().get_node("ChatBox")
	box._unhandled_input(_key(KEY_F12))
	assert_true(box.is_open(), "F12 did not show the chat")
	box._unhandled_input(_key(KEY_F12))
	assert_false(box.is_open(), "F12 did not hide the chat")


func test_another_key_does_not_toggle_it() -> void:
	var box: ChatBox = _world().get_node("ChatBox")
	box._unhandled_input(_key(KEY_K))
	assert_false(box.is_open())


func test_typing_and_sending_puts_a_line_in_the_log() -> void:
	var world := _world()
	var box: ChatBox = world.get_node("ChatBox")
	box.set_open(true)
	box.entry.text = "anyone out there"

	assert_true(box.submit(), "nothing was sent")
	assert_eq(box.entry.text, "", "the entry kept what was sent")
	assert_true(
		box.log_label.text.contains("anyone out there"),
		"the log reads '%s'" % box.log_label.text
	)


## Without this, typing "we should go west" walks you west, jumps, and throws
## four punches.
func test_the_player_does_not_move_while_typing() -> void:
	var world := _world()
	var box: ChatBox = world.get_node("ChatBox")
	box.set_open(true)
	box.focus_entry()
	box._on_focus_changed()

	assert_true(world.is_input_suspended(), "the keyboard is still driving the character")

	box.release_entry()
	box._on_focus_changed()
	assert_false(world.is_input_suspended(), "the character never got the keyboard back")


## Suspension has to reach every consumer, not just movement -- they all read
## intent through the one source.
func test_a_suspended_source_reports_a_player_doing_nothing() -> void:
	var source := PlayerInputSource.new()
	source.suspended = true
	var state := source.poll()

	assert_false(state.is_moving(), "a suspended source reported movement")
	assert_false(state.jump)
	assert_false(state.attack)
	assert_false(state.interact)
	assert_false(state.use)
	assert_false(state.sprint)


## Escape lets go of the entry rather than closing the box, so a mistyped key
## does not throw away what is on screen.
func test_escape_releases_the_entry_without_closing() -> void:
	var world := _world()
	var box: ChatBox = world.get_node("ChatBox")
	box.set_open(true)
	box.focus_entry()

	box._unhandled_input(_key(KEY_ESCAPE))
	assert_false(box.is_typing(), "escape did not let go of the entry")
	assert_true(box.is_open(), "escape closed the whole box")


## Closing while typing must give the keyboard back, or the character is
## paralysed with no visible cause.
func test_hiding_it_while_typing_gives_the_keyboard_back() -> void:
	var world := _world()
	var box: ChatBox = world.get_node("ChatBox")
	box.set_open(true)
	box.focus_entry()
	box._on_focus_changed()

	box.set_open(false)
	box._on_focus_changed()
	assert_false(world.is_input_suspended(), "hiding the chat left the player unable to move")


## Chat is not part of the simulation, and a pause menu is exactly when someone
## types "back in a minute".
func test_it_keeps_running_while_paused() -> void:
	assert_eq((_world().get_node("ChatBox") as ChatBox).process_mode, Node.PROCESS_MODE_ALWAYS)
