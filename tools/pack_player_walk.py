"""Pack the imagegen walk poses into the existing 32x48 character grid.

Only crops, scales and aligns generated artwork; does not synthesize limb poses.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / "assets/characters/walk_source/player_cycle.png").convert("RGBA")
rows = (0, 310, 610, 915, source.height)
poses = []
for row in range(4):
    for column in range(4):
        cell = source.crop((column * source.width // 4, rows[row],
                            (column + 1) * source.width // 4, rows[row + 1]))
        bounds = cell.getchannel("A").point(lambda a: 255 if a >= 128 else 0).getbbox()
        if bounds is None:
            raise ValueError(f"Missing pose {row}, {column}")
        poses.append(cell.crop(bounds))

scale = min(30 / max(p.width for p in poses), 46 / max(p.height for p in poses))
sheet = Image.new("RGBA", (128, 192))
for index, pose in enumerate(poses):
    pose = pose.resize((round(pose.width * scale), round(pose.height * scale)), Image.Resampling.LANCZOS)
    pose.putalpha(pose.getchannel("A").point(lambda a: 255 if a >= 128 else 0))
    sheet.alpha_composite(pose, ((index % 4) * 32 + (32 - pose.width) // 2,
                                (index // 4) * 48 + 48 - pose.height))
sheet.save(ROOT / "assets/characters/player_walk.png")
