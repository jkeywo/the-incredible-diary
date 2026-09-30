# Greek shore audio

## Music credits

Greece Vol. 1–5 [Travel Series] by **Sascha Ende — ende.app**.
Licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
[Publisher's licence](https://ende.app/standard-license).
The MP3s were supplied in the user's Downloads folder and copied unchanged.

- [Volume 1](https://ende.app/en/song/12889-greece-vol-1-travel-series)
- [Volume 2](https://ende.app/en/song/12890-greece-vol-2-travel-series)
- [Volume 3](https://ende.app/en/song/12905-greece-vol-3-travel-series)
- [Volume 4](https://ende.app/en/song/13788-greece-vol-4-travel-series)
- [Volume 5](https://ende.app/en/song/13789-greece-vol-5-travel-series)

`greek_playlist.tres` plays volumes 1–5 in order. A fresh random 5–20 second
gap follows each track, including volume 5 before returning to volume 1.
The three shore scenes share this resource, retaining the active player and gap
on room changes and on the title-to-gameplay handoff. Pausing freezes playback
and gaps. Sequences use listening time, independently of simulation speed and
rewind; a new player starts at volume 1. Returning from the ship starts a new
shore playlist. The individual tracks never loop themselves.

## Ambience and kitchen credits

| Files | Creator and source | Licence and edits |
|---|---|---|
| `ambience/restaurant_walla.ogg` | MicheleFalleri, [Restaurant ambience](https://freesound.org/people/MicheleFalleri/sounds/578447/) | [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Public HQ preview; peak adjusted, 0.8-second wrap crossfade and Ogg conversion. |
| `ambience/market_walla.ogg` | jenniferelradhi (Freesound), [Traders calling Central Athens Market October 2018](https://pixabay.com/fr/sound-effects/ville-traders-calling-central-athens-market-october-2018-68627/) | [Pixabay Content Licence](https://pixabay.com/service/license-summary/). User-supplied download; peak adjusted, 0.8-second wrap crossfade and Ogg conversion. |
| All five `kitchen/*.ogg` files | DavidW, [Kitchen Ambience, SFX](https://opengameart.org/content/kitchen-ambience-sfx) | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Individual source effects, without the preview's third-party walla. Leading silence trimmed; first ten seconds of activity retained, short edge fades, peak adjustment and Ogg conversion. |

Kitchen effects play below the restaurant bed at -27 dB, one at a time with
random 3–9 second gaps and no immediate repeat. All levels and gap ranges are
editable in the room settings/resources. These sounds use the SFX bus; the
playlist uses Music. The existing room crossfades and presentation gain apply.

`tools/build_mission3_audio.py --ffmpeg <executable>` reproduces the Ogg files
from originals in ignored `build/audio-source/mission3`, using numpy and
soundfile as build dependencies. No conversion tools are needed at runtime.
