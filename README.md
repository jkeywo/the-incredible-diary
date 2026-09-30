# The Incredible Diary of Lady Amelia Ashcombe

Godot 4 / GDScript game and integrated authoring editor for Windows PC and web.

**Current build:** the diary title screen opens Mission 1, including its dock
tutorial and six-Hour rescue simulation. The menu's Test Level button opens the
separate two-room authoring foundation harness. See [the design](docs/03_Updated_GDD.md),
[Mission 1](mission1/README.md), [foundation demonstration](docs/foundation/README.md),
and [earlier probe results](docs/authoring-probe/README.md).

## Windows development

The local checkout is `C:\coding\the-incredible-diary`. Godot is pinned in `.godot-version`; Dialogue Manager 4.1.0 is vendored under `addons/` with its license.

```powershell
python tools/setup-godot.py
./tools/dev.ps1 Editor
./tools/dev.ps1 Run
./tools/dev.ps1 Test
./tools/dev.ps1 ExportWeb
./tools/dev.ps1 ExportWindows
```

Python 3 is needed for tool installation, web packaging and a convenient local HTTP server. `ExportWeb -Python <path-to-python>` supports a Python executable outside PATH. The test command also uses Node.js for browser cache and loading-handoff checks. This checkout is already provisioned with local tools. Runtime binaries, templates, imported caches, saves and exports are ignored by Git. The first clean installation downloads the official export-template archive, which is large.

Open `project.godot` to edit. The Windows executable exports to `build/windows/Amelia.exe`. To preview the browser build, run `python -m http.server 8000 --directory build/web` and visit http://localhost:8000 . Use HTTP rather than opening the HTML file directly.

Automated Test/Export runs use `build/godot-profile` for Windows AppData, so their settings, caches and logs are writable without touching personal saves. Editor/Run retain your normal profile. If a restricted agent run reports `Failed to read the root certificate store`, run the same command in a normal PowerShell terminal; the isolated profile cannot grant access to Windows certificates. Keep TLS verification enabled.

Tests fail on shutdown resource-leak messages as well as assertion failures. Each Godot test prints its name before running and saves its output under `build/test-logs`. Native stderr is captured as text on both Windows PowerShell 5.1 and PowerShell 7, so failures identify the test and log path. Audio/UI tests use `tests/shutdown.gd` to release scenes and allow a mixer update before exiting.

On Windows, double-click `build-and-run.bat` to export the native game and launch it. Close an existing `Amelia.exe` session before rebuilding, because Windows locks the running executable. If the pinned Godot tools are missing, the batch file installs them first; that initial setup requires Python 3. Command-line arguments passed to the batch file are forwarded to the game.

## Builds and GitHub Pages

`.github/workflows/build.yml` imports the project, runs probe and foundation checks plus a full simulated-leg benchmark, and exports Windows and web on pull requests and pushes to `main`. Pushes to `main` then deploy the web build to https://jkeywo.github.io/the-incredible-diary/ . Windows exports are downloadable as the `amelia-windows` workflow artifact. Manual runs are also supported; only `main` deploys.

The web export uses Compatibility rendering and no threads, so it does not depend on cross-origin isolation headers unavailable on ordinary GitHub Pages hosting. No repository credentials are embedded in the game. GitHub Pages serves the static game; the planned in-game GitHub authoring integration/authentication is separate and not yet implemented.

Web releases must use `tools/dev.ps1 ExportWeb` (or `python tools/export_web.py <godot>` in CI) to split the export into the title/docks pack and reusable asset packs. A direct Godot web export remains a full download. The initial title/docks pack is about 7.4 MB, plus the 39.5 MB engine before server compression. See [resource loading](docs/resource-loading.md) for prefetch, caching and checks.

## Save/history requirement

The foundation harness now records and journals its full current leg, including historical diagnostics. The earlier probe's small snapshot save remains separate. See the GDD and foundation demonstration for current scope and limitations.

The title menu's Continue and New use `mission1_v2.journal` in Godot user
data. It includes the full recorded current leg and unfinished tutorial state.
New asks before clearing it and leaves foundation/test saves untouched.

The foundation architecture refactor uses a new `foundation_run_v2.jsonl` save under Godot's user data directory. Earlier `foundation_run.jsonl` files are left untouched; this build starts a fresh foundation run.

## Design records

- [Original research, unabridged](docs/01_Original_Research.md)
- [Recovered grilling transcript, unabridged through its recorded cutoff](docs/02_Full_Grilling_Session.md)
- [Current GDD and readiness review](docs/03_Updated_GDD.md)

The GDD includes decisions made after the historical transcript export. Make subsequent design updates in this repository's GDD.
