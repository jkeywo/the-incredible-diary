# Mission 1 first-playable audio

The room scenes expose `RoomAudioSettings` in the Godot inspector. Each room
can set music, two continuous ambience beds, intermittent ambience, levels and
fade duration. `mission1/room_audio.gd` plays the beds at an offset calculated
from elapsed game time; its audio players and fades pause with the scene tree.

Open `res://mission1/room_audio_playtest.tscn` to audition all five backgrounds.
Press **1–5** to switch screens, **G** to switch the salon between Hot Swing
and George Street Shuffle, **Q/F** to select an event cue, **E** to play it,
and **Space** to pause/resume. The clock continues
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
| `ambience/salon_crowd.wav` | [“Small Crowd pre-concert talking party bar walla talking” by JohnsonBrandEditing](https://freesound.org/people/JohnsonBrandEditing/sounds/243373/) | CC0; built from the public high-quality MP3 preview with an 0.8-second wrap crossfade |

## Event cues

The trimmed files in `sfx/` are loaded by `mission1/event_audio.gd`. Add that
script to a `Node` in a gameplay scene and call `play_cue(&"cue_name")`.
It cycles footstep and hiss variants, pauses with the scene tree, and frees
one-shot players when playback finishes. The room/audio playtest exposes every
cue for audition. Gameplay events are not connected yet.

| Files or cues | Source | License and edits |
| --- | --- | --- |
| `footstep_dock_*`, `footstep_wood_*` | [“100 CC0 SFX #2” by rubberduck](https://opengameart.org/content/100-cc0-sfx-2) | CC0; four wood and two general steps, reduced level |
| `baggage_rustle` | [“foley cloth rustle.wav” by martian](https://freesound.org/people/martian/sounds/19291/) | CC0; trimmed from the public high-quality MP3 preview |
| `baggage_move`, `baggage_set_down` | [“Luggage Movement Foley.wav” by SpliceSound](https://freesound.org/people/SpliceSound/sounds/150443/) | CC0; two short excerpts from the public high-quality MP3 preview |
| `cabin_door_open` | [“Door Open, Door Close Set” by qubodup](https://opengameart.org/content/door-open-door-close-set) | CC0; `DoorOpen02`, reduced level |
| `cabin_door_close`, `service_door_open`, `service_door_close`, `steam_valve` | [“100 CC0 metal and wood SFX” by rubberduck](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) | CC0; chosen wood, metal and lock recordings, reduced level |
| `control_button`, `control_switch` | [“Metal Interactions” by qubodup](https://opengameart.org/content/metal-interactions) | CC0; reduced level |
| `chandelier_creak` | [“Tree Creaking” by AntumDeluge](https://opengameart.org/content/tree-creaking) | CC0; short excerpt, reduced level |
| `chandelier_impact`, part of `shove` and `drink_spill` | [“Metal Impact Sounds” by BMacZero](https://opengameart.org/content/metal-impact-sounds) | CC0; `shove` uses a quiet thud with a cloth scuff; `drink_spill` uses a quiet clink |
| `chandelier_glass` | [“Glass Break” by Till Behrend](https://opengameart.org/content/glass-break) | CC0; reduced level |
| part of `drink_spill` | [“40 CC0 water / splash / slime SFX” by rubberduck](https://opengameart.org/content/40-cc0-water-splash-slime-sfx) | CC0; short `splash_09`, mixed low with an intact-glass clink |
| `steam_cough` | [“Cough (2)” by OwlStorm / Owlish Media](https://freesound.org/people/OwlStorm/sounds/151212/) | CC0; trimmed from the public high-quality MP3 preview |
| `crew_alarm` | [“Oh My”, “Help me” by rubenwardy](https://opengameart.org/content/oh-my-help-me-posh-english-high-pitched) | CC0; temporary crew voice until the scripted line is recorded |

The soft rescue files peak at roughly 0.08 (`shove`) and 0.12 (`drink_spill`)
before their additional cue volume reduction. They are intended as quiet
physical accents. The build recipe is `tools/build_mission1_sfx.py`; original
downloads stay in ignored `build/audio-source/mission1-sfx/`. It requires
Python `numpy` and `soundfile` for asset preparation only, not at game runtime.

The two MacLeod tracks require title, creator, source, license and any edits in
distributed game credits. They have not been edited here. The dock wave build
script is `tools/build_mission1_audio.py`; its original FLAC downloads are in
the ignored `build/audio-source/` folder.

### Hour chime

`hour_chime.wav` is an original synthesized bell cue, generated by
`tools/build_hour_chime.py` using Python standard-library sine partials and
exponential decay. It uses no sampled third-party audio. The gameplay event
system plays it once on each forward voyage-hour boundary, through the SFX bus.
