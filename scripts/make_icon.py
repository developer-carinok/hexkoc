#!/usr/bin/env python3
"""HexKoç uygulama simgesini üretir.

Koyu lacivert zemin, altın renkli sivri tepeli altıgen çerçeve ve içinde
daha küçük dolu bir altıgen. 1024x1024, alfa kanalı yok (App Store şartı).

Kullanım:
    .venv-icon/bin/python scripts/make_icon.py
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
SUPERSAMPLE = 4  # kenarlar pürüzsüz olsun diye büyük çizip küçültüyoruz

BACKGROUND = (10, 15, 30)      # #0A0F1E
BACKGROUND_TOP = (28, 37, 64)  # #1C2540 — hafif dikey geçiş
GOLD = (201, 165, 90)          # #C9A55A
GOLD_DIM = (140, 112, 58)

OUT = Path(__file__).resolve().parents[1] / "Assets.xcassets" / "AppIcon.appiconset" / "icon-1024.png"


def hexagon(cx: float, cy: float, radius: float) -> list[tuple[float, float]]:
    """Sivri tepeli (pointy-top) altıgenin köşe noktaları."""
    return [
        (
            cx + radius * math.cos(math.radians(60 * i - 90)),
            cy + radius * math.sin(math.radians(60 * i - 90)),
        )
        for i in range(6)
    ]


def main() -> None:
    s = SIZE * SUPERSAMPLE
    img = Image.new("RGB", (s, s), BACKGROUND)
    draw = ImageDraw.Draw(img)

    # Yumuşak dikey geçiş: üstte biraz daha açık.
    for y in range(s):
        t = (y / s) ** 1.4
        draw.line(
            [(0, y), (s, y)],
            fill=tuple(
                round(BACKGROUND_TOP[c] + (BACKGROUND[c] - BACKGROUND_TOP[c]) * t)
                for c in range(3)
            ),
        )

    cx = cy = s / 2
    outer = s * 0.34
    inner = s * 0.175

    draw.polygon(hexagon(cx, cy, outer), outline=GOLD, width=round(s * 0.028))
    draw.polygon(hexagon(cx, cy, outer * 0.78), outline=GOLD_DIM, width=round(s * 0.008))
    draw.polygon(hexagon(cx, cy, inner), fill=GOLD)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT, "PNG")
    print(f"✓ {OUT} ({img.mode}, {img.size[0]}x{img.size[1]})")


if __name__ == "__main__":
    main()
