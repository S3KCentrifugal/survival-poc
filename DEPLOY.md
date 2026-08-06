# Shipping to testers

How the game gets from a commit to somebody's machine, what has to be done by
hand, and why this route rather than the others.

The short version: **build in GitHub Actions, publish to a Steam Playtest, keep
GitHub Releases as the fallback that always works.**

---

## Part 1 — Choosing the route

### What the goal actually is

Free access for testers, easy for them to get and update, on Windows, Linux,
Steam Deck and Steam Machine. Not for sale.

Two things follow from "not for sale" that rule options in and out. There is no
price to set, so anything built around purchase flows is the wrong shape. And
there is no revenue, so **the $100 Steam Direct fee is a real, non-recoupable-
in-practice cost** — recoupable only against $1,000 of adjusted gross revenue,
which a free playtest will never make.

### The options

| Route | Cost | Testers get | Time to first build | Auto-update |
|---|---|---|---|---|
| **Steam Playtest** | $100 once | Library entry, overlay, friends, Deck support | Days (Valve review) | Yes |
| Steam demo app | $100 once | Public listing, no gating | Days | Yes |
| Steam beta branch + password | $100 once + keys | Must *own* the app first | Days | Yes |
| itch.io | Free | Download or itch app | Minutes | With the itch app |
| GitHub Releases | Free | A zip | Minutes | No |

**Steam Playtest is the right answer**, and it is not a close call. It is the
feature Valve built for this exact case: a separate, free app linked to your
store page, with a "Request Access" button, which you can set to grant
automatically or approve by hand. Testers get it in their library like any other
game — which means the Steam overlay, cloud saves later, and, importantly, it
installs on a Steam Deck the same way everything else does.

A **demo** is a marketing artefact: public, ungated, and reviewed as something
you are advertising. A **password-protected beta branch** requires testers to
own the app, which for an unreleased free game means handing out Steam keys —
more admin than the thing it replaces.

### Why not just itch.io?

It is genuinely good and costs nothing. What it does not give you is the Steam
Deck. A Deck user installing from itch is dropping to desktop mode, downloading
a zip, chmod-ing a binary and adding a non-Steam shortcut. If Deck support is
part of the ask — and it is — Steam is the route.

**Use both.** itch.io works today and Steam does not: the $100 has to clear, the
store page needs review, and the playtest app needs its own approval. Point
early testers at itch or a GitHub Release while that happens.

### Why GitHub Actions rather than anything else

It is already in use here, which settles it. On the merits it is also fine: the
build is a single Godot invocation, the artefacts are ~100 MB, and the only
awkward part — Steam's authentication — is awkward everywhere.

The one thing to know: **export templates are a 1.2 GB download**, so the cache
is not an optimisation, it is the difference between a 4-minute build and a
15-minute one.

---

## Part 2 — Platforms

### What is actually being built

Two binaries, both x86_64:

| Target | Binary | Covers |
|---|---|---|
| Linux | `survival-poc.x86_64` | Desktop Linux, **Steam Deck**, **Steam Machine** |
| Windows | `survival-poc.exe` | Desktop Windows |

**Steam Deck and Steam Machine both run SteamOS**, which is Arch-based Linux on
x86_64. They are not separate build targets. One native Linux build serves all
three, and Steam will also run the Windows build under Proton if the Linux one
is ever missing.

### The gotcha that will bite

**The executable bit.** Steam preserves the permissions the depot is uploaded
with. Two ways to lose it:

- Uploading a Linux depot from a **Windows** runner. NTFS has no executable bit,
  so the file arrives without one and the game installs perfectly and then does
  nothing at all when launched.
- Passing the build through `actions/upload-artifact` / `download-artifact`,
  which **does not preserve permissions**.

Both are handled — `build.sh` sets it, and the Steam job re-sets it after the
download — but if you ever restructure the pipeline, this is the thing that
breaks silently.

### Steam Deck: what is done and what is not

Building for it and being good on it are different questions.

**Works now:** it is a native Linux x86_64 build, so it installs and runs.
Rendering is Forward+ with Vulkan, which the Deck's RDNA 2 GPU supports.

**Not done, and needed before Deck Verified is worth submitting for:**

- **No controller support at all.** Every input is keyboard or mouse. This is
  the single biggest gap: the Deck's own controls will do nothing, and a player
  has to bring a keyboard or configure Steam Input by hand. `InputSource` is
  the right seam to add it at — see `CLAUDE.md`.
- **The interface is tuned for 1080p.** The Deck is 1280×800. `canvas_items`
  stretch scales it, but `UI.md`'s 12 px caption text becomes small on a
  7-inch screen. Valve's Deck guidance wants text legible at that size.
- **No default resolution or graphics preset for the Deck.**

Expect **Playable**, not **Verified**, and that is fine for a playtest — Verified
is a store-page badge, not a requirement to install.

---

## Part 3 — Manual steps

None of this can be automated. Do it in order; several steps gate the next.

### 3.1 Steamworks account and the fee

1. Sign up at <https://partner.steamgames.com/>. Individual or company — an
   individual account needs your legal name and tax details.
2. Complete the **tax interview** and banking details. Valve will not let an app
   go live without them, even a free one.
3. **Pay the $100 Steam Direct fee** for the app. This creates the base
   `AppID`.
4. Wait for the account to clear. Historically this includes a ~30-day hold
   before you can release, and a bank verification step. **Start this first** —
   it is the longest pole by a wide margin.

### 3.2 Create the app and the playtest

1. In Steamworks, note the base **App ID**.
2. Set up the **store page** far enough to submit: name, short description,
   at least one screenshot, a capsule image. It does not have to be good; it
   has to exist, because the Playtest's "Request Access" button lives on it.
3. **Technology → Steam Playtest** on the base app. Enabling it creates a
   *second* app, with its **own App ID and its own depots**. This is the one CI
   uploads to.
4. Choose access: **automatic** (anyone who requests gets in immediately) or
   **manual** (you approve). Automatic is almost always what you want for a
   playtest; manual is for a closed alpha.
5. Submit both apps for review. Days, not hours.

> The single most common mistake: uploading builds to the **base app** rather
> than the **playtest app**. They are different App IDs and testers only own the
> playtest one.

### 3.3 Create the depots

On the **playtest** app, under **SteamPipe → Depots**:

1. Create a depot for Linux. Note its ID. Set its OS to Linux.
2. Create a depot for Windows. Note its ID. Set its OS to Windows.
3. Under **Installation → General**, add a launch option per OS:

   | OS | Executable | Arguments |
   |---|---|---|
   | Linux | `survival-poc.x86_64` | |
   | Windows | `survival-poc.exe` | |

4. Under **Builds**, create a beta branch called `playtest`. The workflow sets
   builds live on it.

Put the three ids into `steam/app_build.vdf`, `steam/depot_linux.vdf` and
`steam/depot_windows.vdf`, replacing the `0` placeholders.

### 3.4 The builder account, and the credential problem

This is the fiddly part, and it is fiddly for everyone.

`steamcmd` requires Steam Guard two-factor authentication, and Steamworks will
not let a publishing account turn it off. CI cannot answer a 2FA prompt. The
way through is to authenticate **once, on a real machine**, and hand CI the
resulting session file.

1. In Steamworks, **Users & Permissions → create a separate builder account**.
   Do not use your own. Give it only:
   - *Edit App Metadata* and *Publish* — **on the playtest app only**.
   Nothing else. If the credential leaks, the blast radius is one playtest.
2. Log into that account once in the Steam client so Steam Guard is set up. Use
   the **mobile authenticator**, not email — email codes expire and cannot be
   re-used for a session file.
3. On your own machine, install `steamcmd` and log in once:

   ```bash
   steamcmd +login <builder_account> +quit
   ```

   Enter the Steam Guard code when prompted. This writes a session into
   `config.vdf`.

4. Find `config.vdf` and base64 it:

   ```bash
   # Linux
   base64 -w 0 ~/.steam/steam/config/config.vdf
   # macOS
   base64 -i ~/Library/Application\ Support/Steam/config/config.vdf
   # Windows
   certutil -encode "C:\Program Files (x86)\Steam\config\config.vdf" out.txt
   ```

5. Add these **repository secrets** in GitHub
   (*Settings → Secrets and variables → Actions*):

   | Secret | Value |
   |---|---|
   | `STEAM_USERNAME` | the builder account name |
   | `STEAM_CONFIG_VDF` | the base64 string from step 4 |
   | `STEAM_APP_ID` | the **playtest** App ID, not the base one |

**This session expires.** Changing the account password, or Steam deciding the
session is stale, invalidates it — and the failure looks like a login error in
CI weeks after anyone touched it. When that happens, repeat steps 3–5. Put a
note somewhere you will see it.

### 3.5 First upload

Do the first one **by hand**, so that when CI fails you know whether it is CI:

```bash
steamcmd +login <builder_account> +run_app_build /absolute/path/to/steam/app_build.vdf +quit
```

`SetLive` is empty in `app_build.vdf` on purpose, so this uploads without
changing what testers see. Check it in Steamworks under **Builds**, then set it
live on `playtest` from the web UI.

Only once that has worked should you let the workflow do it.

---

## Part 4 — The pipeline

### What runs when

| Trigger | Tests | Build | GitHub release | Steam |
|---|---|---|---|---|
| push to `main` | yes | no | no | no |
| pull request | yes | no | no | no |
| tag `v*` | yes | yes | yes | yes → `playtest` |
| manual run | yes | yes | no | only if you tick the box |

Steam upload is opt-in on manual runs. A pipeline that pushes to a live branch
on every button press is one nobody dares press.

### Cutting a build for testers

```bash
git tag v0.3.0
git push origin v0.3.0
```

That runs the suite, builds both platforms, attaches zips to a GitHub release,
and sets the Steam build live on `playtest`.

### Building locally

```bash
./build.sh                 # both platforms, release
./build.sh linux --debug   # one platform, debug templates
```

CI is a thin wrapper around this script on purpose. A pipeline whose only home
is a YAML file is a pipeline you debug by pushing commits.

Export templates must be installed to match `.godot-version`:

```
~/.local/share/godot/export_templates/4.7.1.stable/
```

`build.sh` tells you the download URL if they are missing.

### Versioning

Tags are `vMAJOR.MINOR.PATCH`. Steam does not care — it numbers its own builds —
but the tag becomes the build description in Steamworks, which is what you read
when working out which build a tester is complaining about.

---

## What is deliberately not here

- **No code signing.** Unsigned Windows builds trip SmartScreen ("Windows
  protected your PC"). A certificate is ~$200–400/year and only worth it once
  there is something to protect. Steam-delivered builds are less affected than
  a downloaded zip, because Steam is the trusted installer.
- **No macOS.** It needs an Apple Developer account ($99/year) for notarisation,
  and an unnotarised Mac build is worse than none — Gatekeeper refuses it
  outright.
- **No dedicated server build.** `MULTIPLAYER.md` describes a Rust server as the
  eventual answer; shipping a Godot headless server before that decision is made
  would be a thing to maintain and then throw away.
- **No automatic rollback.** Steam keeps every build and setting an old one live
  is two clicks in the web UI, which is faster and safer than automating it.
- **No Steam Deck Verified submission.** See Part 2 — the controller gap has to
  close first.
