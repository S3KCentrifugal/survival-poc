# 015 — A console, and two ways to lose an object

*2026-08-04 · commit pending*

A dev console on the backtick key: `tp`, `time`, `heal`, `hurt`, `stamina`,
`speed`, `where`, `kill`, `help`, `clear`, `quit`. Useful on its own, but the
interesting part is that building it surfaced two bugs from the same corner of
GDScript, in opposite directions, and the test suite caught one of them without
a single assertion failing.

## The shape

Three pieces, for the usual reason:

- **`DevConsole`** — registry, parser, history. Knows nothing about survival
  games. Takes a line, returns what to print.
- **`GameCommands`** — what the commands actually do to this world.
- **`DevConsoleUI`** — the panel, the keys, the text box.

The split earns itself immediately: a console exists to replace "type it and
watch", and because `run()` is a pure string-in-string-out function, every
command is exercised in a test instead. `test_game_commands.gd` runs `tp 12 -9`
against a real mounted world and asserts the player landed on the ground.

## Two things that had to be got right to be usable at all

**The world pauses while the console is open.** Without it the player keeps
walking as you type, because `PlayerInputSource` reads the `Input` singleton and
a focused `LineEdit` does precisely nothing about that. Focus is a UI concept;
the `Input` singleton is global state.

**The toggle is handled in `_input`, not `_unhandled_key_input`.** The text box
has focus while the console is open, so an unhandled-input handler never sees
the backtick — the `LineEdit` types it instead, and the key that is supposed to
close the console just puts a backtick in your command. `_input` runs before GUI
handling, so it can take the key and call `set_input_as_handled()`.

## Bug one: a Callable does not keep its object alive

`GameCommands` was a local:

```gdscript
var commands := GameCommands.new()
commands.install(_console)     # registers ~10 DevCommands holding its methods
```

The function returns, the last reference to `commands` goes away, the
`RefCounted` is freed. `Callable` stores an **object id**, not a reference — so
all ten commands survived as objects with dead callables.

The failure mode is the quiet kind. Nothing errors. `Callable.is_valid()`
returns false and my `DevCommand.run()` politely answered *"registered but does
nothing"* for every single command.

It was caught immediately, but by a *weak* test. `test_every_command_survives_
having_nothing_to_work_on` asserted each command returned a non-empty string —
and `"unknown command: tp"` is non-empty, so it would have passed even with
nothing registered at all. What actually caught it was a dozen other tests
failing together. The weak test has since been taught to reject "unknown" and
"does nothing" specifically.

The fix is to hold the owner in a member. Obvious in hindsight, invisible while
typing.

## Bug two: a bound argument *is* a strong reference

The exact opposite, ten lines away. `help` needs the registry to list, so:

```gdscript
DevCommand.new(&"help", ..., _help.bind(console))
```

`bind()` stores its arguments as Variants, and a Variant holding a `RefCounted`
**is** a strong reference. So:

```
DevConsole → DevCommand → Callable(bound: DevConsole) → DevConsole
```

A reference cycle. GDScript reference-counts and does not collect cycles, so
every `DevConsole` ever created leaked — along with its commands and its
`GameCommands`. Roughly thirteen objects per mounted world.

**Nothing failed.** All 345 tests passed. The only evidence was a line after the
summary:

```
27 suites, 344 tests, 1330 assertions
all passing

WARNING: 335 ObjectDB instances were leaked at exit
```

I nearly scrolled past it. What made it worth chasing was that it had not been
there the day before — and confirming *that* was a two-minute experiment: move
the new suite out of `tests/`, re-run, and watch the number drop from 335 to
111. Still not zero, which was the real clue: the remaining 111 came from every
*other* suite that mounts `main.tscn`, because the console is in the scene now.
One leak, two symptoms.

The fix was to stop closing over the console: `help` is about the registry, so
`DevConsole` registers it as a built-in and calls its own method. No bound
argument, no cycle, and arguably where it should have lived from the start —
`GameCommands` had no business owning the command that lists commands.

Both leak warnings are now gone, including the pre-existing 111. That makes the
exit warnings worth treating as a signal rather than noise, which they were not
before today.

## The asymmetry, stated plainly

Now in `CLAUDE.md`, because it is not intuitive and it bit twice in one hour:

> A `Callable` stores an object **id** — it will not keep a `RefCounted` alive,
> and goes silently invalid when the object dies. But `bind()` stores its
> arguments as **Variants**, which are strong references — so binding an object
> into a callable that object can reach makes a cycle nothing collects.

Hold the owner in a member. Do not bind a collection into the things it
collects.

## Small things worth keeping

`tp` puts you *on* the terrain rather than at whatever height you happened to
be, because otherwise every teleport needs a second command to stop falling.

Numeric arguments go through a parser that refuses non-numbers, so `tp north 4`
says so instead of silently reading as zero and looking like a teleport that
worked.

`speed` duplicates the movement config before editing it — post 013's resource
cache lesson, applied without having to relearn it.

`kill` prints *"the died signal fired, but nothing listens to it yet"*, because
a command that appears to do nothing is worse than one that explains why.

The panel is 98% opaque rather than translucent. At 92% the debug overlay on the
layer below bled through and console output was printed over the readout —
visible in the first screenshot, and only in the screenshot.
