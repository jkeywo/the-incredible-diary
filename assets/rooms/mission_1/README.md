# Mission 1 room backgrounds

Five first-playable screen drafts at the current Godot viewport size of
1160 × 740 pixels. The dock screen is split into three layers. Higher-resolution
imagegen originals and the first flattened dock reference are in `masters/`.
The matching `.tscn` files are loadable Godot room backdrops with empty
`Entities` and `Effects` nodes for gameplay placement. The controls and steam
screen has separate entity nodes for its disconnected logical rooms.
Each scene also has a `RoomAudioSettings` child with editable music, ambience,
levels and fade duration. Open `res://mission1/room_audio_playtest.tscn` to
audition all five rooms; [audio sources and controls](../../audio/mission_1/README.md)
are listed with the imported files.

| File | Screen layout |
| --- | --- |
| `01_docks_water.png` | Opaque moving harbor-water layer, 1200 × 766 for movement margin. |
| `01_docks_ship.png` | Transparent moving ship layer, 1200 × 766 with more ship artwork than the visible frame needs. |
| `01_docks_pier.png` | Transparent fixed pier and boarding stairs, 1160 × 740; baggage left, guest arrival right, Amelia's start in the open centre. |
| `01_docks_preview.png` | Static composite preview of the three layers. Do not use for animation. |
| `02_foyer.png` | Entrance below, cabins left, service/steam rooms right, salon upstairs ahead. |
| `03_cabin_corridor.png` | Three spacious cabins in the upper two thirds; a continuous corridor in the lower third. Narrow empty thresholds have no baked-in door leaves so door props can be placed separately. |
| `04_controls_and_steam.png` | Controls on the left and the disconnected steam-side room on the right, both visible at once. |
| `05_party_salon.png` | Open party floor, perimeter seating and drink service area. |

For the dock, draw **water → ship → pier**. At rest, place the water at
`(-20, -13)`, the ship at `(-20, -90)`, and the pier at `(0, 0)`, relative to the
1160 × 740 screen. The preview uses exactly these offsets. The water and ship
can each move by up to 8 pixels in either axis while their image canvases still
cover the screen. Keep the pier and stairs fixed. This is a suggested visual
range; tune motion speed and phase in engine.

`01_docks.tscn` uses `docks.gd` to bob the ship and water independently within
that range. `PierAndStairs` stays fixed, so boarding geometry and character
positions do not bob. Set `animate_bobbing = false` to pause cosmetic motion;
call `set_motion_time(seconds)` to show a chosen visual phase while scrubbing
or replaying recorded time. The scene origin is the top-left of the fixed
1160 × 740 screen.

These are backgrounds, not complete room implementations. Walkable polygons,
connections, interaction positions, the steam hazard, chandelier states and
other changing props should be authored separately. The pictured control
machinery and salon furniture are scenic; their gameplay hotspots need explicit
positions and state handling. The five screens depict six logical rooms because
the controls and steam-side rooms share one screen.

Generated with the built-in imagegen tool using the existing Amelia sprite as a
style reference. Shared prompt direction: full-screen 1920s Mediterranean cruise
ship pixel-art game background; consistent three-quarter top-down camera;
chunky readable pixels; navy, teal, cream and brass Art Deco palette; generous
open floor for 32 × 48 character sprites; no characters, UI or text. Individual
compositions followed the five layouts in the table above. The original dock
image was also used as a style reference for the other four screens. The cabin
revision enlarged the three interiors to the upper two thirds of the screen,
narrowed their entrances, and removed all door leaves. Dock
extraction prompts isolated the fixed pier/stairs and moving ship with genuine
alpha, then generated a water-only back layer and extended the ship artwork for
bobbing clearance.
