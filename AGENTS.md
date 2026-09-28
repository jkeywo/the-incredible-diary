# Working on The Incredible Diary

This is an independent Godot/GDScript project, not a member of the neighbouring Vellum fleet.

- `docs/03_Updated_GDD.md` is the current design authority. Research/transcripts are historical context; later explicit user decisions take precedence.
- Target Windows PC and web. Keep the shared runtime compatible with the web export; no C# or native-only dependency without revisiting the target constraints.
- `main.gd` currently implements only the authoring feasibility probe. Do not describe it as the full editor or Mission 1.
- Keep `.tools`, `.godot`, `build`, credentials and personal save data out of Git.
- Use `tools/dev.ps1 Test`, `ExportWeb` and `ExportWindows` for proportionate checks. The test command verifies the probe, not unimplemented gameplay requirements.
- Simulation saves must eventually include current-leg history. Scrubbing displays recorded history, never inferred outcomes from later edits.
- GitHub Actions deploys pushes to `main` to Pages. Pull requests build without deployment.
