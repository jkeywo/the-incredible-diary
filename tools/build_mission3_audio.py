"""Prepare approved ambience/effects as compact Ogg files. Needs numpy, soundfile, FFmpeg.

Stage the original files in build/audio-source/mission3. Music is copied unchanged
from the supplied downloads. See assets/audio/mission_3/README.md for provenance.
"""
from pathlib import Path
import argparse
import subprocess
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "build/audio-source/mission3"
OUTPUT = ROOT / "assets/audio/mission_3"


def convert(name, folder, ffmpeg, loop=False, max_seconds=None):
    audio, rate = sf.read(SOURCE / name, always_2d=True)
    if max_seconds:
        # Discard leading silence and keep a short piece of actual activity.
        audible = np.flatnonzero(np.max(np.abs(audio), axis=1) > 0.003)
        if len(audible):
            audio = audio[max(0, int(audible[0]) - int(rate * 0.05)):]
        audio = audio[:int(max_seconds * rate)]
        edge = min(int(rate * 0.03), len(audio) // 4)
        audio[:edge] *= np.linspace(0, 1, edge)[:, None]
        audio[-edge:] *= np.linspace(1, 0, edge)[:, None]
    if loop:
        edge = min(int(rate * 0.8), len(audio) // 4)
        blend = np.linspace(0, 1, edge)[:, None]
        seam = audio[-edge:] * (1-blend) + audio[:edge] * blend
        audio = np.concatenate((audio[edge:-edge], seam))
    peak = float(np.max(np.abs(audio)))
    if peak > 0:
        audio *= 0.7 / peak
    target = OUTPUT / folder / (Path(name).stem + ".ogg")
    target.parent.mkdir(parents=True, exist_ok=True)
    intermediate = SOURCE / (Path(name).stem + "_prepared.wav")
    sf.write(intermediate, audio, rate, subtype="PCM_16")
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-y", "-i",
                    str(intermediate), "-c:a", "libvorbis", "-q:a", "4", str(target)], check=True)
    print(f"{target.name}: {len(audio)/rate:.2f}s, {target.stat().st_size} bytes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", required=True)
    args = parser.parse_args()
    for name in ["restaurant_walla.mp3", "market_walla.mp3"]:
        convert(name, "ambience", args.ffmpeg, loop=True)
    for name in ["cookware_clatter.wav", "fast_chops_on_cutting_board.wav",
                 "slow_chops_on_cutting_board.wav", "water_boiling_in_pot.wav",
                 "gas_burner_flicker_on_2.wav"]:
        convert(name, "kitchen", args.ffmpeg, max_seconds=10)
