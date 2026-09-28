# Amelia live authoring feasibility probe

Historical probe report. Sources now live at the repository root; use the root README and `tools/dev.ps1` for current commands. The authoring stack was subsequently accepted; current decisions are in `../03_Updated_GDD.md`. The instructions below describe the original probe export.

Tested 28 September 2026 with Godot 4.7.2-stable and Dialogue Manager 4.1.0.

## Result

**17/17 automated checks passed in both the exported Windows executable and the exported Web build running in headless Chrome.** The browser screenshot was also inspected for readable layout. The same GDScript runtime compiles edited dialogue source on both targets, with no external compiler service.

This establishes feasibility for an integrated scene-script editor. It is not the first playable or a complete character/storylet authoring system.

## Try it

On Windows, launch `build/windows/AmeliaProbe.exe`.

1. Click **Stop steam**, then **Next scene line** twice. The second line executes the script command delaying Guest to Hour 5.
2. Change `delay_guest(1)` to `delay_guest(2)` in the text editor and click **Validate & apply edited script**.
3. Click **Reset loop**, **Stop steam**, and advance through the scene again. Guest is now delayed to Hour 6.
4. Use **Save** and **Reload** to restore the script, world and conversation cursor.

For web, serve `build/web` with a local HTTP server and open `index.html` through localhost. Opening it as a file URL is insufficient. For example, from a terminal with Python installed: `python -m http.server 8000 --directory build/web`, then visit http://localhost:8000 .

Source project: open `project.godot` in Godot 4.7.2. Export presets currently reference the downloaded templates in this workspace's `work/runtime/templates` directory; adjust these paths if moving the project.

## What was checked

The automated checks cover runtime source compilation; a rescue prerequisite; actor state changes; multiple speakers; a script command mutating the world; save/restore before and after a command; avoiding duplicate execution of completed commands; applying changed text and command arguments; rejecting malformed source while retaining the working script; and resetting world state while retaining knowledge and edited content. JSON evidence is in `evidence/`.

Native export was tested headlessly with a workspace save-path override. Web ran in headless Chrome with software rendering and used Godot's `user://` file API. Save/reload was verified within a running process/page. Persistence across a fresh browser session, storage eviction, other browsers, native graphical interaction and controller input were not tested.

## Boundaries and next implementation work

- Applying a valid edit restarts the scene cursor while retaining world state. This can repeat scene commands if the author runs the scene again; it is not seamless migration of an active conversation.
- Saves happen at line boundaries, outside active command execution. Exact continuous autosave, interrupted actions, waits and rewind history remain to implement.
- The two characters and two drawn areas are a small test harness. Maps and character schedules are not editable in this probe.
- Compilation catches syntax errors. Authoring validation for missing actors, command names/arguments, timing conflicts and map references remains necessary.
- Dialogue Manager supplies dialogue, conditions and mutations. A deterministic game layer must own hourly schedules, eligible storylets, actor availability, priorities, knowledge and loop state. The authoring editor should expose these alongside scripts.

Recommendation: use **Dialogue Manager for scene scripts**, **structured data for characters/maps/storylet metadata**, and **GDScript for the simulation and command API**. Adoption is a recommendation following this test, not a newly recorded user decision.

## Dependencies

- [Godot 4.7.2](https://github.com/godotengine/godot/releases/tag/4.7.2-stable), MIT; [license and third-party notices](https://godotengine.org/license/).
- [Dialogue Manager 4.1.0](https://github.com/nathanhoad/godot_dialogue_manager/releases/tag/v4.1.0), MIT; bundled license at `addons/dialogue_manager/LICENSE`.

Test harness source is `main.gd`; all 17 checks are in `_run_tests`. Add `?probe_test` to the web URL to run them, or use `-- --probe-test --save-path=<absolute file> --report=<absolute file>` with the native executable.
