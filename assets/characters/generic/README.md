# Generic Mission 1 NPCs

Five recolourable characters, alongside the four existing guest archetypes in
`assets/characters/`. Each has four-direction idle, walk, talk and interaction
bob cycles for first playable use.

| ID | Role | Recolourable garment |
| --- | --- | --- |
| `sailor` | Male deckhand for the steam room and baggage area | None; skin only |
| `guest_male_jacket` | Male guest | Teal jacket |
| `guest_male_waistcoat` | Male guest | Orange waistcoat |
| `guest_female_dress` | Female guest | Blue dress |
| `guest_female_coat` | Female guest | Violet coat |

Place `generic_animated_character.tscn` at the actor's feet, select the
`character_id` and `initial_direction`, then enable `recolor_skin` and/or
`recolor_garment` and set their colours. Call `play_action(action, direction)`
for `idle`, `walk`, `talk` or `bob`. The animated `_sprites.png` and
`_sprites_mask.png` sheets are **416 × 192**, with **32 × 48** cells: rows are
down, left, up, right; columns are idle (2), walk (4), talk (3), bob (4).
The older `generic_character.tscn` and 128 × 48 static sheets remain usable.
The sailor exposes skin recolouring;
the other four expose both. Each paired `_mask.png` uses **red for skin** and
**green for the chosen garment**. `recolor.gdshader` retains the base art's
light/dark shading while changing those regions. See `palette_preview.png`:
each row shows the default four directions on the left and one recoloured
example on the right.

The sailor also has Mission 1 clips `handle_baggage`, `demonstrate`,
`restore_steam` and `raise_alarm` from `../actions/`. The large four-facing
imagegen originals are retained in `source/`. Run
`tools/build_generic_characters.py` with the bundled Pillow Python runtime to
regenerate the small sheets, masks and preview, then run
`tools/build_mission1_action_sprites.py` to regenerate the sailor action strip.
The scripts fit the source art to the established character cell size and
classify the two colour regions.

The built-in imagegen prompt set used the existing rake, ex-army, glamorous,
matron and Amelia art as **style references**, asking for one consistent person
in four full-body directions on transparent background, with crisp chunky
1920s pixel art and a clean colour distinction between warm skin and a single
guest garment. The subjects were a navy-and-cream striped deckhand, teal-jacket
man, orange-waistcoat man, blue-dress woman and violet-coat woman. The actual
four-view source images are the art authority for the movement cycles.
