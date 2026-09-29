# Mission 1 character action clips

These are first-playable 32 × 48 transparent sprite frames. Each action PNG
contains four horizontal frames per named action. `character_sprite.gd` loads
Amelia and the three provisional guest roles; the recolourable sailor is loaded
by `generic/generic_animated_character.gd` with its matching skin mask.

| Character | Clips, from left to right |
| --- | --- |
| Amelia | `hide_bag`, `shove`, `turn_valve`, `bump` |
| Sailor | `handle_baggage`, `demonstrate`, `restore_steam`, `raise_alarm` |
| Rake (poisoned guest) | `search_bag`, `hold_drink`, `spill_react`, `poison_collapse` |
| Glamorous (chandelier guest) | `chandelier_warn`, `pushed`, `recover`, `chandelier_casualty` |
| Matron (steam guest) | `steam_trapped`, `cough`, `escape`, `chatter` |

The matron also has the separate `steam_casualty` clip. It plays once and holds
the last prone frame. The rake has a separate four-facing
`rake_stained_sprites.png` sheet for idle, walk, talk and bob after the drink
spills. Call `set_outfit_stained(true)` on the poisoned guest scene after the
spill; this keeps the stain visible during their walk to change clothes.
The anonymous spiking hand is an effect scene inside the drink prop, not a
named character sprite.

The role casting is provisional. The action strips stay separate from the
shared four-facing movement sheets so they can be reassigned. The generated
`source/` PNGs contain the large key poses. Run
`tools/build_mission1_action_sprites.py` using the bundled Pillow Python to
rebuild the gameplay strips. The preview shows each four-frame action at 4×.
Run `tools/build_mission1_character_effects.py` to rebuild the stained sheet,
steam casualty strip and visual effects from their generated sources.

Actions are single key-pose animations with small motion for scene blocking.
They do not yet include prop interactions or visual effects; baggage, drink,
valve and steam belong in separate scene layers.
