# 041 — Getting it to testers

*6 August 2026 — covers the deployment pipeline commit*

The game has never left this machine. This is the pipeline that changes that,
and the analysis behind picking one route over the others.

## The route

Free access, easy to get and update, on Windows, Linux, Steam Deck and Steam
Machine. Two consequences fall straight out of "free":

There is no price to set, so anything built around purchase flows is the wrong
shape. And there is no revenue, so **the $100 Steam Direct fee is a real cost** —
it is recoupable only against $1,000 of adjusted gross revenue, which a free
playtest will never earn. Worth saying plainly rather than repeating "recoupable"
as though it were free.

Five options, and it is not a close call:

| Route | Cost | Testers get | Auto-update |
|---|---|---|---|
| **Steam Playtest** | $100 once | Library entry, overlay, **Deck install** | Yes |
| Steam demo app | $100 once | Public listing, no gating | Yes |
| Beta branch + password | $100 + keys | Must *own* the app first | Yes |
| itch.io | Free | Download or the itch app | With the app |
| GitHub Releases | Free | A zip | No |

**Steam Playtest** is the feature Valve built for this exact case: a separate,
free app linked to your store page with a "Request Access" button you can set to
auto-grant. A demo is a marketing artefact — public and ungated. A
password-protected beta branch needs testers to *own* the app, which for an
unreleased free game means handing out keys, more admin than the thing it
replaces.

The thing that settles it against itch.io — which is otherwise excellent and
free — is the Deck. A Deck user installing from itch drops to desktop mode,
downloads a zip, chmods a binary and adds a non-Steam shortcut. If Deck support
is part of the ask, Steam is the route.

So: **both**. itch and GitHub Releases work today; Steam does not, because the
fee has to clear and two apps need review. Use the bridge while that happens.

## Building something before writing about building something

The temptation with a pipeline is to write the YAML and let CI discover whether
it works. Instead: install the export templates locally, produce both builds,
and run one.

That turned up things worth knowing before writing any workflow. The export
templates are a **1.2 GB** download, separate from the editor — so the CI cache
is not an optimisation, it is the difference between a four-minute build and a
fifteen-minute one. The Linux build is 75 MB and the Windows build 108 MB. And
`run_tests.sh` hard-coded the engine path, which would have forced CI to fake
the managed-tree layout with a symlink; it takes a `GODOT` override now, as
`build.sh` does.

`build.sh` is the build, and CI is a thin wrapper around it. A pipeline whose
only home is a YAML file is a pipeline you debug by pushing commits at it.

## The bit that will break

**Steam preserves the executable bit it is given.** Two ways to lose it:

- Uploading a Linux depot from a **Windows** runner. NTFS has no executable bit.
- Passing the build through `upload-artifact` / `download-artifact`, which does
  not preserve permissions at all.

Either way the game installs perfectly and then does nothing when launched.
There is no error, because nothing errored. It is set in `build.sh` and re-set
in the Steam job, and there is a test asserting both — not because a test can
catch the real failure, but because someone restructuring the pipeline will
delete one of them.

## The credential problem, which is fiddly for everyone

`steamcmd` requires Steam Guard, Steamworks will not let a publishing account
disable it, and CI cannot answer a 2FA prompt.

The way through is to authenticate once on a real machine and hand CI the
resulting `config.vdf`, base64'd into a secret. Two things about that worth
writing down where somebody will find them:

- Use a **separate builder account** with permissions on the playtest app only.
  If the secret leaks, the blast radius is one playtest.
- **The session expires.** A password change or Steam deciding it is stale kills
  it, and the failure appears in CI weeks after anyone touched the pipeline,
  looking like a login error out of nowhere.

`SetLive` is deliberately empty in `steam/app_build.vdf`. Uploading and
promoting are different decisions, and a script that does both is one nobody
dares run.

## Deck and Steam Machine

Both run SteamOS: Arch-based Linux on x86_64. **They are not separate build
targets** — one native Linux binary serves desktop Linux, the Deck and the Steam
Machine, and Steam will fall back to running the Windows build under Proton if
the Linux one is ever missing.

Building for the Deck and being good on it are different questions, though, and
the honest answer is that this game is not ready:

- **No controller support at all.** Every input is keyboard or mouse. On a Deck
  that means the built-in controls do nothing until a player configures Steam
  Input by hand. This is the single biggest gap.
- **The interface is tuned for 1080p.** The Deck is 1280×800, and `UI.md`'s
  12 px caption size is small on a seven-inch screen.

Expect **Playable**, not **Verified**. Which is fine — Verified is a store-page
badge, not a requirement to install, and a playtest is exactly when you find out
what the controls should be.

## What the tests can and cannot do

`test_shipping.gd` checks the things that fail silently until release day: that
the presets are named what `build.sh` asks for (Godot matches the string and
exports *nothing* otherwise, with no error), that the pack is embedded so a
tester cannot lose a `.pck`, that tests and the devblog are excluded from the
build, that the depots point at what the build actually produces, that the
release workflow runs the suite first, and that no credential is committed.

What it cannot check is Steam. There is no App ID and no account, so the upload
is unverified by definition. That is what `DEPLOY.md` is for, and why it says to
do the first upload by hand — so that when CI fails you already know whether it
is CI.

---

Next: nothing scheduled. Posts 002–011 and 025–027 are still owed.
