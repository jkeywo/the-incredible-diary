# Local setup verification — 28 September 2026

- Cloned `jkeywo/the-incredible-diary` into `C:/coding/the-incredible-diary`, branch `main`.
- Provisioned ignored local Godot 4.7.2 binaries and Windows/web templates.
- `tools/dev.ps1 Test`: 17/17 probe checks passed.
- `tools/dev.ps1 ExportWeb`: successful export to `build/web`.
- `tools/dev.ps1 ExportWindows`: successful export to `build/windows/Amelia.exe`.
- `tools/setup-godot.py`: successfully recognized the local installation.
- `actionlint .github/workflows/build.yml`: passed.
- GitHub Pages configured with `build_type=workflow` and HTTPS enabled.

Setup changes are local and have not been committed or pushed. The Linux Actions job and hosted Pages deployment have not run yet. Fresh tool downloads on Linux have not been exercised locally. Export success and the probe checks do not establish full Mission 1, editor or simulation-history functionality.
