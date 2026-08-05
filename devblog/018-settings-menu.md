# 018 — A menu, and the file a player can edit

*2026-08-04 · commit `6ec1535`*

Escape opens a menu. It has Settings, and Settings has the graphics options a
game is expected to have. What it persists to is a text file in the player's
home directory, and most of the interesting work in this feature is about that
file being wrong.

## Four pieces, so the untestable part is small

None of the actual work — resizing a window, changing a monitor, setting an
MSAA level — can be verified in a headless test. There is no window. So the
split is drawn to make that part as thin as possible:

| | |
|---|---|
| `GameSettings` | plain data plus every rule about what is valid |
| `SettingsStore` | reads and writes `user://settings.cfg` |
| `SettingsMenu` / `PauseMenu` | show settings, collect them, report button presses |
| `SettingsApplier` | the only file that touches a window, a renderer or a bus |

`SettingsApplier` is about sixty lines and has no branches worth arguing about.
Everything that *can* be got wrong lives in the two classes above it, which have
forty-odd tests between them and never open a window.

## The settings file is the one thing a player can edit

Every other piece of state in this project is written and read by us. A settings
file is different: it sits in a documented location, in a plain text format,
and sooner or later somebody opens it and types a number.

So the rules are not defensive padding, they are the feature:

- **A monitor that is not there.** Settings written on a two-screen desk, opened
  on a laptop, would place the window on screen 2. The symptom is not an error
  message; it is a game that appears not to launch. `sanitise()` takes the
  current screen count and clamps.
- **A frame cap of 4000.** Rounds *down* to the highest we offer. Rounding up
  would mean a hand-edited file silently getting more than the menu can express;
  rounding down means the file can never ask for something we did not intend.
- **A corrupt file.** Gives defaults. Never propagates a parse failure.
- **A truncated file.** Loses one setting, not all of them — every field falls
  back independently, so half a file is half your settings rather than none.
- **Keys from a later build.** Ignored, so a settings file from a newer version
  does not stop an older one starting.

Each of those is one test with a name that says what it protects against.

## Escape had a job already

Feature 16 gave Escape to the mouse capture: press it, get your cursor back. A
pause menu wants the same key, and the same cursor.

The resolution is that they were always the same gesture. Opening the menu
pauses the game, releases the cursor and shows the panel — and any one of those
without the others is a bug you can feel. A menu you cannot click. A character
who walks off while you read the options. So `PauseMenu.set_open()` does all
three and `WorldRoot` no longer watches for Escape at all.

There is a second Escape consumer: the dev console. That resolved itself
pleasantly. The console handles input in `_input` and marks it handled; the menu
uses `_unhandled_input`. So Escape closes the console if one is open, and only
reaches the menu when nothing else wanted it — which is exactly the behaviour
you would design, arrived at by using the right hook for each.

Inside the settings panel, Escape steps back to the root menu rather than
closing everything, because a mistyped key should not throw away the panel you
were reading.

## Rows built from a list

The settings panel is a dozen label-and-control pairs. Written into the `.tscn`
that is roughly four hundred lines of node declarations which have to be edited
in lockstep with `GameSettings` — and which nothing checks. Built in code from a
list, adding a setting is one line and the layout cannot drift out of step.

The test that makes this safe asks for every setting's control by name and fails
if one was never built. That is the check the hand-written version could not
have had.

The one piece of judgement in the panel: a resolution picker in fullscreen is
**greyed out, not hidden**. A control that vanishes leaves you wondering whether
the game has the setting at all; one that greys out says "not for this mode".

## Two things about the test suite

**The suite now prints one error on a passing run.** The test that proves a
corrupt file cannot stop the game starting hands `ConfigFile` some garbage, and
Godot's parser logs before returning its error code — there is no quiet variant.
I nearly reworded the test to avoid it, and decided against: the test is worth
more than the silence, so instead the test's name and doc comment say the line
is expected, and `PROGRESS.md` records that a *second* error line means
something is actually wrong. Post 015 argued that clean output makes exit
warnings a usable signal; this is the smallest possible dent in that, made
deliberately and written down.

**The suite rewrote my own settings file.** `test_applying_saves_to_disk` did
exactly what it says, through a menu whose store pointed at the real
`user://settings.cfg`. Running the tests changed the settings of whoever ran
them. The screenshot is what caught it — the settings panel opened showing
144 FPS and 4x MSAA, which I had never chosen, because a test had.

`PauseMenu.settings_path` is overridable now, one test mounts the menu
standalone with its own path, and another asserts the shipped scene still
carries the real one. There is a general shape here worth remembering: **a test
that exercises persistence is a test that writes something, and the default
destination is somebody's real data.**
