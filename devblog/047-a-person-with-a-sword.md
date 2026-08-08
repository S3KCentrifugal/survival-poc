# 047 — A person, with a sword

*8 August 2026 — covers the humanoid player and weapon commit*

The player has been a CC0 robot since feature 1: two and a half heads tall, legs
under a third of its height, arms like a barrel with sleeves. Asked for a more
humanoid character, one that can hold the sword the merchant sells and swing it
— with the AI left exactly as they were.

The interesting constraint is the one `ART.md` has stated from the start: there
is no artist. So the character is generated, the same way the grass and the
trees are.

## Retargeting rather than replacing

The robot is rigged properly. Twenty-five bones with Rigify names — spine chain,
shoulders, arms, legs, toes — and twenty animation clips including `Attack1`.
What it is not is *proportioned* like a person:

| | Robot | A person |
|---|---|---|
| Head | 26% of the figure | ~13% |
| Legs | 29% | ~47% |
| Height in an 1.8 m capsule | 1.41 m | — |

So the bones get moved rather than replaced. Rest translations are what set limb
lengths, and animation tracks are rotations *relative to* those rests — so
lengthening a thigh keeps every clip working and simply gives the character a
longer stride. `HumanoidRig` scales the leg and arm chains, shortens the torso to
meet them, narrows the shoulders, lifts the root so the longer legs do not go
through the floor, and scales the armature until the figure fills the collision
capsule it has been rattling around inside for forty-six features.

`HumanoidMesh` then builds a body over whatever proportions result — tapered
tubes per bone, every vertex weighted wholly to one bone, colours in the vertices
because there is no texture and nobody to draw one. It reads the rig rather than
duplicating it, so changing the proportions changes the body with no second copy
of any measurement.

Only the player. The wanderers, the companion and the merchants keep the robot,
which was the brief and is also better: the thing you control being shaped
differently from the things you meet is information.

## Three silent failures

**A skinned mesh with no skeleton path renders in its bind pose.** The character
stood in a perfect T-pose in the middle of a field. The bones underneath were
animating correctly, the skin was bound correctly, and nothing errored —
`MeshInstance3D.skeleton` is `..` when the node is authored in the editor and
**empty** when it is built with `new()`. One line, and until it was found the
symptom pointed at the rig, the skin, and the animation in turn.

**`COLOR` is only interpolated into `fragment()` if `vertex()` touches it.** The
whole figure rendered flat white with its vertex colours sitting unread in the
mesh. Copying `COLOR` into a varying fixed it.

**The value band flattened the palette — for the third time.** Banding each
colour separately lands skin, tunic and boots on the same brightness by
construction. This is precisely the mistake the foliage gradient made in post
046 and the blade tips made before that, and I made it again anyway. The palette
now moves as one, scaled by a single number.

Then the *opposite* mistake, which was new: capping that scale so nothing clips
to white, and capping it so hard that the band did nothing at all. The character
rendered at its authored albedo, sat at the same value as the grass, and measured
1.7:1 against a 3:1 rule. A light character is not an accident of this palette —
it is what rule 3 costs.

## Rule 3 got harder, and that is the honest headline

`player-close` measured **3.5:1** with the robot. It measures **3.0:1** with the
person.

That is not a bug, it is the trade. Rule 3 is a rule about **mass**, and a slim
humanoid has less of it than a barrel-shaped toy. Two things bought it back to
the line: a deliberately pale torso over dark legs — a legibility decision before
it is a costume one, because `FrameLook` samples a disc at chest height and so
does a player's eye — and widening the figure after a first attempt came out
spindly. The drawing and the measurement were arguing about the same number,
which is the useful case.

The measuring disc was recalibrated with the model, and it needed to be. 0.15 of
the character's height fitted a robot that was very nearly as wide as it was
tall; a person is about a fifth as wide as they are tall, so that disc reached
straight past the torso into the grass. Recalibrating a measurement in the same
commit that changes what it measures is uncomfortably close to moving the
goalposts — the defence is that the old disc was measuring background on *any*
humanoid, and the new figure is stated rather than buried.

## The sword

`WeaponDefinition` points at an item by id rather than living on it. Most items
are never held — a mushroom, a bowl of soup, a coin — and giving every one of
them a damage bonus and a grip transform would put weapon data on the whole
inventory.

`WeaponComponent` reads the inventory it was given and writes to the attack it
was given; neither goes looking for the other. **Carry a sword and you are
holding it.** There is no equip screen, because there is one weapon and a screen
for it would be a screen with one button.

The blade hangs off a `BoneAttachment3D` on `hand.R`, so the existing `Attack1`
clip swings it without a frame of new animation being authored. The mesh is
split out of the pickup scene into `sword_held.tscn` — a held weapon carrying a
pickup component is a weapon you can interact with while holding it.

Damage, heavy damage and reach are pushed onto `AttackComponent` as plain
variables. Not written into `AttackConfig`: that is a `.tres` shared by every
actor using it, so arming the player through it would arm every wanderer in the
world. That is the resource-cache trap, which has now caught this project four
times, and a weapon system is exactly the shape of feature that invites it — so
there is a test that loads the config back and asserts it is untouched.

The sword's description used to end "Does nothing yet, which is a promise rather
than a feature." It has been changed.

## What this is not

A character. It is a generated figure of tapered tubes with a rounded head and
no face, and it will not survive contact with an actual artist — nor should it.
`ART.md` has said since post 043 that silhouette design is the one part of this
that is neither derivable from a rule nor measurable afterwards. What has changed
is that the placeholder is now a *person-shaped* placeholder that holds a sword,
which is enough to build combat against.

---

Next: Phase 4 — water.
