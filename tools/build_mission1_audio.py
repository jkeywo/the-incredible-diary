"""Stitch the four downloaded CC0 wave recordings into a looping dock bed.

Inputs: build/audio-source/wave_01.flac ... wave_04.flac from the Water Waves
OpenGameArt page. Requires numpy and soundfile for this asset-build step only.
"""

from pathlib import Path

import numpy as np
import soundfile as sf


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "build" / "audio-source"
OUTPUT = ROOT / "assets" / "audio" / "mission_1" / "ambience" / "dock_waves.wav"
RATE = 44100
OVERLAP = int(RATE * 0.3)


def join(left: np.ndarray, right: np.ndarray) -> np.ndarray:
    blend = np.linspace(0.0, 1.0, OVERLAP, endpoint=False)[:, None]
    middle = left[-OVERLAP:] * (1.0 - blend) + right[:OVERLAP] * blend
    return np.concatenate((left[:-OVERLAP], middle, right[OVERLAP:]))


clips = []
for index in range(1, 5):
    audio, sample_rate = sf.read(SOURCE / f"wave_{index:02d}.flac", always_2d=True)
    if sample_rate != RATE or audio.shape[1] != 2:
        raise ValueError("Unexpected dock wave format")
    clips.append(audio)

bed = clips[0]
for clip in clips[1:]:
    bed = join(bed, clip)

# Crossfade the tail into the head, then start playback after the head segment.
blend = np.linspace(0.0, 1.0, OVERLAP, endpoint=False)[:, None]
boundary = bed[-OVERLAP:] * (1.0 - blend) + bed[:OVERLAP] * blend
bed = np.concatenate((bed[OVERLAP:-OVERLAP], boundary))
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
sf.write(OUTPUT, bed, RATE, subtype="PCM_16")
print(f"Wrote {OUTPUT} ({len(bed) / RATE:.2f}s)")
