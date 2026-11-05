"""Puts the real app screenshots (captured on an Android emulator) into a
simple phone frame for the concept document.

    python docs/concept/frame_screens.py
"""
import pathlib

from PIL import Image, ImageDraw

HERE = pathlib.Path(__file__).parent
SRC = HERE / "assets" / "screens"
OUT = HERE / "assets" / "screens_framed"

SCREENS = [
    "01_welcome", "02_signup", "03_language", "04_location", "05_profile_reveal",
    "06b_home_active", "07_compose_top", "08_compose_bottom", "10_my_reports",
    "11_report_detail", "13_public_dashboard", "14_districts", "15_bengaluru_wards",
    "16_bbmp_map",
]


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius, fill=255)
    return mask


def frame(name):
    shot = Image.open(SRC / f"{name}.png").convert("RGB").resize((540, 1170), Image.LANCZOS)
    pad, bezel_r, screen_r = 18, 64, 46
    w, h = shot.width + pad * 2, shot.height + pad * 2
    out = Image.new("RGBA", (w + 8, h + 8), (0, 0, 0, 0))
    body = Image.new("RGBA", (w, h), (24, 24, 32, 255))
    out.paste(body, (4, 4), rounded_mask((w, h), bezel_r))
    out.paste(shot, (4 + pad, 4 + pad), rounded_mask(shot.size, screen_r))
    # A subtle camera dot in the status-bar area.
    ImageDraw.Draw(out).ellipse((4 + w / 2 - 7, 4 + pad + 10, 4 + w / 2 + 7, 4 + pad + 24), fill=(10, 10, 14, 255))
    bg = Image.new("RGB", out.size, "white")
    bg.paste(out, mask=out.split()[3])
    bg.save(OUT / f"{name}.png", optimize=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in SCREENS:
        frame(name)
        print("framed", name)


if __name__ == "__main__":
    main()
