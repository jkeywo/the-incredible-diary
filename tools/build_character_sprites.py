"""Turn the approved four-facing character art into fixed-grid test-bed sprites.

Requires Pillow from the Codex workspace runtime. The large source PNGs are kept
so the small sprites can be regenerated without another image generation pass.
"""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "characters" / "source"
WALK_SOURCE = ROOT / "assets" / "characters" / "walk_source"
OUTPUT = ROOT / "assets" / "characters"
CELL = (32, 48)
DIRECTIONS = ("down", "left", "up", "right")
ANIMATIONS = (("idle", 2), ("walk", 4), ("talk", 3), ("bob", 4))
BACKGROUND_THRESHOLD = 32


def place(canvas: Image.Image, piece: Image.Image, x: int, y: int) -> None:
    canvas.alpha_composite(piece, (x, y))


def base_pose(source: Image.Image, view_index: int, view_count: int = 4) -> Image.Image:
    cell_width = source.width // view_count
    face = source.crop((view_index * cell_width, 0, (view_index + 1) * cell_width, source.height))
    alpha = face.getchannel("A").point(lambda value: 255 if value >= BACKGROUND_THRESHOLD else 0)
    face.putalpha(alpha)
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("Missing character facing")
    face = face.crop(bounds)
    scale = min(30 / face.width, 46 / face.height)
    face = face.resize((max(1, round(face.width * scale)), max(1, round(face.height * scale))), Image.Resampling.LANCZOS)
    face.putalpha(face.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
    result = Image.new("RGBA", CELL)
    place(result, face, (CELL[0] - face.width) // 2, CELL[1] - face.height)
    return result


def shifted(base: Image.Image, dy: int) -> Image.Image:
    result = Image.new("RGBA", CELL)
    place(result, base, 0, dy)
    return result


def walk_pose(base: Image.Image, direction: int, phase: int, skirt: bool) -> Image.Image:
    # Keep the torso on one axis. Side views stride left/right; front and back
    # views alternate foot depth without stepping sideways. Skirts keep their
    # silhouette and move only the shoes.
    split_y = 42 if skirt else 35
    result = Image.new("RGBA", CELL)
    place(result, base.crop((0, 0, 32, split_y)), 0, -int(phase in (1, 3)))
    left = base.crop((0, split_y, 16, 48))
    right = base.crop((16, split_y, 32, 48))
    if direction in (1, 3):
        stride = (-2, 0, 2, 0)[phase]
        if skirt:
            stride = max(-1, min(1, stride))
        place(result, left, stride, split_y - int(phase == 1))
        place(result, right, 16 - stride, split_y - int(phase == 3))
    else:
        foot_lift = (0, 1, 2, 1)[phase]
        place(result, left, 0, split_y - foot_lift)
        place(result, right, 16, split_y - (2 - foot_lift))
    return result


def talk_pose(base: Image.Image, direction: int, phase: int) -> Image.Image:
    result = shifted(base, -int(phase == 1))
    if phase == 1 and direction != 2:
        # A tiny mouth change is readable at native size; the back view gestures.
        mouths = ((15, 17), (8, 17), None, (22, 17))
        x, y = mouths[direction]
        result.putpixel((x, y), (52, 30, 36, 255))
        result.putpixel((x + 1, y), (52, 30, 36, 255))
    return result


def bob_pose(base: Image.Image, phase: int) -> Image.Image:
    return shifted(base, (0, 1, -1, 0)[phase])


def build_sheet(source_path: Path) -> None:
    source = Image.open(source_path).convert("RGBA")
    walk_source = Image.open(WALK_SOURCE / source_path.name).convert("RGBA")
    skirt = source_path.stem in ("glamorous", "matron")
    columns = sum(count for _, count in ANIMATIONS)
    sheet = Image.new("RGBA", (CELL[0] * columns, CELL[1] * len(DIRECTIONS)))
    for direction in range(4):
        base = base_pose(source, direction)
        walk_base = base
        if direction in (1, 3):
            # Stationary side views retain their slight turn toward the camera.
            # Walking uses a true profile to read as straight horizontal travel.
            walk_base = base_pose(walk_source, 0 if direction == 1 else 1, 2)
        frames = [base, shifted(base, -1)]
        frames += [walk_pose(walk_base, direction, phase, skirt) for phase in range(4)]
        frames += [talk_pose(base, direction, phase) for phase in range(3)]
        frames += [bob_pose(base, phase) for phase in range(4)]
        for column, frame in enumerate(frames):
            place(sheet, frame, column * CELL[0], direction * CELL[1])
    destination = OUTPUT / f"{source_path.stem}_sprites.png"
    sheet.save(destination, optimize=True)
    print(destination.relative_to(ROOT))


if __name__ == "__main__":
    for path in sorted(SOURCE.glob("*.png")):
        build_sheet(path)
