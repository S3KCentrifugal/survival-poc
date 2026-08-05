# 028 — A front door

*5 August 2026 — covers the title screen commit*

Until now the game had no front door. Launching it dropped you straight into
the world, standing in a room, already playing. That was fine while the only
person launching it was the person who wrote it, and it stopped being fine the
moment there were two ways to play.

## The scene is not the game

The real change here is not a menu. It is that `res://scenes/main.tscn` is no
longer the entry point. `project.godot` now points at `res://scenes/title.tscn`,
and the world is something you *navigate to*.

That distinction matters more than it sounds. A game whose entry point is the
world has nowhere to put anything that happens before the world exists —
choosing single-player or multiplayer, reading a saved graphics setting,
picking a server. All of that has to happen while there is nothing to render
into, which means it cannot live inside the thing being rendered.

## Why the swap is done by hand

The obvious way to change scenes in Godot is `SceneTree.change_scene_to_file()`.
It is deferred and it hands nothing back. There is no moment at which the new
scene exists and you can talk to it.

Hosting needs exactly that moment. "Press Host" is two things in sequence:
build the world, *then* open a socket in it. With the deferred call you get the
first and have no handle on the result, so the second has to be smuggled in
through a static or an autoload — a global variable holding "what the player
picked", read by the scene once it wakes up. That is a bad seam, and it is
exactly the sort of thing that becomes load-bearing.

So `SceneRouter` does the swap itself:

```gdscript
var previous := tree.current_scene
var next := scene.instantiate()
tree.root.add_child(next)
tree.current_scene = next
if previous != null and is_instance_valid(previous):
	previous.queue_free()
```

Four lines, and now `to_game()` can do the thing the deferred call cannot:

```gdscript
var world := swap(tree, load(GAME_SCENE))
if mode == GameSession.Mode.SINGLE_PLAYER:
	return world        # no socket; already a host with one local player
var network := world.get_node_or_null("Network") as NetworkService
if mode == GameSession.Mode.HOST: network.host(port)
else:                              network.join(address, port)
```

The `queue_free` is deferred on purpose, and this is the trap in the four
lines. A button handler is running *inside* the scene it is about to destroy.
Freeing it immediately pulls the ground out from under the caller mid-signal.
`queue_free` defers to the end of the frame, by which point the handler has
returned.

## Leaving is not just arriving in reverse

`to_title()` is not `to_game()` with the arguments swapped. Two things have to
be undone on the way out, and neither is obvious until it bites:

**The socket.** A player who returns to the title while still connected is a
ghost standing in someone else's world — their character keeps being simulated
by the server because nothing told the server they left. So the router closes
the connection before it swaps.

**The pause.** The pause menu is the *only* place you can press "Main menu"
from, and the pause menu only exists while `tree.paused` is true. Swap without
unpausing and you get a title screen whose buttons do nothing, because the
title screen is not `PROCESS_MODE_ALWAYS` and has no reason to be. This one is
invisible in code review and instant in play.

## One settings panel, not two

The title needs settings. So does the pause menu, which already had them.

The wrong fix is to build the panel twice, which is how a project ends up with
a graphics option that exists in one menu and not the other. The panel came out
of `ui/pause_menu.tscn` into its own `ui/settings_menu.tscn`, and both screens
instance it.

Load-apply-save moved out too, into `SettingsController`. Both owners hold one.
And the ordering here produced the one real bug of the feature:

> A child's `_ready` runs before its parent's.

The controller originally loaded and applied settings in its own `_ready`. The
pause menu's test overrides `settings_path` so a test run does not rewrite the
settings of whoever ran it — but by the time the parent could pass the override
down, the child had already read the default path. The suite failed with
`expected 144, got 0`, which reads like a persistence bug and is a lifecycle
bug.

The fix is that `SettingsController` does nothing on its own. It acts when told:

```gdscript
settings_controller.settings_path = settings_path
settings_controller.camera = camera
settings_controller.load_and_apply()
```

A node that configures itself at `_ready` cannot be configured by its owner.
Worth remembering the next time something wants to be helpful in `_ready`.

## What the tests can and cannot reach

`SceneRouter.swap()` frees the current scene. During a test run, the current
scene *is* the test runner. A test that presses "Single player" for real
destroys the thing running it, which is a memorable way to discover the
distinction between a unit and an integration test.

So `test_title_screen.gd` checks everything up to that call — the panels, the
wiring, the port parsing, that joining with a blank address refuses and says
why — and the round trip was verified separately with a throwaway probe:

```
after play: current_scene=Main
  player: Player:<CharacterBody3D#68216162268>
  networked: false
after main menu: current_scene=TitleScreen
  paused=false
```

Single-player opens no socket, which is the whole point of feature 25's
design: single-player is a host with one local player, so "start the game" and
"start the game with networking" are the same code path with a different
argument.

---

Next: [029 — Two jumps, and a companion that could not
die](029-double-jump-and-a-companion-that-could-not-die.md). Posts 002–011 and
025–027 are still owed — the three
multiplayer features shipped without theirs, which is the convention in
`CLAUDE.md` being broken and worth writing down rather than quietly leaving.
