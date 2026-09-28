"""Build static four-facing sprites and recolour masks from imagegen sources.

Uses the bundled Pillow runtime.  Creative source art is kept in
assets/characters/generic/source; this script only fits it to the game's
existing 32 x 48 static cell size and classifies the designated colour regions.
"""

from __future__ import annotations

import colorsys
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets" / "characters" / "generic"
SOURCE = ASSETS / "source"
CELL = (32, 48)
FACING_COUNT = 4
ANIMATIONS = (("idle", 2), ("walk", 4), ("talk", 3), ("bob", 4))
NAMES = (
    "sailor",
    "guest_male_jacket",
    "guest_male_waistcoat",
    "guest_female_dress",
    "guest_female_coat",
)
ALTERNATE_GARMENTS = {
    "guest_male_jacket": (0.68, 0.27, 0.22),
    "guest_male_waistcoat": (0.22, 0.48, 0.72),
    "guest_female_dress": (0.64, 0.23, 0.40),
    "guest_female_coat": (0.20, 0.51, 0.33),
}


def static_facing(source: Image.Image, index: int) -> Image.Image:
    width = source.width // FACING_COUNT
    face = source.crop((index * width, 0, (index + 1) * width, source.height))
    alpha = face.getchannel("A").point(lambda value: 255 if value >= 32 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"No art for facing {index}")
    face = face.crop(bounds)
    scale = min(30 / face.width, 46 / face.height)
    face = face.resize((max(1, round(face.width * scale)), max(1, round(face.height * scale))), Image.Resampling.LANCZOS)
    face.putalpha(face.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    cell = Image.new("RGBA", CELL)
    cell.alpha_composite(face, ((CELL[0] - face.width) // 2, CELL[1] - face.height))
    return cell


def garment_pixel(name: str, rgb: tuple[int, int, int], x: int, y: int) -> bool:
    red, green, blue = rgb
    hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
    if name == "sailor":
        return False
    if name in ("guest_male_jacket", "guest_female_dress"):
        return 0.46 <= hue <= 0.61 and saturation > 0.23 and value > 0.15
    if name == "guest_male_waistcoat":
        return (14 <= y <= 34 and 5 <= x <= 27 and 0.015 <= hue <= 0.105
                and saturation > 0.54 and green < 145 and blue < 105)
    if name == "guest_female_coat":
        return 13 <= y <= 36 and 0.72 <= hue <= 0.91 and saturation > 0.23 and value > 0.18
    raise ValueError(name)


def skin_pixel(name: str, rgb: tuple[int, int, int], x: int, y: int) -> bool:
    red, green, blue = rgb
    hue, saturation, value = colorsys.rgb_to_hsv(red / 255, green / 255, blue / 255)
    # The coat guest's cream skirt shares some warm colours with the base skin.
    # Its exposed skin is above the skirt, so keep that mask in the upper body.
    if name == "guest_female_coat" and y >= 35:
        return False
    return (0.015 <= hue <= 0.13 and 0.22 <= saturation <= 0.78
            and value > 0.37 and red > green + 15 and green > blue + 8
            and y < 43)


def make_mask(name: str, sheet: Image.Image) -> tuple[Image.Image, int, int]:
    mask = Image.new("RGB", sheet.size)
    skin_count = garment_count = 0
    for y in range(sheet.height):
        for x in range(sheet.width):
            red, green, blue, alpha = sheet.getpixel((x, y))
            if alpha < 128:
                continue
            local_x = x % CELL[0]
            if garment_pixel(name, (red, green, blue), local_x, y):
                mask.putpixel((x, y), (0, 255, 0))
                garment_count += 1
            elif skin_pixel(name, (red, green, blue), local_x, y):
                mask.putpixel((x, y), (255, 0, 0))
                skin_count += 1
    return mask, skin_count, garment_count


def recoloured_example(name: str, sheet: Image.Image, mask: Image.Image) -> Image.Image:
    result = sheet.copy()
    skin_luma = {"sailor": 0.547, "guest_male_jacket": 0.528,
                 "guest_male_waistcoat": 0.546, "guest_female_dress": 0.562,
                 "guest_female_coat": 0.638}[name]
    garment_luma = {"guest_male_jacket": 0.272, "guest_male_waistcoat": 0.331,
                    "guest_female_dress": 0.227, "guest_female_coat": 0.214}
    dark_skin = (0.36, 0.21, 0.15)
    for y in range(sheet.height):
        for x in range(sheet.width):
            red, green, blue, alpha = sheet.getpixel((x, y))
            if alpha == 0:
                continue
            mark = mask.getpixel((x, y))
            if mark[0] > 127:
                target, baseline = dark_skin, skin_luma
            elif mark[1] > 127:
                target, baseline = ALTERNATE_GARMENTS[name], garment_luma[name]
            else:
                continue
            luma = (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255
            recoloured = tuple(min(255, round(component * luma / baseline * 255)) for component in target)
            result.putpixel((x, y), (*recoloured, alpha))
    return result


def shifted(base: Image.Image, dy: int) -> Image.Image:
    result = Image.new("RGBA" if base.mode == "RGBA" else "RGB", CELL)
    result.paste(base, (0, dy))
    return result


def walk_pose(base: Image.Image, direction: int, phase: int, skirt: bool) -> Image.Image:
    split_y = 42 if skirt else 35
    result = Image.new("RGBA" if base.mode == "RGBA" else "RGB", CELL)
    result.paste(base.crop((0, 0, 32, split_y)), (0, -int(phase in (1, 3))))
    left = base.crop((0, split_y, 16, 48))
    right = base.crop((16, split_y, 32, 48))
    if direction in (1, 3):
        stride = (-2, 0, 2, 0)[phase]
        if skirt:
            stride = max(-1, min(1, stride))
        result.paste(left, (stride, split_y - int(phase == 1)))
        result.paste(right, (16 - stride, split_y - int(phase == 3)))
    else:
        lift = (0, 1, 2, 1)[phase]
        result.paste(left, (0, split_y - lift))
        result.paste(right, (16, split_y - (2 - lift)))
    return result


def animation_frames(base: Image.Image, direction: int, skirt: bool) -> list[Image.Image]:
    frames = [base, shifted(base, -1)]
    frames += [walk_pose(base, direction, phase, skirt) for phase in range(4)]
    frames += [base, shifted(base, -1), shifted(base, 1)]
    frames += [shifted(base, dy) for dy in (0, 1, -1, 0)]
    return frames


def make_animation_sheets(name: str, sheet: Image.Image, mask: Image.Image) -> None:
    width = CELL[0] * sum(count for _, count in ANIMATIONS)
    sprite_sheet = Image.new("RGBA", (width, CELL[1] * FACING_COUNT))
    mask_sheet = Image.new("RGB", sprite_sheet.size)
    skirt = name in ("guest_female_dress", "guest_female_coat")
    for direction in range(FACING_COUNT):
        rect = (direction * CELL[0], 0, (direction + 1) * CELL[0], CELL[1])
        sprite_frames = animation_frames(sheet.crop(rect), direction, skirt)
        mask_frames = animation_frames(mask.crop(rect), direction, skirt)
        for index, (sprite_frame, mask_frame) in enumerate(zip(sprite_frames, mask_frames)):
            dest = (index * CELL[0], direction * CELL[1])
            sprite_sheet.alpha_composite(sprite_frame, dest)
            mask_sheet.paste(mask_frame, dest)
    sprite_sheet.save(ASSETS / f"{name}_sprites.png", optimize=True)
    mask_sheet.save(ASSETS / f"{name}_sprites_mask.png", optimize=True)


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    preview = Image.new("RGBA", (CELL[0] * FACING_COUNT * 2, CELL[1] * len(NAMES)), (32, 37, 48, 255))
    for row, name in enumerate(NAMES):
        source = Image.open(SOURCE / f"{name}.png").convert("RGBA")
        sheet = Image.new("RGBA", (CELL[0] * FACING_COUNT, CELL[1]))
        for index in range(FACING_COUNT):
            sheet.alpha_composite(static_facing(source, index), (index * CELL[0], 0))
        mask, skin_count, garment_count = make_mask(name, sheet)
        sheet.save(ASSETS / f"{name}.png", optimize=True)
        mask.save(ASSETS / f"{name}_mask.png", optimize=True)
        make_animation_sheets(name, sheet, mask)
        preview.alpha_composite(sheet, (0, row * CELL[1]))
        preview.alpha_composite(recoloured_example(name, sheet, mask), (CELL[0] * FACING_COUNT, row * CELL[1]))
        print(f"{name}: skin={skin_count} garment={garment_count}")
    preview.resize((preview.width * 4, preview.height * 4), Image.Resampling.NEAREST).save(
        ASSETS / "palette_preview.png", optimize=True)


if __name__ == "__main__":
    main()
