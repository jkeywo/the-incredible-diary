"""Build the chosen Mission 1 event clips from ignored CC0 source downloads.

Requires numpy and soundfile. Source paths and licenses are recorded in
assets/audio/mission_1/README.md. Run with PYTHONPATH pointing at a local
soundfile installation if it is not in the selected Python environment.
"""

from pathlib import Path

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "build" / "audio-source" / "mission1-sfx"
OUT = ROOT / "assets" / "audio" / "mission_1"
RATE = 44100


def read(path: str, start: float = 0.0, end: float | None = None) -> np.ndarray:
    y, rate = sf.read(SRC / path, always_2d=True, dtype="float32")
    y = y[int(start * rate):int(end * rate) if end is not None else None]
    if rate != RATE:
        original = np.arange(len(y), dtype=np.float64) / rate
        target = np.arange(round(len(y) * RATE / rate), dtype=np.float64) / RATE
        y = np.stack([np.interp(target, original, y[:, channel]) for channel in range(y.shape[1])], axis=1).astype("float32")
    return y


def mono(y: np.ndarray) -> np.ndarray:
    return y.mean(axis=1, keepdims=True)


def fade(y: np.ndarray, attack: float = 0.005, release: float = 0.06) -> np.ndarray:
    y = y.copy()
    a = min(len(y), round(attack * RATE))
    r = min(len(y), round(release * RATE))
    if a:
        y[:a] *= np.linspace(0.0, 1.0, a, dtype="float32")[:, None]
    if r:
        y[-r:] *= np.linspace(1.0, 0.0, r, dtype="float32")[:, None]
    return y


def save(name: str, y: np.ndarray) -> None:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if np.max(np.abs(y)) > 1.0:
        raise ValueError(f"{name} clips: peak {np.max(np.abs(y))}")
    sf.write(path, y, RATE, subtype="PCM_16")
    print(f"{name}: {len(y) / RATE:.2f}s, peak {np.max(np.abs(y)):.3f}")


def simple(name: str, source: str, gain: float = 1.0, start: float = 0.0, end: float | None = None) -> None:
    save(name, fade(read(source, start, end) * gain))


general = "extracted/general/"
metal = "extracted/metal/"
doors = "extracted/doors/qubodup-DoorSet/ogg/"
controls = "extracted/metal_interactions/metal_interactions/"

# Short, varied steps for both surfaces; one player step triggers one file.
for i in range(1, 3):
    simple(f"sfx/footstep_dock_{i:02d}.wav", f"{general}sfx100v2_footstep_{i:02d}.ogg", 0.55)
for i in range(1, 5):
    simple(f"sfx/footstep_wood_{i:02d}.wav", f"{general}sfx100v2_footstep_wood_{i:02d}.ogg", 0.55)

# Bags have separate rustle, lift/move and set-down cues. The long source
# recording stays in the ignored build directory.
simple("sfx/baggage_rustle.wav", "cloth.mp3", 0.85, 0.3, 2.0)
simple("sfx/baggage_move.wav", "luggage.mp3", 0.70, 21.45, 23.25)
simple("sfx/baggage_set_down.wav", "luggage.mp3", 0.55, 52.75, 53.65)

simple("sfx/cabin_door_open.wav", f"{doors}qubodup-DoorOpen02.ogg", 0.7)
simple("sfx/cabin_door_close.wav", f"{metal}wood_close_01.ogg", 0.7)
simple("sfx/service_door_open.wav", f"{metal}metal_open_01.ogg", 0.65)
simple("sfx/service_door_close.wav", f"{metal}metal_close_01.ogg", 0.65)
simple("sfx/control_button.wav", f"{controls}metal_button_press1.wav", 0.55)
simple("sfx/control_switch.wav", f"{controls}metal_interaction1.wav", 0.60)
simple("sfx/steam_valve.wav", f"{metal}lock_open_01.ogg", 0.65)

simple("sfx/chandelier_creak.wav", "tree_creak/tree_creak_0.ogg", 0.55, 0.0, 3.6)
simple("sfx/chandelier_impact.wav", "metal_impacts/bong1.wav", 0.75)
simple("sfx/chandelier_glass.wav", "glass_break/glass_breaking.wav", 0.65)
simple("sfx/steam_cough.wav", "cough.mp3", 0.95, 0.0, 1.05)
simple("sfx/crew_alarm_placeholder.wav", "alarm_voice/helpme_1.wav", 0.7)

# The rescue beats are deliberately small in the mix: a muffled contact and
# clothing scuff for the shove, a short trickle with an intact-glass clink.
thud = mono(read("metal_impacts/thud2.wav"))
scuff = mono(read("cloth.mp3", 0.42, 1.08))
shove = np.zeros((max(len(thud), len(scuff) + round(.04 * RATE)), 1), dtype="float32")
shove[:len(thud)] += thud * .18
offset = round(.04 * RATE)
shove[offset:offset + len(scuff)] += scuff * .23
save("sfx/shove_soft.wav", fade(shove, release=.09))

splash = mono(read("extracted/splash/splash_09.ogg"))
clink = mono(read("metal_impacts/clink1_0.wav"))
spill = np.zeros((max(len(splash), len(clink) + round(.12 * RATE)), 1), dtype="float32")
spill[:len(splash)] += splash * .13
offset = round(.12 * RATE)
spill[offset:offset + len(clink)] += clink * .16
save("sfx/drink_spill_soft.wav", fade(spill, release=.12))

# A short wrap crossfade removes the edge when the salon crowd bed loops.
crowd = read("salon_crowd.mp3")
overlap = round(.8 * RATE)
blend = np.linspace(0.0, 1.0, overlap, endpoint=False, dtype="float32")[:, None]
boundary = crowd[-overlap:] * (1.0 - blend) + crowd[:overlap] * blend
crowd_loop = np.concatenate((crowd[overlap:-overlap], boundary))
path = OUT / "ambience" / "salon_crowd.wav"
path.parent.mkdir(parents=True, exist_ok=True)
sf.write(path, crowd_loop, RATE, subtype="PCM_16")
print(f"ambience/salon_crowd.wav: {len(crowd_loop) / RATE:.2f}s")
