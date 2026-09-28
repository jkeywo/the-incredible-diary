"""Build the fixed-grid open/closed valve prop from its generated source art."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "props" / "source" / "valve.png"
DESTINATION = ROOT / "assets" / "props" / "valve_states.png"
CELL = (32, 48)


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    width = source.width // 2
    sheet = Image.new("RGBA", (CELL[0] * 2, CELL[1]))
    for state in range(2):
        art = source.crop((state * width, 0, (state + 1) * width, source.height))
        alpha = art.getchannel("A").point(lambda value: 255 if value >= 32 else 0)
        art.putalpha(alpha)
        bounds = alpha.getbbox()
        if bounds is None:
            raise ValueError("Missing valve state")
        art = art.crop(bounds)
        scale = min(30 / art.width, 46 / art.height)
        art = art.resize((round(art.width * scale), round(art.height * scale)), Image.Resampling.LANCZOS)
        art.putalpha(art.getchannel("A").point(lambda value: 255 if value >= 128 else 0))
        sheet.alpha_composite(art, (state * CELL[0] + (CELL[0] - art.width) // 2, CELL[1] - art.height))
    sheet.save(DESTINATION, optimize=True)
    print(DESTINATION.relative_to(ROOT))


if __name__ == "__main__":
    main()
