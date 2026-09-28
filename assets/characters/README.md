# Character sprites for the two-room foundation

Five characters: the player, the upper-class rake, the glamorous upper-class passenger,
the middle-class ex-army passenger, and the matronly middle-class passenger.
These are test-bed archetypes, not named Mission 1 characters.

The two-room foundation currently maps `player` to Amelia, `matron` to Chatter
Box, and `rake` to the guest. The other two sheets remain available for later
test-bed casting.

Each transparent PNG is a **416 × 192** sprite sheet of **32 × 48** cells. Rows
are down, left, up, right. Columns are idle (2 frames), walk (4), talk (3), and
interaction bob (4), in that order. `character_sprite.tscn` loads the sheets and
exposes animations named `idle_down`, `walk_left`, `talk_up`, `bob_right`, etc.
The node origin is at the character's feet. Call `play_action(action, direction)`;
the one-shot bob returns to idle automatically.
The `mission_1/` folder contains ten ready-to-instance Godot character scenes:
Amelia, the three provisional rescue roles, ex-army guest, sailor, and four
recolourable generic guests. These scenes use the base animation scripts, so
their sprite sheets and action clips are available in the Godot editor.

Mission 1 action clips live in `actions/` and are loaded by the same scene.
Amelia has `hide_bag`, `shove`, `turn_valve` and `bump`. The provisional role
casting uses `rake` for the poisoned guest (`search_bag`, `hold_drink`,
`spill_react`, `poison_collapse`), `glamorous` for the chandelier guest
(`chandelier_warn`, `pushed`, `recover`, `chandelier_casualty`) and `matron` for
the steam guest (`steam_trapped`, `cough`, `escape`, `chatter`). Timed clips loop;
short reactions return to idle, while casualty poses hold their final frame.
Call `play_action(name, direction)` for these clips too. `ex_army` still has
the shared four-direction idle, walk, talk and bob cycles.

The `source/` PNGs retain the generated four-facing visual references, and
`walk_source/` contains the true-profile side-walk references. Run
`tools/build_character_sprites.py` with Pillow to regenerate the fixed-grid
sheets. The walk and expressive cycles are deliberately simple for the PRD #1
test bed; refine the frames before using them as polished campaign art.

## Art prompt

Created with the built-in imagegen tool, using the selected Style B player
preview as the reference. Shared prompt: “Compact readable retro pixel art,
chunky crisp pixels, limited warm Art Deco palette with ominous dark accents,
strong silhouette, 1920s Mediterranean cruise ship, three-quarter top-down
view, four consistent full-body facings (down, left, up, right), designed for
32 × 48 pixel sprites, transparent background, no scenery or labels.” Subjects:

- Player: boy-presenting junior purser in a dark navy uniform and cap.
- Rake: slim upper-class man in a cream suit and dark waistcoat.
- Glamorous passenger: upper-class woman in a plum evening dress.
- Ex-army passenger: middle-class man in brown tweed and olive tie.
- Matron: middle-class woman in a practical teal dress and cardigan.

The side-walk reference prompt kept each costume and palette but requested
strict left and right profiles with a horizontal stride and one foot leading.
