# Mission 1 stateful props

The `*.tscn` files are ready to instance under a room's `Entities` node.
Each uses `stateful_prop.gd`, with a bottom-centre placement origin. Call
`set_state("name")` to change its visible state; the method returns `false` for
an unknown name. Each `*_states.png` is a one-row transparent sprite sheet.

| Scene | States from left to right | Cell |
| --- | --- | --- |
| `cabin_door.tscn` | `closed`, `open` | 96 × 104 |
| `service_door.tscn` | `closed`, `open` | 80 × 128 |
| `suitcase.tscn` | `present`, `hidden` | 56 × 48 |
| `bag_hiding.tscn` | `empty`, `occupied` | 112 × 88 |
| `code_panel.tscn` | `standby`, `entry`, `accepted`, `rejected` | 80 × 72 |
| `drink.tscn` | `full`, `spiked`, `spilled`, `empty` | 56 × 48 |
| `chandelier.tscn` | `intact`, `warning`, `fallen` | 144 × 144 |
| `steam_vent.tscn` | `active`, `off` | 160 × 144 |
| `valve.tscn` | `open`, `closed` | 32 × 48 |

The `full` and `spiked` drink frames are deliberately identical. The game must
track poison separately and reveal it through witnessing or inspection. The
`hidden` suitcase frame is transparent; switch the hiding place to `occupied`
at the same time. Cabin door sprites are sized for the narrow empty thresholds
in the cabin screen. The upright service door can be used for the controls and
steam room exit. The code panel has blank display windows so the current
three-digit code can be drawn by UI instead of baked into art.

The `steam_vent.tscn` scene now loops a separate steam plume when its state is
`active`; switching to `off` hides it. `chandelier.tscn` exposes
`show_at(warning, progress, impact_seconds, time)` to sample its accelerating
150-pixel drop and impact dust from recorded simulation time. Its origin is
the shared floor position at the centre of the foyer. Negative progress means
hanging; negative impact time means it has not landed.
`drink.tscn` exposes `play_spiking()` for the identity-hidden hand and vial;
the visual becomes `spiked` only when that clip finishes. `play_spill()` switches
to `spilled` and plays the short splash. Direct `set_state()` remains available
when showing recorded history without replaying the effects.

The scenes supply visual state changes and brief effects, not completed
interactions or collisions. Steam and chandelier event timing, path blocking,
bag movement and inspection logic belong to room and simulation authoring.
Prop placement in the five rooms remains to be finalized.

`prop_preview.png` shows the game-scale states at 2×. The larger generated
source images are retained in `source/`. Use
`tools/build_mission1_props.py` with Pillow to rebuild the sheets after editing
sources. The script crops, scales and aligns the generated state art; it does
not draw new content.
