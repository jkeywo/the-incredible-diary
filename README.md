# The Incredible Diary of Lady Amelia Ashcombe

Godot 4 / GDScript game and integrated authoring editor for Windows PC and web.

**Current build:** a two-room simulation foundation harness. It is not Mission 1 or the completed editor. See [the design](docs/03_Updated_GDD.md), [foundation demonstration](docs/foundation/README.md), and [earlier probe results](docs/authoring-probe/README.md).

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

Python 3 is needed only for tool installation and a convenient local HTTP server. This checkout is already provisioned with local tools. Runtime binaries, templates, imported caches, saves and exports are ignored by Git. The first clean installation downloads the official export-template archive, which is large.

Open `project.godot` to edit. The Windows executable exports to `build/windows/Amelia.exe`. To preview the browser build, run `python -m http.server 8000 --directory build/web` and visit http://localhost:8000 . Use HTTP rather than opening the HTML file directly.

## Builds and GitHub Pages

`.github/workflows/build.yml` imports the project, runs probe and foundation checks plus a full simulated-leg benchmark, and exports Windows and web on pull requests and pushes to `main`. Pushes to `main` then deploy the web build to https://jkeywo.github.io/the-incredible-diary/ . Windows exports are downloadable as the `amelia-windows` workflow artifact. Manual runs are also supported; only `main` deploys.

The web export uses Compatibility rendering and no threads, so it does not depend on cross-origin isolation headers unavailable on ordinary GitHub Pages hosting. No repository credentials are embedded in the game. GitHub Pages serves the static game; the planned in-game GitHub authoring integration/authentication is separate and not yet implemented.

## Save/history requirement

The foundation harness now records and journals its full current leg, including historical diagnostics. The earlier probe's small snapshot save remains separate. See the GDD and foundation demonstration for current scope and limitations.

## Design records

- [Original research, unabridged](docs/01_Original_Research.md)
- [Recovered grilling transcript, unabridged through its recorded cutoff](docs/02_Full_Grilling_Session.md)
- [Current GDD and readiness review](docs/03_Updated_GDD.md)

The GDD includes decisions made after the historical transcript export. Make subsequent design updates in this repository's GDD.
