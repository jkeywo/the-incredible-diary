"""Crop generated Mission 1 prop states into transparent Godot sprite sheets.

Run with the bundled Pillow Python runtime after changing imagegen sources in
assets/props/mission_1/source/. Cells are bottom-centred so state changes keep
their placement anchor. The full and spiked drinks intentionally share art.
"""

from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
DIR = ROOT / "assets" / "props" / "mission_1"
SOURCE = DIR / "source"

# Explicit boundaries prevent wide generated objects crossing equal columns.
SLICES = {
    "cabin_door": [(0, 887), (887, 1774)],
    "service_door": [(0, 768), (768, 1536)],
    "baggage": [(0, 530), (530, 1290), (1290, 2017)],
    "code_panel_wide": [(0, 1870)],
    "drink": [(0, 520), (520, 1280), (1280, 1774)],
    "chandelier": [(0, 724), (724, 1448), (1448, 2172)],
    "steam_vent": [(0, 887), (887, 1774)],
}

# (source name, source columns, cell size, per-source maximum painted size)
SHEETS = {
    "cabin_door": ("cabin_door", [0, 1], (96, 104), [(90, 56), (88, 98)]),
    "service_door": ("service_door", [0, 1], (80, 128), [(72, 124)] * 2),
    "suitcase": ("baggage", [0, None], (56, 48), [(52, 42)]),
    "bag_hiding": ("baggage", [1, 2], (112, 88), [(108, 82), (108, 82)]),
    "code_panel": ("code_panel_wide", [0, 0, 0, 0], (240, 108), [(234, 102)] * 4),
    "drink": ("drink", [0, 0, 1, 2], (56, 48), [(34, 44), (34, 44), (54, 40), (34, 44)]),
    "chandelier": ("chandelier", [0, 1, 2], (144, 144), [(132, 132), (132, 132), (140, 82)]),
    "steam_vent": ("steam_vent", [0, 1], (160, 144), [(154, 140), (82, 76)]),
}


def source_sprite(image: Image.Image, span: tuple[int, int], alpha_cutoff: int) -> Image.Image:
    column = image.crop((span[0], 0, span[1], image.height))
    alpha = column.getchannel("A")
    bounds = alpha.point(lambda value: 255 if value >= alpha_cutoff else 0).getbbox()
    if bounds is None:
        raise ValueError("Generated prop state is empty")
    column = column.crop(bounds)
    column.putalpha(column.getchannel("A").point(lambda value: value if value >= alpha_cutoff else 0))
    return column


def fit(sprite: Image.Image, cell: tuple[int, int], maximum: tuple[int, int]) -> Image.Image:
    scale = min(maximum[0] / sprite.width, maximum[1] / sprite.height)
    width = max(1, round(sprite.width * scale))
    height = max(1, round(sprite.height * scale))
    sprite = sprite.resize((width, height), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", cell)
    result.alpha_composite(sprite, ((cell[0] - width) // 2, cell[1] - height))
    return result


def build(only: str | None = None) -> None:
    cache = {name: Image.open(SOURCE / f"{name}.png").convert("RGBA") for name in SLICES}
    preview_rows = []
    for name, (source_name, columns, cell, maximums) in SHEETS.items():
        if only and name != only:
            continue
        source = cache[source_name]
        sheet = Image.new("RGBA", (cell[0] * len(columns), cell[1]))
        for index, source_index in enumerate(columns):
            if source_index is None:
                continue
            cutoff = 24 if source_name == "steam_vent" else 64
            sprite = source_sprite(source, SLICES[source_name][source_index], cutoff)
            if name == "code_panel":
                # The new housing has an explicit in-game size and fixed apertures.
                pose = Image.new("RGBA", cell)
                pose.alpha_composite(sprite.resize((234, 102), Image.Resampling.LANCZOS), (3, 6))
            else:
                pose = fit(sprite, cell, maximums[index])
            sheet.alpha_composite(pose, (index * cell[0], 0))
        sheet.save(DIR / f"{name}_states.png", optimize=True)
        preview_rows.append((name, sheet))
        print(DIR / f"{name}_states.png")

    if only:
        return
    preview = Image.new("RGBA", (850, len(preview_rows) * 240), "#1b2430")
    draw = ImageDraw.Draw(preview)
    for row, (name, sheet) in enumerate(preview_rows):
        draw.text((12, row * 240 + 12), name, fill="#f2dcab")
        scale = min(2, 810 / sheet.width, 205 / sheet.height)
        large = sheet.resize((round(sheet.width * scale), round(sheet.height * scale)), Image.Resampling.NEAREST)
        preview.alpha_composite(large, (12, row * 240 + 30))
    preview.save(DIR / "prop_preview.png", optimize=True)


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=SHEETS)
    build(parser.parse_args().only)
