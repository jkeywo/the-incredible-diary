"""Build the original Mission 1 bell cue using only Python's standard library."""
import math
from pathlib import Path
import struct
import wave

RATE = 44100
output = Path(__file__).resolve().parents[1] / "assets/audio/mission_1/sfx/hour_chime.wav"
with wave.open(str(output), "wb") as audio:
    audio.setparams((1, 2, RATE, 0, "NONE", "not compressed"))
    samples = []
    for i in range(RATE * 3):
        t = i / RATE
        envelope = min(1.0, t / 0.004) * min(1.0, (3.0 - t) / 0.15)
        value = sum(gain * math.sin(math.tau * frequency * t) * math.exp(-t / decay)
                    for frequency, gain, decay in [(880, .27, .8), (1763, .10, .45), (2380, .06, .25)])
        samples.append(struct.pack("<h", int(32767 * envelope * value)))
    audio.writeframes(b"".join(samples))
