"""Fit imagegen Mission 1 action key poses to 32 x 48 gameplay clips.

Each four-column source provides one key pose per action. Looping clips stay
in that pose; transient clips move from the base pose to the key pose.
"""

from pathlib import Path

from PIL import Image

from build_generic_characters import make_mask


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "characters" / "actions" / "source"
OUTPUT = SOURCE.parent
CELL = (32, 48)
ACTION_COUNT = 4
FRAMES_PER_ACTION = 4

ACTION_BASE_DIRECTIONS = {
    "amelia": (1, 3, 2, 3),
    "sailor": (0, 3, 3, 3),
    "rake": (0, 0, 0, 0),
    "glamorous": (0, 3, 0, 0),
    "matron": (1, 0, 1, 3),
}
LOOPING_ACTIONS = {
    "amelia": {2},
    "sailor": {0, 1, 2},
    "rake": {0, 1},
    "glamorous": {0},
    "matron": {0, 1, 3},
}


def action_clip(name: str, index: int, base: Image.Image, key: Image.Image) -> tuple[Image.Image, ...]:
    if index in LOOPING_ACTIONS[name]:
        return (key, shifted(key, -1), key, shifted(key, -1))
    return (base, key, shifted(key, -1), key)


def key_pose(source: Image.Image, index: int) -> Image.Image:
    column_width = source.width // ACTION_COUNT
    face = source.crop((index * column_width, 0, (index + 1) * column_width, source.height))
    alpha = face.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError(f"Missing action pose {index}")
    face = face.crop(bounds)
    scale = min(30 / face.width, 46 / face.height)
    face = face.resize((max(1, round(face.width * scale)), max(1, round(face.height * scale))), Image.Resampling.LANCZOS)
    face.putalpha(face.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    cell = Image.new("RGBA", CELL)
    cell.alpha_composite(face, ((CELL[0] - face.width) // 2, CELL[1] - face.height))
    remove_small_alpha_components(cell)
    return cell


def remove_small_alpha_components(cell: Image.Image) -> None:
    """Discard detached alert marks and generation flecks around key poses."""
    seen: set[tuple[int, int]] = set()
    for y in range(CELL[1]):
        for x in range(CELL[0]):
            if (x, y) in seen or cell.getpixel((x, y))[3] == 0:
                continue
            component: list[tuple[int, int]] = []
            queue = [(x, y)]
            seen.add((x, y))
            for px, py in queue:
                component.append((px, py))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = px + dx, py + dy
                        if (0 <= nx < CELL[0] and 0 <= ny < CELL[1]
                                and (nx, ny) not in seen and cell.getpixel((nx, ny))[3] != 0):
                            seen.add((nx, ny))
                            queue.append((nx, ny))
            if len(component) < 8:
                for px, py in component:
                    cell.putpixel((px, py), (0, 0, 0, 0))


def shifted(image: Image.Image, dy: int) -> Image.Image:
    result = Image.new(image.mode, CELL)
    result.paste(image, (0, dy))
    return result


def build(name: str) -> None:
    source = Image.open(SOURCE / f"{name}.png").convert("RGBA")
    original_name = ("player_sprites.png" if name == "amelia" else
                     "generic/sailor_sprites.png" if name == "sailor" else
                     f"{name}_sprites.png")
    original = Image.open(ROOT / "assets" / "characters" / original_name).convert("RGBA")
    key_poses = [key_pose(source, index) for index in range(ACTION_COUNT)]
    sheet = Image.new("RGBA", (CELL[0] * ACTION_COUNT * FRAMES_PER_ACTION, CELL[1]))
    for action_index, direction in enumerate(ACTION_BASE_DIRECTIONS[name]):
        base = original.crop((0, direction * CELL[1], CELL[0], (direction + 1) * CELL[1]))
        key = key_poses[action_index]
        clip = action_clip(name, action_index, base, key)
        for frame_index, pose in enumerate(clip):
            sheet.alpha_composite(pose, ((action_index * FRAMES_PER_ACTION + frame_index) * CELL[0], 0))
    sheet.save(OUTPUT / f"{name}_actions.png", optimize=True)
    if name == "sailor":
        # Match the exact action-frame geometry for the sailor's skin tint.
        static_mask = Image.open(ROOT / "assets" / "characters" / "generic" /
                                 "sailor_sprites_mask.png").convert("RGB")
        key_strip = Image.new("RGBA", (CELL[0] * ACTION_COUNT, CELL[1]))
        for index, pose in enumerate(key_poses):
            key_strip.alpha_composite(pose, (index * CELL[0], 0))
        key_mask, _, _ = make_mask("sailor", key_strip)
        mask_sheet = Image.new("RGB", sheet.size)
        for action_index, direction in enumerate(ACTION_BASE_DIRECTIONS[name]):
            base_mask = static_mask.crop((0, direction * CELL[1], CELL[0], (direction + 1) * CELL[1]))
            key = key_mask.crop((action_index * CELL[0], 0, (action_index + 1) * CELL[0], CELL[1]))
            clip = action_clip(name, action_index, base_mask, key)
            for frame_index, pose in enumerate(clip):
                mask_sheet.paste(pose, ((action_index * FRAMES_PER_ACTION + frame_index) * CELL[0], 0))
        mask_sheet.save(OUTPUT / "sailor_actions_mask.png", optimize=True)
    print(OUTPUT / f"{name}_actions.png")


if __name__ == "__main__":
    for subject in ACTION_BASE_DIRECTIONS:
        build(subject)
    preview = Image.new("RGBA", (CELL[0] * ACTION_COUNT * FRAMES_PER_ACTION * 4,
                                  CELL[1] * len(ACTION_BASE_DIRECTIONS) * 4), "#1b202c")
    for row, subject in enumerate(ACTION_BASE_DIRECTIONS):
        strip = Image.open(OUTPUT / f"{subject}_actions.png").convert("RGBA")
        preview.alpha_composite(strip.resize((strip.width * 4, strip.height * 4),
                                             Image.Resampling.NEAREST),
                                (0, row * CELL[1] * 4))
    preview.save(OUTPUT / "action_preview.png", optimize=True)
