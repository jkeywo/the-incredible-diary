# Mission 1 first-playable audio shortlist

Checked 29 September 2026 against the linked asset pages. The original
OpenGameArt selections are **CC0** except for the new salon alternative noted
below. [CC0 permits copying, editing and commercial use without permission](https://creativecommons.org/publicdomain/zero/1.0/).
The Kevin MacLeod alternatives are free under **CC BY 4.0**, which requires
credit. The selected room beds are now imported; see
[`assets/audio/mission_1/README.md`](../assets/audio/mission_1/README.md)
for filenames and playtest instructions. Event SFX remain recommendations.

## Music and room ambience

| Place | Candidate and creator | First-playable use |
| --- | --- | --- |
| Docks | [Water Waves](https://opengameart.org/content/water-waves), transitking | Randomize the four short wave recordings at low level under the pier scene. They are short effects, so avoid hard looping one sample. |
| Docks, faint layer | [Steamboat Engine Sound](https://opengameart.org/content/steamboat-engine-sound), Spring Spring | A low engine pulse near the boarding stairs. Keep below the waves and dialogue. |
| Foyer and cabins | [Piano Swap Rpg](https://opengameart.org/content/piano-swap-rpg), Tozan | Slow, lightly swaying piano as the main quiet ship music. Fade between repeats if its ends do not loop cleanly. |
| Party salon | [Catchy Swing](https://opengameart.org/content/catchy-swing), Doge | Loopable saxophone, bass and drum swing for the party. Lower it during dialogue and the chandelier warning. |
| Controls and steam side | [Steam boiler sound loop](https://opengameart.org/content/steam-boiler-sound-loop), bart | Continuous low machinery hum; keep it quieter on the controls half of the screen. |
| Steam hazard | [Steam release sounds](https://opengameart.org/content/steam-release-sounds), bart | Irregular hiss bursts over the boiler bed. Stop or taper them when Amelia shuts off the steam. |

### Party salon alternatives to audition

| Track and creator | License | Why it might fit |
| --- | --- | --- |
| [Hot Swing](https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1100202), Kevin MacLeod | CC BY 4.0 | Bright 144 BPM ensemble with saxes, clarinet, trumpet and trombone. Strongest candidate for an energetic party, but only 50 seconds long, so its ending needs a loop edit or crossfade. |
| [Jazz Lost in Time](https://opengameart.org/content/jazz), Spring Spring | CC BY 4.0 (one of the licenses offered on the page) | Brass and sax swing with an intentionally old-record sound; the most period-flavoured option. Audition the drum break before choosing a loop point. |
| [George Street Shuffle](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300035), Kevin MacLeod | CC BY 4.0 | Bouncy 153 BPM jazz with vibes, bass, piano and drums. At 4:28, it can play as a longer, lighter room bed, though it has less big-band punch. |

Hot Swing and George Street Shuffle are the selected salon playtest tracks.
Hot Swing is the room default; press **G** in the standalone room/audio playtest
to compare them at the same elapsed game time.

The piano and salon tracks are modern recordings with a period-flavoured feel;
they are first-playable placeholders rather than historically authenticated
1920s recordings. The links verify licensing and descriptions; final taste,
loop edits and balance still need an in-game audition. If a CC BY track is
used, add its title, creator, source URL, license and any edit to the game
credits.

## Event sounds

| Use | Candidate and creator |
| --- | --- |
| Footsteps, doors, bag handling, switches, small glass and metal sounds | [100 CC0 SFX #2](https://opengameart.org/content/100-cc0-sfx-2), rubberduck. The pack page lists these categories. Select individual sounds rather than adding the whole pack to the game. |
| Control hardware, cabin doors and chandelier impact | [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx), rubberduck. Its metal falling/slam and door sounds cover several cues. |
| Chandelier warning | [Tree Creaking](https://opengameart.org/content/tree-creaking), Department64 / AntumDeluge. Trim a subtle creak; audition it against the visual shake. |
| Chandelier aftermath | [Glass Break](https://opengameart.org/content/glass-break), Till Behrend. Layer briefly with a metal fall/impact from the pack above. |
| Drink spill | A small water splash or glass/item sound from the packs above, pitched and mixed quietly. The glass need not break in the intended rescue. |
| Steam guest cough | [Sound Effects Pack](https://opengameart.org/content/sound-effects-pack), OwlishMedia. It includes human coughing; extract only the chosen clip from the large archive. |

For first playable, the selected packs should also cover keypad clicks,
accept/reject cues, a shove, baggage and most doors. The crew alarm can be an
authored line of dialogue. A suitable **quiet salon crowd murmur** remains
optional; avoid a shouting crowd recording because it would make the party
sound like a protest.

## Integration notes

- Keep music, ambience and event sounds on separate Godot buses so dialogue
  can duck music without muting the steam warning or chandelier creak.
- Crossfade room beds on screen changes. The salon music can bleed faintly
  into the foyer; the steam hum should dominate its own screen.
- Save the exact downloaded filenames and source links beside any imported
  audio. Export only the clips used after trimming, with credits retained even
  though CC0 does not require attribution.
