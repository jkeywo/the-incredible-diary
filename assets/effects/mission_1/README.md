# Mission 1 visual effects

Four transparent, four-frame Godot effect scenes are ready to instance:

| Scene | Use | Playback |
| --- | --- | --- |
| `steam_plume.tscn` | Moving steam above the active vent | Loop until stopped |
| `chandelier_dust.tscn` | Chandelier impact cloud | One shot, then hidden |
| `drink_splash.tscn` | Drink knock and floor splash | One shot, then hidden |
| `obscured_spiking.tscn` | Anonymous hand and vial above the drink | One shot, then hidden |

Each uses `sprite_strip_effect.gd` and supports `play_effect()` and
`stop_effect()`. The first three are already children of their matching prop
scenes; the spiking hand is a child of `drink.tscn`. The character art additions
are the rake's stained movement sheet and matron's held steam casualty clip.

The generated large pose sheets are retained in `source/` and
`assets/characters/actions/source/`. Run
`tools/build_mission1_character_effects.py` with Pillow to rebuild the
game-scale strips and `character_effect_preview.png`.
