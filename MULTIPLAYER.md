# Multiplayer architecture

The plan for getting from a single-player prototype to a 100-player server, and
from there to something MMO-shaped, without rewriting the game twice.

Read `PROGRESS.md` first for what exists. This file is forward-looking: it
describes decisions taken now that only pay off later, and the order things
should happen in.

## The one rule

**Single-player is a server with one local player.** There is no separate
single-player code path, ever.

The moment there are two paths, they diverge, and every multiplayer bug becomes
a bug that only reproduces in multiplayer — which is the expensive kind. The
game boots as an authoritative host with one local peer and no listening
socket. Adding a socket is what makes it multiplayer.

This is what Minecraft, Valheim and Rust all do, and it is the single most
important decision in this document.

## Authority model

**Server-authoritative.** The server simulates the world; clients send *intent*
and render what they are told.

Not negotiable for this game, for three reasons:

- **Persistence.** An MMO's world state must be the server's, or it is the
  state of whoever last saved it.
- **Cheating.** A client that decides its own damage decides everything.
- **Consistency.** 100 players cannot each hold their own opinion of where the
  wanderers are.

The cost is latency: your own actions do not take effect until the server agrees.
The standard mitigation is **client-side prediction with reconciliation** for the
local player only, which is deferred (see the order of work below) but which the
architecture already permits — see the next section.

## What already fits, by luck and by design

This is the part worth knowing, because it decides how much of the existing code
survives.

| | |
|---|---|
| **`InputSource`** | The big one. Feature 4 built it so "a server can eventually receive intent from a client", and that is exactly what happens: a `RemoteInputSource` on the server is fed from client packets and `MovementComponent` cannot tell the difference. Three drivers already exist (human, wander AI, follow AI) and none required movement to change. A fourth will not either. |
| **The pure logic layer** | `MovementSolver`, `Stamina`, `VitalPool`, `Cooldown`, `Wander`, `Follow`, `MeleeSolver`, `Heightfield` are all `RefCounted` with no scene tree and no globals. Given the same inputs and the same delta they produce the same output. That is the precondition for both server simulation and client prediction, and it is already true. |
| **`SaveIdComponent`** | Stable identity per object, already distinguishing placed things from spawned ones. Network ids should be these ids — one identity scheme, not two. |
| **Config in `Resource` files** | Server and client agree on tuning because they ship the same `.tres`. Nothing has hard-coded numbers to drift. |
| **Presentation separated from state** | The HUD, damage numbers, explosions and floating health bars are all driven by signals off components. They become client-side reactions to replicated events with no change of shape. |

## What is wrong today

Equally honest. None of this is a mistake — it is single-player code written when
single-player was the whole game — but each is a thing that must move.

1. **Damage is applied by the attacker.** `AttackComponent.punch()` finds targets
   and calls `take_damage()` directly. Must become: client asks, server validates
   reach and cooldown, server applies, server tells everyone.
2. **AI runs on every peer.** `WanderComponent` and `FollowComponent` would
   simulate independently on each client and immediately diverge. Server only.
3. **Spawners run on every peer.** `WandererSpawner` would produce a different
   population per client. Server only.
4. **The day/night clock is local.** Every client would have its own time of day.
   Must be server time, replicated, with clients interpolating between updates.
5. **The dev console can do anything.** `tp`, `kill`, `time` and `speed` are
   world-mutating. They need a server gate and an authorisation concept before
   any socket is opened.
6. **`CharacterBody3D` + `move_and_slide` is not bit-deterministic** across
   platforms. Lockstep is therefore out. The model is snapshot replication with
   interpolation, plus prediction for the local player.

## Replication plan

Three channels, three different rates, for three different reasons.

**Intent, client → server, every physics tick (60 Hz).**
An `InputState` is tiny: a direction, a few flags. Unreliable-ordered — a dropped
input is stale by the time it would arrive. At 100 players that is 6,000 small
packets a second inbound, which is unremarkable.

**State, server → client, 20 Hz.**
Transform, health, animation state, per entity *in interest*. Clients render
~100 ms in the past and interpolate between snapshots, which is what makes 20 Hz
look smooth. Unreliable — the next snapshot supersedes a lost one.

**Events, server → interested clients, reliable.**
Hits, deaths, explosions, chat. Things that happen once and must not be lost.

## Interest management

The thing that decides whether an MMO is possible, and the reason it is listed
here rather than left until later.

A server sending every entity to every client is O(players × entities). At 100
players it is survivable; at MMO scale it is the whole problem. The answer is a
spatial grid — cells of roughly 32 m, each entity published to its cell, each
client subscribed to its own cell and the ring around it.

Two things in the current design already help:

- The world is already a **tile** with a node-free `Heightfield`. Chunking is
  many heightfields rather than a rewrite, and chunk boundaries are natural
  interest cells.
- Entities already have **stable ids**, so an entity entering and leaving
  interest is the same entity when it comes back.

## Scaling

**To 100 players.** One server process. Godot's ENet transport, 20 Hz snapshots,
distance-based interest. The realistic bottleneck is not bandwidth but the
server's own physics: 100 characters plus AI on one thread. Mitigations, in
order of preference: run AI at a lower tick than physics, sleep distant
entities, and only then reach for threads.

**To an MMO.** This is where honesty matters, because the answer is not "more of
the same":

- **Zone servers.** One process per region, with handoff at boundaries. The
  per-tile terrain helps; nothing else in the current design assumes one process.
- **A real persistence layer.** The save system (not yet built) becomes a
  database, not a file. This is the strongest argument for building the save
  system *after* this document rather than before it.
- **A gateway.** Login, character selection, and routing to the right zone.
- **Ops.** Deployment, monitoring, rollback, and a backend team's worth of work
  that has nothing to do with the game.

An MMO is not a networking feature; it is a different product with a different
cost structure. What this architecture buys is that the *game code* does not have
to be thrown away to get there.

## Not closing the door on a Rust server

The plan of record is that if this becomes an MMO, **the server is written in
Rust**, not Godot. That is out of scope for now, but it decides what may be
built today. Three things would make it hard, and each is avoided deliberately.

**1. Godot's serialisation.** `@rpc`, `MultiplayerSynchronizer` and
`var_to_bytes` all encode Godot's `Variant` type system. Anything reading them
has to reimplement `Variant` first.

*Avoided by:* `NetworkProtocol`. Every byte on the wire is a plain integer or an
IEEE-754 float in a documented little-endian layout, with the message table and
quantisation error bounds written down and asserted by tests. That file is a
specification a Rust implementation follows. No Godot type ever goes on the wire.

**2. A transport tangled through the codebase.** If sending were scattered
across components, swapping it would mean touching all of them.

*Avoided by:* `NetworkService` being the only file that knows a socket exists.
It carries opaque bytes and reports who joined. Godot wraps `send_bytes`
payloads in a small framing byte of its own — the one Godot-specific detail left
— so a Rust server either matches that framing or replaces this single file.
Everything above it speaks `NetworkProtocol` and does not care.

**3. Tuning the server cannot read.** Thirteen `.tres` files hold the numbers
that decide how fast a player moves and how hard a punch hits. A Rust server
must agree with the client on every one of them, and cannot parse `.tres`.

*Not yet solved, and the next thing to do about it:* export the tuning to JSON
from a single source of truth, so both implementations read the same numbers.
Until then, the risk is small — thirteen files, none large — but it grows with
every new config.

### The one that is genuinely hard: physics

The server has to decide where players actually end up, and today that is
`CharacterBody3D.move_and_slide` — Godot's physics engine, which a Rust server
cannot reproduce and should not try to.

There is no clean dodge, so the honest positions are:

- The *decisions* are already portable. `MovementSolver`, `Stamina`,
  `VitalPool`, `Cooldown`, `Wander`, `Follow` and `MeleeSolver` are pure maths
  over plain numbers, with no engine in them. Porting them to Rust is
  transcription, not redesign — and that is most of the rules.
- What is left is **collision resolution**, which is a capsule against static
  world geometry. That is a well-understood problem with Rust crates for it, and
  the world is boxes and a heightfield rather than arbitrary meshes.
- Until that day, a headless Godot build *is* the server. That is what supports
  100 players and it is a perfectly good answer for a long time.

The rule this implies for new gameplay code: **keep authoritative decisions in
the pure logic layer, and let Godot physics only move things.** A rule that says
"you cannot punch more than once every 0.35 s" belongs in a `Cooldown`; a rule
that says "you stopped because a wall is there" is the engine's. The first must
be portable; the second is allowed not to be.

## Order of work

Each step leaves the game playable and single-player working, and each is
independently useful. Nothing below is built yet except step 1.

1. **Session and authority seam.** A `GameSession` that knows whether this
   process is a server, and a rule every state-mutating system asks before it
   acts. Single-player answers "yes, you are the server" to everything, so
   behaviour is unchanged. *(Done — see `PROGRESS.md` feature 25.)*
2. **Move mutation behind authority.** Damage validated server-side; AI and
   spawners server-only. Still single-player, still identical to play.
3. **A transport.** Host and join over ENet, carrying `NetworkProtocol` bytes.
   *(Done — see `PROGRESS.md` feature 26. Two processes exchange handshake,
   intent and snapshots; entity replication is step 4.)*
4. **State replication with interpolation.** Remote players and AI move
   smoothly at 20 Hz.
5. **Client prediction and reconciliation** for the local player, so your own
   movement is not latency-bound. The pure `MovementSolver` is what makes this
   tractable.
6. **Interest management.** Required before player counts get interesting.
7. **Persistence.** Server-side, database-shaped, using the existing ids.

## Rules for new code, starting now

These are cheap to follow today and expensive to retrofit:

- **Never mutate shared state without asking whether you are the authority.**
  Use `NetworkAuthority.may_simulate(node)`. It returns true in single-player, so
  it costs nothing now.
- **Intent comes from an `InputSource`.** Never read the `Input` singleton
  outside `PlayerInputSource`. This rule already exists and is now load-bearing
  for a second reason.
- **Keep decisions in `RefCounted` logic classes**, pure and delta-driven. It is
  what allows the same code to run on a server, in a prediction step, and in a
  test.
- **Presentation reacts to signals; it never decides.** An explosion is a
  reaction to a death, not a cause of one.
- **New global state belongs to the session**, not to an autoload that clients
  and servers both write.
