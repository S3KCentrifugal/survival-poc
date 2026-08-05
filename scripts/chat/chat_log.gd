class_name ChatLog
extends RefCounted
## What has been said, and the rules about what may be said.
##
## Pure: no nodes, no network, no text boxes. Which matters more here than it
## looks, because a chat log is a place where **other people's text** ends up on
## your screen -- so the trimming, the length cap and the control-character
## strip are the security-shaped part of this feature, and they belong somewhere
## they can be tested with hostile input rather than by asking someone to type
## it.

## The kinds of line the box shows. Not decoration: a system line is not
## attributable to anyone and must not be able to look as though it is.
enum Kind { CHAT, SYSTEM }

## One line.
class Entry:
	extends RefCounted

	var author: String
	var text: String
	var kind: Kind

	func _init(p_author: String, p_text: String, p_kind: Kind = Kind.CHAT) -> void:
		author = p_author
		text = p_text
		kind = p_kind

	## What the box draws. System lines carry no author, so nothing said by the
	## game can be mistaken for something said by a player.
	func line() -> String:
		return text if kind == Kind.SYSTEM else "%s: %s" % [author, text]


## Longest a single message may be, in characters.
##
## Generous for a sentence and far short of what fits in a packet. Enforced here
## rather than on the text box, because the text box is not the only way a
## message arrives -- the other one is a stranger's network peer.
const MAX_LENGTH: int = 240

## Longest a name may be.
const MAX_AUTHOR_LENGTH: int = 24

## How many lines are kept. Old ones fall off the top.
var capacity: int

var _entries: Array[Entry] = []


func _init(p_capacity: int = 100) -> void:
	capacity = maxi(p_capacity, 1)


## Adds a line and returns it, or null if there was nothing worth adding.
##
## Sanitises rather than rejects: a message with a newline in it is a message
## with a newline in it, not an attack to refuse and not a reason to drop
## someone's sentence.
func add(author: String, text: String, kind: Kind = Kind.CHAT) -> Entry:
	var clean := sanitise(text)
	if clean.is_empty():
		return null
	var entry := Entry.new(sanitise(author).left(MAX_AUTHOR_LENGTH), clean, kind)
	_entries.append(entry)
	while _entries.size() > capacity:
		_entries.pop_front()
	return entry


## Adds a line from the game rather than from a person.
func add_system(text: String) -> Entry:
	return add("", text, Kind.SYSTEM)


func entries() -> Array[Entry]:
	return _entries.duplicate()


func size() -> int:
	return _entries.size()


func is_empty() -> bool:
	return _entries.is_empty()


func clear() -> void:
	_entries.clear()


## Every line, oldest first, as the box draws them.
func text() -> String:
	var lines: Array[String] = []
	for entry: Entry in _entries:
		lines.append(entry.line())
	return "\n".join(lines)


## Strips anything that would let a message be more than a message.
##
## Newlines and carriage returns become spaces rather than being removed: a
## message that can contain a newline can draw a fake second line, and one that
## can contain a *lot* of them can push the whole log off the screen. Other
## control characters go entirely -- there is no legitimate chat message
## containing a null byte or an escape.
static func sanitise(text: String) -> String:
	var out := ""
	for index in text.length():
		var code := text.unicode_at(index)
		if code == 10 or code == 13 or code == 9:
			out += " "
		elif code >= 32 and code != 127:
			out += String.chr(code)
	return out.strip_edges().left(MAX_LENGTH)
