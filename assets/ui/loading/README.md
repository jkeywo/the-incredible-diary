# Diary loading screen

The Web export uses `shell.html`: a navy and brass frame, a half-closed diary
with a V-shaped lower edge, and three rapidly riffling parchment leaves.
The Godot icon stays in the bottom-right corner. Download progress comes from
Godot's actual byte counts; engine startup displays “Opening the diary…”.
Reduced-motion preferences suppress the moving leaves. Startup failures remain
visible in the screen, including a failure to download the engine script.

`diary-source.png` is generated artwork. `diary.png` is its smaller loading
texture; the two book halves are posed and animated in CSS. `godot-icon.png`
is the Godot mark cropped from the stock Godot export splash (`godot-splash.png`).
Godot branding belongs to the Godot project.

Edit `shell.template.html` and `loading.css`, then run
`python tools/build_loading_screen.py` and commit the resulting `shell.html`.
Its images and styling are embedded, so local and GitHub Actions exports use
the same loader without extra copy steps or third-party requests.
The startup JavaScript preserves the pinned Godot template's feature checks
and service-worker handling.

`boot-splash.png` is the matching static engine splash, including the corner
Godot credit. Godot's pre-runtime splash cannot animate; the native loading scene takes over with animated pages once the runtime starts.
It loads the title resources on a background thread, using the same diary art
and page motion as the Web loader. The Web page supplies its animation during
download/startup.
