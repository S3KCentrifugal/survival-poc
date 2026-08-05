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
- **Probably not Godot's high-level multiplayer.** `MultiplayerSynchronizer` and
  `@rpc` are convenient and are built for tens of peers, not thousands. Expect to
  replace them with a custom binary protocol over ENet, and to write the server
  simulation as a headless Godot build — or eventually as a separate service.
- **Ops.** Deployment, monitoring, rollback, and a backend team's worth of work
  that has nothing to do with the game.

An MMO is not a networking feature; it is a different product with a different
cost structure. What this architecture buys is that the *game code* does not have
to be thrown away to get there.

## Order of work

Each step leaves the game playable and single-player working, and each is
independently useful. Nothing below is built yet except step 1.

1. **Session and authority seam.** A `GameSession` that knows whether this
   process is a server, and a rule every state-mutating system asks before it
   acts. Single-player answers "yes, you are the server" to everything, so
   behaviour is unchanged. *(Done — see `PROGRESS.md` feature 25.)*
2. **Move mutation behind authority.** Damage validated server-side; AI and
   spawners server-only. Still single-player, still identical to play.
3. **A transport.** Host and join over ENet. Two processes, one player each,
   both seeing the same world. This is where it stops being theoretical.
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
