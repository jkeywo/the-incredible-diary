# Resource loading

The initial web pack contains the title, Settings, docks scene/audio, and small resource metadata/scripts. Imported art and audio outside that set are exported as individual PCKs. The engine is still required at startup. The September 2026 build has a roughly 7.4 MB initial pack and a 39.5 MB engine, before HTTP compression.

## Runtime

- `ResourceStream` owns the resource cache across scene changes. Web requests fetch up to four asset packs concurrently. Active travel takes priority over background preparation.
- The title prepares the saved destination, or the initial docks state for New. Confirming New selects the docks without waiting for an unrelated saved room. The previous save is cleared only once the selected destination is ready.
- `mission1/content_plan.gd` lists dynamic paths: room props, character sheets and adjacent rooms. Static scene and `preload` dependencies come from the exporter. Formatted `load` paths must be included in a mission's content plan.
- Gameplay creates characters only when they are visible. Room changes and character arrivals wait for their required resources; simulation and rewind do not advance during that wait. Neighbour prefetch changes with the current room. Requests that have already started may finish after a destination changes.
- PC uses background resource reads from installed files. Web mounts validated asset packs in temporary memory and then prepares resources through the same loader. Saves remain separate.
- The full-size animated diary covers a foreground wait. Continue/New then uses the existing opening transition. Errors preserve the voyage and offer retry or return to the menu.

## Reuse between missions

Pack filenames contain a SHA-256 digest. The browser caches validated bytes in `diary-assets-v1` using Cache Storage. Reusing an existing resource path in another mission uses the same pack URL; it does not create a mission-specific copy. Scene changes also reuse mounted packs and loaded resources. Changed assets get new filenames. A future mission needs its own dynamic content plan, but uses this same cache.

Browser storage may be unavailable or evicted. Loading falls back to the network if storage is blocked, and corrupt cached bytes are discarded and fetched again. The cache contains game assets, never journals or preferences. Use HTTPS or localhost for web hosting.

## Export and checks

`tools/dev.ps1 ExportWeb` calls `tools/export_web.py`, which performs normal Godot exports, splits the exported imported resources with Godot's PCKPacker, embeds the dependency manifest and copies the browser cache helper. It updates the initial loading bar's byte count. The export then validates the title and every room/character dependency from an isolated bootstrap pack. Inspect `build/web-content-manifest.json` and `build/exported-content-test.log` when changing resource paths. Deploy all files in `build/web` together.

`tools/dev.ps1 Test` covers foreground waits, early clicks, preserved saves on failure, retry, room and character loading, recorded history, menu audio handoff, and browser-cache behavior. The browser cache tests cover duplicate requests, fresh-page reuse, integrity failures, corrupt cached data, blocked storage and retry. `ExportWindows` builds the shared native flow.

The local browser check used a fresh headless Chromium context, slowed asset responses, selected New before preparation finished, inspected the diary and docks, then reloaded and continued the saved voyage. It checks that salon and offscreen character art were not requested from the docks and that already fetched assets require no repeat transfer.
