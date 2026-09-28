# Mission 1 first-playable audio

The room scenes expose `RoomAudioSettings` in the Godot inspector. Each room
can set music, two continuous ambience beds, intermittent ambience, levels and
fade duration. `mission1/room_audio.gd` plays the beds at an offset calculated
from elapsed game time; its audio players and fades pause with the scene tree.

Open `res://mission1/room_audio_playtest.tscn` to audition all five backgrounds.
Press **1–5** to switch screens, **G** to switch the salon between Hot Swing
and George Street Shuffle, and **Space** to pause/resume. The clock continues
across rooms, so returning to a room seeks to the phase its sound would have
reached. The current opening scene also uses these settings for docks and
foyer. Other gameplay room connections have not yet been built.

## Sources and credits

| Imported file | Source | License |
| --- | --- | --- |
| `music/hot_swing.mp3` | [“Hot Swing” by Kevin MacLeod](https://incompetech.com/music/royalty-free/index.html?Search=Search&isrc=USUAN1100202) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `music/george_street_shuffle.mp3` | [“George Street Shuffle” by Kevin MacLeod](https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1300035) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) |
| `music/piano_swap_rpg.ogg` | [“Piano Swap Rpg” by Tozan](https://opengameart.org/content/piano-swap-rpg) | [CC0](https://creativecommons.org/publicdomain/zero/1.0/) |
| `ambience/dock_waves.wav` | [“Water Waves” by transitking](https://opengameart.org/content/water-waves) | CC0; edited by joining four source clips with short crossfades for a loop |
| `ambience/steamboat_engine.wav` | [“Steamboat Engine Sound” by Spring Spring](https://opengameart.org/content/steamboat-engine-sound) | CC0 |
| `ambience/steam_boiler.wav` | [“Steam boiler sound loop” by bart](https://opengameart.org/content/steam-boiler-sound-loop) | CC0 |
| `ambience/steam_hiss_01.wav`, `steam_hiss_03.wav` | [“Steam release sounds” by bart](https://opengameart.org/content/steam-release-sounds), archive markers 1 and 3 | CC0 |

The two MacLeod tracks require title, creator, source, license and any edits in
distributed game credits. They have not been edited here. The dock wave build
script is `tools/build_mission1_audio.py`; its original FLAC downloads are in
the ignored `build/audio-source/` folder.
