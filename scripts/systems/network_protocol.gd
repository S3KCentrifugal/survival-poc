class_name NetworkProtocol
extends RefCounted
## The wire format, written out byte by byte.
##
## **This exists so the server can one day be written in Rust.** Godot's own
## `var_to_bytes`, `@rpc` and `MultiplayerSynchronizer` are all convenient and
## all encode Godot's `Variant` type system, which nothing outside Godot can
## read without reimplementing it. Every byte here is a plain integer or an
## IEEE-754 float, laid out explicitly, and the layout below is the
## specification a Rust implementation would follow.
##
## Rules, none of which may be broken without breaking the port:
##
## - **Little-endian**, always. Both x86 and ARM are, and being explicit costs
##   nothing.
## - **No Godot types on the wire.** No `Variant`, no `Vector3`, no `StringName`.
##   Positions are three floats; a rotation is one integer.
## - **Fixed layouts.** No optional fields, no self-describing anything. A
##   reader that knows the message kind knows the exact length.
## - **Quantise deliberately, and say by how much.** See the table below.
##
## ## Messages
##
## Every packet starts with one byte of kind. Sizes are the total in bytes.
##
## | Kind | Name | Direction | Size | Payload |
## |---|---|---|---|---|
## | 1 | HELLO | client → server | 3 | `u16` protocol version |
## | 2 | WELCOME | server → client | 11 | `u16` version, `u32` your id, `u32` tick |
## | 3 | INPUT | client → server | 10 | `u32` tick, `i8` move x, `i8` move z, `u16` yaw, `u8` buttons |
## | 4 | SNAPSHOT | server → client | 7 + 20n | `u32` tick, `u16` count, then n entities |
## | 5 | DESPAWN | server → client | 5 | `u32` entity id |
##
## An entity inside a snapshot is 20 bytes: `u32` id, three `f32` position,
## `u16` yaw, `u8` flags, `u8` health.
##
## ## Quantisation
##
## | Field | On the wire | Range | Worst error |
## |---|---|---|---|
## | move x/z | `i8` | -1 .. 1 | 0.004 |
## | yaw | `u16` | 0 .. 2π | 0.0001 rad |
## | health | `u8` | 0 .. 1 | 0.002 |
##
## Positions stay full `f32`: a centimetre of error on a position is visible as
## a jitter, and four bytes each is not what makes a snapshot expensive.
##
## ## Budget
##
## 20 bytes per entity. At 20 snapshots a second and 50 entities in interest
## that is 20 kB/s to each client, and 2 MB/s out of a 100-player server. That
## number is the entire argument for interest management: without it the same
## server sends 100× more.

## Bumped whenever a layout changes. A client and server that disagree must
## refuse each other rather than misread each other's bytes.
const VERSION: int = 1

enum Kind {
	NONE = 0,
	HELLO = 1,
	WELCOME = 2,
	INPUT = 3,
	SNAPSHOT = 4,
	DESPAWN = 5,
}

## Button bits in an INPUT message.
const BUTTON_SPRINT: int = 1 << 0
const BUTTON_JUMP: int = 1 << 1
const BUTTON_ATTACK: int = 1 << 2

## Flag bits on a snapshot entity.
const FLAG_ON_FLOOR: int = 1 << 0
const FLAG_SPRINTING: int = 1 << 1
const FLAG_ATTACKING: int = 1 << 2
const FLAG_HURT: int = 1 << 3
const FLAG_DEAD: int = 1 << 4

const ENTITY_SIZE: int = 20
const SNAPSHOT_HEADER_SIZE: int = 7


static func encode_hello() -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(3)
	bytes.encode_u8(0, Kind.HELLO)
	bytes.encode_u16(1, VERSION)
	return bytes


static func encode_welcome(peer_id: int, tick: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(11)
	bytes.encode_u8(0, Kind.WELCOME)
	bytes.encode_u16(1, VERSION)
	bytes.encode_u32(3, peer_id)
	bytes.encode_u32(7, tick)
	return bytes


## One tick of a player's intent.
##
## [param move] is a ground direction of length at most 1; [param yaw] is where
## they are facing, in radians.
static func encode_input(tick: int, move: Vector2, yaw: float, buttons: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(10)
	bytes.encode_u8(0, Kind.INPUT)
	bytes.encode_u32(1, tick)
	bytes.encode_s8(5, quantise_axis(move.x))
	bytes.encode_s8(6, quantise_axis(move.y))
	bytes.encode_u16(7, quantise_angle(yaw))
	bytes.encode_u8(9, buttons & 0xFF)
	return bytes


## Reads an INPUT back. Returns an empty dictionary if the bytes are not one.
##
## Every decoder checks the length before reading. A malformed packet is a
## thing a server receives from strangers, so it has to be a rejection rather
## than an out-of-bounds read.
static func decode_input(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() != 10 or bytes.decode_u8(0) != Kind.INPUT:
		return {}
	return {
		"tick": bytes.decode_u32(1),
		"move": Vector2(unquantise_axis(bytes.decode_s8(5)), unquantise_axis(bytes.decode_s8(6))),
		"yaw": unquantise_angle(bytes.decode_u16(7)),
		"buttons": bytes.decode_u8(9),
	}


static func decode_welcome(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() != 11 or bytes.decode_u8(0) != Kind.WELCOME:
		return {}
	return {
		"version": bytes.decode_u16(1),
		"peer_id": bytes.decode_u32(3),
		"tick": bytes.decode_u32(7),
	}


static func decode_hello(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() != 3 or bytes.decode_u8(0) != Kind.HELLO:
		return {}
	return {"version": bytes.decode_u16(1)}


## A batch of entity states.
##
## [param entities] is an array of dictionaries with `id`, `position`, `yaw`,
## `flags` and `health` -- health as a fraction from 0 to 1.
static func encode_snapshot(tick: int, entities: Array[Dictionary]) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(SNAPSHOT_HEADER_SIZE + entities.size() * ENTITY_SIZE)
	bytes.encode_u8(0, Kind.SNAPSHOT)
	bytes.encode_u32(1, tick)
	bytes.encode_u16(5, entities.size())

	var at := SNAPSHOT_HEADER_SIZE
	for entity: Dictionary in entities:
		var position: Vector3 = entity.get("position", Vector3.ZERO)
		bytes.encode_u32(at, int(entity.get("id", 0)))
		bytes.encode_float(at + 4, position.x)
		bytes.encode_float(at + 8, position.y)
		bytes.encode_float(at + 12, position.z)
		bytes.encode_u16(at + 16, quantise_angle(float(entity.get("yaw", 0.0))))
		bytes.encode_u8(at + 18, int(entity.get("flags", 0)) & 0xFF)
		bytes.encode_u8(at + 19, quantise_fraction(float(entity.get("health", 1.0))))
		at += ENTITY_SIZE
	return bytes


static func decode_snapshot(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < SNAPSHOT_HEADER_SIZE or bytes.decode_u8(0) != Kind.SNAPSHOT:
		return {}
	var count := bytes.decode_u16(5)
	# The count is a stranger's number until the length agrees with it.
	if bytes.size() != SNAPSHOT_HEADER_SIZE + count * ENTITY_SIZE:
		return {}

	var entities: Array[Dictionary] = []
	var at := SNAPSHOT_HEADER_SIZE
	for _index in count:
		entities.append({
			"id": bytes.decode_u32(at),
			"position": Vector3(
				bytes.decode_float(at + 4), bytes.decode_float(at + 8), bytes.decode_float(at + 12)
			),
			"yaw": unquantise_angle(bytes.decode_u16(at + 16)),
			"flags": bytes.decode_u8(at + 18),
			"health": unquantise_fraction(bytes.decode_u8(at + 19)),
		})
		at += ENTITY_SIZE
	return {"tick": bytes.decode_u32(1), "entities": entities}


static func encode_despawn(entity_id: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(5)
	bytes.encode_u8(0, Kind.DESPAWN)
	bytes.encode_u32(1, entity_id)
	return bytes


static func decode_despawn(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() != 5 or bytes.decode_u8(0) != Kind.DESPAWN:
		return {}
	return {"id": bytes.decode_u32(1)}


## What kind of message this is, or [constant Kind.NONE] for anything empty or
## unrecognised.
static func kind_of(bytes: PackedByteArray) -> Kind:
	if bytes.is_empty():
		return Kind.NONE
	var first := bytes.decode_u8(0)
	if first < Kind.HELLO or first > Kind.DESPAWN:
		return Kind.NONE
	return first as Kind


## Packs the intent flags an [InputState] carries.
static func buttons_of(state: InputState) -> int:
	var buttons := 0
	if state.sprint:
		buttons |= BUTTON_SPRINT
	if state.jump:
		buttons |= BUTTON_JUMP
	if state.attack:
		buttons |= BUTTON_ATTACK
	return buttons


## Rebuilds an [InputState] from a decoded INPUT. The server feeds these to a
## [RemoteInputSource], and movement cannot tell the difference.
static func input_state_from(decoded: Dictionary) -> InputState:
	var state := InputState.new()
	if decoded.is_empty():
		return state
	var buttons: int = decoded.get("buttons", 0)
	state.move = decoded.get("move", Vector2.ZERO)
	state.sprint = (buttons & BUTTON_SPRINT) != 0
	state.jump = (buttons & BUTTON_JUMP) != 0
	state.attack = (buttons & BUTTON_ATTACK) != 0
	return state


static func quantise_axis(value: float) -> int:
	return int(round(clampf(value, -1.0, 1.0) * 127.0))


static func unquantise_axis(value: int) -> float:
	return clampf(float(value) / 127.0, -1.0, 1.0)


## Angles go on the wire as a whole turn split into 65536, which is finer than
## anything a player can see and half the size of a float.
static func quantise_angle(radians: float) -> int:
	return int(round(fposmod(radians, TAU) / TAU * 65535.0)) & 0xFFFF


static func unquantise_angle(value: int) -> float:
	return float(value) / 65535.0 * TAU


static func quantise_fraction(value: float) -> int:
	return int(round(clampf(value, 0.0, 1.0) * 255.0))


static func unquantise_fraction(value: int) -> float:
	return clampf(float(value) / 255.0, 0.0, 1.0)
