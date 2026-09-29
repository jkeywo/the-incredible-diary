"""Fit imagegen Mission 1 character and effect poses into gameplay strips.

This script crops, scales and aligns generated transparent art. Character 1's
stained movement uses the established four-facing sprite construction; it does
not change the clean rake sheet.
"""

from pathlib import Path

from PIL import Image, ImageDraw

from build_character_sprites import (
    ANIMATIONS,
    CELL,
    base_pose,
    bob_pose,
    place,
    shifted,
    talk_pose,
    walk_pose,
)


ROOT = Path(__file__).resolve().parents[1]
CHAR_SOURCE = ROOT / "assets" / "characters" / "actions" / "source"
CHAR_OUTPUT = ROOT / "assets" / "characters"
EFFECT_DIR = ROOT / "assets" / "effects" / "mission_1"
EFFECT_SOURCE = EFFECT_DIR / "source"

STRIPS = {
    # source, output, source spans, cell, maximum painted dimensions, alpha cutoff
    "steam_casualty": (
        CHAR_SOURCE / "matron_steam_casualty.png",
        CHAR_OUTPUT / "actions" / "matron_steam_casualty.png",
        [(0, 510), (510, 950), (950, 1536)],
        (32, 48),
        [(30, 46), (30, 36), (30, 22)],
        64,
    ),
    "obscured_spiking": (
        CHAR_SOURCE / "obscured_spiking.png",
        EFFECT_DIR / "obscured_spiking.png",
        [(0, 470), (470, 941), (941, 1411), (1411, 1882)],
        (64, 64),
        [(60, 60)] * 4,
        64,
    ),
    "steam_plume": (
        EFFECT_SOURCE / "steam_plume.png",
        EFFECT_DIR / "steam_plume.png",
        [(0, 443), (443, 887), (887, 1330), (1330, 1774)],
        (128, 112),
        [(56, 106), (92, 108), (122, 110), (94, 108)],
        24,
    ),
    "chandelier_dust": (
        EFFECT_SOURCE / "chandelier_dust.png",
        EFFECT_DIR / "chandelier_dust.png",
        [(0, 443), (443, 887), (887, 1330), (1330, 1774)],
        (160, 80),
        [(80, 54), (126, 60), (150, 76), (116, 56)],
        24,
    ),
    "drink_splash": (
        EFFECT_SOURCE / "drink_splash.png",
        EFFECT_DIR / "drink_splash.png",
        [(0, 443), (443, 887), (887, 1330), (1330, 1774)],
        (64, 48),
        [(48, 46), (56, 44), (60, 36), (58, 26)],
        48,
    ),
}


def build_stained_sheet() -> None:
    source = Image.open(CHAR_SOURCE / "rake_stained.png").convert("RGBA")
    walk_source = Image.open(CHAR_SOURCE / "rake_stained_walk.png").convert("RGBA")
    sheet = Image.new("RGBA", (CELL[0] * sum(count for _, count in ANIMATIONS), CELL[1] * 4))
    for direction in range(4):
        base = base_pose(source, direction)
        walk_base = base_pose(walk_source, 0 if direction == 1 else 1, 2) if direction in (1, 3) else base
        frames = [base, shifted(base, -1)]
        frames += [walk_pose(walk_base, direction, phase, False) for phase in range(4)]
        frames += [talk_pose(base, direction, phase) for phase in range(3)]
        frames += [bob_pose(base, phase) for phase in range(4)]
        for column, frame in enumerate(frames):
            place(sheet, frame, column * CELL[0], direction * CELL[1])
    destination = CHAR_OUTPUT / "rake_stained_sprites.png"
    sheet.save(destination, optimize=True)
    print(destination)


def fit_pose(image: Image.Image, span: tuple[int, int], cell: tuple[int, int],
             maximum: tuple[int, int], cutoff: int) -> Image.Image:
    source = image.crop((span[0], 0, span[1], image.height))
    alpha = source.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= cutoff else 0).getbbox()
    if bounds is None:
        raise ValueError("Missing generated effect pose")
    source = source.crop(bounds)
    source.putalpha(source.getchannel("A").point(lambda value: value if value >= cutoff else 0))
    scale = min(maximum[0] / source.width, maximum[1] / source.height)
    size = (max(1, round(source.width * scale)), max(1, round(source.height * scale)))
    source = source.resize(size, Image.Resampling.LANCZOS)
    result = Image.new("RGBA", cell)
    result.alpha_composite(source, ((cell[0] - size[0]) // 2, cell[1] - size[1]))
    return result


def build_strip(name: str) -> Image.Image:
    source_path, output_path, spans, cell, maximums, cutoff = STRIPS[name]
    source = Image.open(source_path).convert("RGBA")
    frames = [fit_pose(source, span, cell, maximum, cutoff)
              for span, maximum in zip(spans, maximums)]
    if name == "steam_casualty":
        frames.append(frames[-1].copy())  # The last frame is held after the clip.
    sheet = Image.new("RGBA", (cell[0] * len(frames), cell[1]))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * cell[0], 0))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output_path, optimize=True)
    print(output_path)
    return sheet


def build_preview(sheets: dict[str, Image.Image]) -> None:
    stained = Image.open(CHAR_OUTPUT / "rake_stained_sprites.png").convert("RGBA")
    rows = [("stained rake walk / idle", stained.crop((0, 0, stained.width, 48)))]
    rows += list(sheets.items())
    preview = Image.new("RGBA", (850, 230 * len(rows)), "#1b2430")
    draw = ImageDraw.Draw(preview)
    for index, (name, sheet) in enumerate(rows):
        y = index * 230
        draw.text((12, y + 10), name, fill="#f2dcab")
        scale = min(4, 820 / sheet.width, 188 / sheet.height)
        resized = sheet.resize((round(sheet.width * scale), round(sheet.height * scale)), Image.Resampling.NEAREST)
        preview.alpha_composite(resized, (12, y + 30))
    preview.save(EFFECT_DIR / "character_effect_preview.png", optimize=True)


if __name__ == "__main__":
    build_stained_sheet()
    outputs = {name: build_strip(name) for name in STRIPS}
    build_preview(outputs)
