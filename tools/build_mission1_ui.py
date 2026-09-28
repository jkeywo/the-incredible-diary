"""Prepare the imagegen diary illustrations and exact title lettering.

The source PNGs are retained at full resolution. Typography is rasterized into
a separate transparent texture so the Godot cover and its title can swipe
together without baking generated lettering into the illustration.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "assets" / "ui" / "mission_1"
SOURCE = UI / "source"
SIZE = (1160, 740)
FONT_DIR = Path("C:/Windows/Fonts")


def tracked_line(draw: ImageDraw.ImageDraw, label: str, font: ImageFont.FreeTypeFont,
                 center_x: int, top: int, tracking: int, color: tuple[int, ...]) -> None:
    glyphs = [(letter, draw.textlength(letter, font=font)) for letter in label]
    width = sum(width for _, width in glyphs) + tracking * max(0, len(glyphs) - 1)
    x = center_x - width / 2
    for letter, width in glyphs:
        draw.text((round(x + 1), top + 2), letter, font=font, fill=(3, 10, 22, 225),
                  stroke_width=1, stroke_fill=(3, 10, 22, 225))
        draw.text((round(x), top), letter, font=font, fill=color)
        x += width + tracking


def title_lettering() -> Image.Image:
    lettering = Image.new("RGBA", SIZE)
    draw = ImageDraw.Draw(lettering)
    deco_small = ImageFont.truetype(str(FONT_DIR / "AGENCYB.TTF"), 47)
    deco_main = ImageFont.truetype(str(FONT_DIR / "AGENCYB.TTF"), 62)
    deco_large = ImageFont.truetype(str(FONT_DIR / "AGENCYB.TTF"), 77)
    tracked_line(draw, "THE", deco_small, 852, 162, 9, (242, 197, 106, 255))
    tracked_line(draw, "INCREDIBLE", deco_main, 852, 226, 3, (250, 218, 150, 255))
    tracked_line(draw, "DIARY", deco_large, 852, 306, 7, (250, 218, 150, 255))
    # The personal attribution crosses the formal title at a handwritten angle.
    cursive = ImageFont.truetype(str(FONT_DIR / "VIVALDII.TTF"), 49)
    writing = Image.new("RGBA", (480, 155))
    ink = ImageDraw.Draw(writing)
    for words, top in (("of Lady Amelia", 0), ("Ashcombe", 60)):
        width = ink.textlength(words, font=cursive)
        ink.text(((480 - width) / 2 + 2, top + 3), words, font=cursive,
                 fill=(4, 8, 18, 220))
        ink.text(((480 - width) / 2, top), words, font=cursive,
                 fill=(228, 228, 202, 255))
    writing = writing.rotate(8, Image.Resampling.BICUBIC, expand=True)
    lettering.alpha_composite(writing, (852 - writing.width // 2, 381))
    return lettering


def main() -> None:
    UI.mkdir(parents=True, exist_ok=True)
    prepared: dict[str, Image.Image] = {}
    for name in ("closed", "open"):
        source = Image.open(SOURCE / f"diary_{name}_master.png").convert("RGBA")
        prepared[name] = source.resize(SIZE, Image.Resampling.LANCZOS)
        prepared[name].save(UI / f"diary_{name}.png", optimize=True)
    lettering = title_lettering()
    lettering.save(UI / "diary_title_lettering.png", optimize=True)
    preview = prepared["closed"].copy()
    preview.alpha_composite(lettering)
    preview.save(UI / "diary_title_preview.png", optimize=True)


if __name__ == "__main__":
    main()
