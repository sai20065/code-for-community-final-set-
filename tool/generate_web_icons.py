"""Regenerates web/favicon.png and web/icons/* from assets/icon/logo.png.

`flutter_launcher_icons` handles Android from the same source art (see
flutter_launcher_icons-android.yaml), but nothing in this repo kept the web
icon set in sync — they were generated once by hand and then drifted several
logo revisions behind. This script closes that gap.

Run after replacing assets/icon/logo.png:

    pip install Pillow
    python tool/generate_web_icons.py

Requires a square source image, ideally 1024x1024 with transparency.
"""
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "icon" / "logo.png"

# AppColors.paper — matches manifest.json's background_color. Transparent
# PNGs render on whatever the browser chrome happens to be, which is black in
# dark mode; flattening onto the brand background keeps the mark legible.
BACKGROUND = (243, 242, 238, 255)

# Maskable icons get cropped to a circle or squircle by the launcher, so the
# artwork sits inside the 72% safe zone rather than filling the canvas.
MASKABLE_SAFE_ZONE = 0.72


def flatten(image: Image.Image) -> Image.Image:
    canvas = Image.new("RGBA", image.size, BACKGROUND)
    return Image.alpha_composite(canvas, image)


def main() -> int:
    if not SOURCE.exists():
        print(f"No source art at {SOURCE}", file=sys.stderr)
        return 1

    source = Image.open(SOURCE).convert("RGBA")
    if source.width != source.height:
        print(
            f"Source is {source.width}x{source.height}; a square image is "
            "required or the icons will be distorted.",
            file=sys.stderr,
        )
        return 1

    icons_dir = ROOT / "web" / "icons"
    icons_dir.mkdir(parents=True, exist_ok=True)

    for size in (192, 512):
        resized = source.resize((size, size), Image.LANCZOS)
        flatten(resized).convert("RGB").save(icons_dir / f"Icon-{size}.png")

        canvas = Image.new("RGBA", (size, size), BACKGROUND)
        inner = int(size * MASKABLE_SAFE_ZONE)
        offset = (size - inner) // 2
        canvas.alpha_composite(
            source.resize((inner, inner), Image.LANCZOS), (offset, offset)
        )
        canvas.convert("RGB").save(icons_dir / f"Icon-maskable-{size}.png")

    favicon = source.resize((64, 64), Image.LANCZOS)
    flatten(favicon).convert("RGB").save(ROOT / "web" / "favicon.png")

    print("Regenerated web/favicon.png and web/icons/*.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
