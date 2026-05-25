#!/usr/bin/env python3
"""Generate PhytoNote launcher icon — erlenmeyer + feuille botanique, palette du thème."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
OUT_DIR = Path(__file__).resolve().parent.parent / "app" / "assets" / "icon"
OUT_DIR.mkdir(parents=True, exist_ok=True)

PRIMARY = (46, 93, 60)
PRIMARY_DARK = (31, 65, 40)
SAND = (250, 247, 242)
ACCENT = (164, 113, 72)
LEAF_LIGHT = (145, 195, 145)
LEAF_DARK = (62, 124, 80)
LIQUID_TOP = (140, 200, 150)
LIQUID_BOT = (90, 160, 110)


def rounded_square(size: int, radius: int, fill) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=fill)
    return img


def leaf_shape(cx: float, cy: float, length: float, width: float, angle_deg: float, fill) -> Image.Image:
    """Pointed-oval leaf, rotated."""
    pad = int(length * 1.6)
    canvas = Image.new("RGBA", (pad, pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    cxp, cyp = pad // 2, pad // 2
    pts = []
    n = 64
    for i in range(n):
        t = i / (n - 1) * math.pi * 2
        # leaf outline: x = sin(t) * width, y modulated by cos(t)*length, but tapered
        x = math.sin(t) * width * (1 - 0.0)
        # cos(t) goes from 1 to -1; map to length but taper at both ends
        y = math.cos(t) * length / 2
        # taper width at the tips
        taper = math.cos(t) ** 2
        x *= 1 - 0.5 * taper
        pts.append((cxp + x, cyp + y))
    d.polygon(pts, fill=fill)
    rotated = canvas.rotate(angle_deg, resample=Image.BICUBIC, expand=True)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rw, rh = rotated.size
    out.paste(rotated, (int(cx - rw / 2), int(cy - rh / 2)), rotated)
    return out


def make_icon(with_background: bool = True) -> Image.Image:
    if with_background:
        bg = rounded_square(SIZE, 220, PRIMARY)
        depth = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        dd = ImageDraw.Draw(depth)
        dd.ellipse((-180, 380, SIZE + 180, SIZE + 380), fill=(0, 0, 0, 50))
        depth = depth.filter(ImageFilter.GaussianBlur(60))
        bg = Image.alpha_composite(bg, depth)
    else:
        bg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    cx = SIZE // 2

    # Erlenmeyer flask
    neck_w = 130
    neck_top = 360
    shoulder = 540
    body_bottom = 880
    body_w_bottom = 540

    # body trapezoid + neck rectangle (one polygon)
    flask = [
        (cx - neck_w // 2, neck_top),
        (cx + neck_w // 2, neck_top),
        (cx + neck_w // 2, shoulder),
        (cx + body_w_bottom // 2, body_bottom - 36),
        (cx + body_w_bottom // 2 - 26, body_bottom),
        (cx - body_w_bottom // 2 + 26, body_bottom),
        (cx - body_w_bottom // 2, body_bottom - 36),
        (cx - neck_w // 2, shoulder),
    ]
    d.polygon(flask, fill=SAND)

    # rim (slightly wider at neck top)
    rim = [
        (cx - neck_w // 2 - 26, neck_top - 12),
        (cx + neck_w // 2 + 26, neck_top - 12),
        (cx + neck_w // 2 + 26, neck_top + 26),
        (cx - neck_w // 2 - 26, neck_top + 26),
    ]
    d.polygon(rim, fill=SAND)

    # liquid filling the lower 55% of the body (vertical gradient)
    liquid_top_y = 700
    liquid_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ld = ImageDraw.Draw(liquid_layer)
    # interpolate the body width at y
    def body_width(y: int) -> int:
        # neck (between neck_top and shoulder) constant
        if y < shoulder:
            return neck_w
        # linear from neck_w at shoulder to body_w_bottom at body_bottom-36
        t = (y - shoulder) / (body_bottom - 36 - shoulder)
        t = max(0.0, min(1.0, t))
        return int(neck_w + t * (body_w_bottom - neck_w))

    inset = 22
    for y in range(liquid_top_y, body_bottom - 16):
        w = max(0, body_width(y) - inset)
        t = (y - liquid_top_y) / (body_bottom - 16 - liquid_top_y)
        r = int(LIQUID_TOP[0] + (LIQUID_BOT[0] - LIQUID_TOP[0]) * t)
        g = int(LIQUID_TOP[1] + (LIQUID_BOT[1] - LIQUID_TOP[1]) * t)
        b = int(LIQUID_TOP[2] + (LIQUID_BOT[2] - LIQUID_TOP[2]) * t)
        ld.rectangle((cx - w // 2, y, cx + w // 2, y + 1), fill=(r, g, b, 235))
    # subtle highlight on the surface of the liquid
    ld.ellipse((cx - 110, liquid_top_y + 4, cx - 30, liquid_top_y + 26), fill=(255, 255, 255, 90))
    layer = Image.alpha_composite(layer, liquid_layer)

    # graduations (dark ticks on the right of the body)
    d2 = ImageDraw.Draw(layer)
    grad_x_right = cx + 80
    for y in [600, 660, 720, 780]:
        d2.rectangle((grad_x_right, y - 4, grad_x_right + 46, y + 4), fill=PRIMARY_DARK)

    # Outline of the flask, drawn last so it sits on top of liquid
    d2.line(
        [
            (cx - neck_w // 2 - 26, neck_top - 12),
            (cx - neck_w // 2 - 26, neck_top + 26),
            (cx - neck_w // 2, neck_top + 26),
            (cx - neck_w // 2, shoulder),
            (cx - body_w_bottom // 2, body_bottom - 36),
            (cx - body_w_bottom // 2 + 26, body_bottom),
            (cx + body_w_bottom // 2 - 26, body_bottom),
            (cx + body_w_bottom // 2, body_bottom - 36),
            (cx + neck_w // 2, shoulder),
            (cx + neck_w // 2, neck_top + 26),
            (cx + neck_w // 2 + 26, neck_top + 26),
            (cx + neck_w // 2 + 26, neck_top - 12),
            (cx - neck_w // 2 - 26, neck_top - 12),
        ],
        fill=PRIMARY_DARK,
        width=10,
        joint="curve",
    )

    # Two leaves rising from the neck
    leaf_left = leaf_shape(cx - 110, 240, length=320, width=130, angle_deg=-32, fill=LEAF_DARK)
    leaf_right = leaf_shape(cx + 130, 220, length=340, width=140, angle_deg=28, fill=LEAF_LIGHT)
    layer = Image.alpha_composite(layer, leaf_left)
    layer = Image.alpha_composite(layer, leaf_right)

    # Stems
    d3 = ImageDraw.Draw(layer)
    d3.line([(cx - 10, neck_top - 10), (cx - 200, 130)], fill=PRIMARY_DARK, width=10)
    d3.line([(cx + 10, neck_top - 10), (cx + 220, 110)], fill=PRIMARY_DARK, width=10)

    return Image.alpha_composite(bg, layer)


def main() -> None:
    icon = make_icon(with_background=True)
    icon.save(OUT_DIR / "icon.png")
    fg = make_icon(with_background=False)
    fg.save(OUT_DIR / "icon_foreground.png")
    print(f"Wrote {OUT_DIR / 'icon.png'} and icon_foreground.png")


if __name__ == "__main__":
    main()
