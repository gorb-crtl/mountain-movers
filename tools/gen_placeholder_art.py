#!/usr/bin/env python3
"""Generates the placeholder pixel art in assets/sprites/.

Real art can simply overwrite these PNGs (keep the file names). Sizes can
change too; the game scales sprites by fixed factors, so tweak those in code
if new art is much bigger.

Usage: python3 tools/gen_placeholder_art.py   (needs Pillow)
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"

PALETTE = {
    ".": (0, 0, 0, 0),
    "k": (34, 26, 22, 255),     # outline
    "s": (241, 194, 125, 255),  # skin
    "S": (210, 155, 95, 255),   # skin shade
    "g": (150, 150, 150, 255),  # grey hair
    "y": (20, 20, 30, 255),     # sunglasses
    "m": (140, 50, 50, 255),    # mouth
    "c": (139, 69, 19, 255),    # cigar
    "o": (255, 120, 0, 255),    # ember / vest
    "b": (47, 59, 89, 255),     # suit
    "B": (30, 38, 60, 255),     # suit shade
    "w": (245, 245, 245, 255),  # shirt
    "r": (200, 40, 40, 255),    # tie / dynamite
    "R": (150, 25, 25, 255),    # dynamite shade
    "p": (28, 32, 48, 255),     # trousers
    "e": (15, 15, 15, 255),     # shoes
    "h": (250, 205, 30, 255),   # hard hat
    "H": (205, 160, 10, 255),   # hard hat shade
    "v": (255, 140, 20, 255),   # safety vest
    "j": (60, 90, 160, 255),    # jeans
    "W": (150, 100, 50, 255),   # wood
    "i": (170, 175, 185, 255),  # iron
    "f": (255, 230, 120, 255),  # fuse spark
    "G": (120, 200, 90, 255),   # grass
    "D": (125, 128, 135, 255),  # rock
    "d": (90, 92, 100, 255),    # rock shade
}

BOSS = [
    "......kkkkkk........",
    ".....kssssssk.......",
    "....kssssssssk......",
    "....kgssssssgk......",
    "....kyyyyyyyyk......",
    "....ksyyssyysk......",
    "....kssssSsssk......",
    "....ksskmmksskccco..",
    ".....kssssssk.......",
    "......kkwwkk........",
    "....kkbbwrwbbkk.....",
    "...kbbbbwrwbbbbkkkk.",
    "...kbbbbbrbbbbbbbbsk",
    "...kbbbbbrbbbbkkkksk",
    "...kbkbbbrbbbk...kk.",
    "...kbkbbbbbbbk......",
    "...kskBbbbbbbk......",
    "....k.kbbbbbbk......",
    "......kppppppk......",
    "......kppkkppk......",
    "......kppk.kppk.....",
    "......kppk.kppk.....",
    ".....keeek.keeek....",
    ".....kkkkk.kkkkk....",
]

WORKER = [
    "...kkkk.....",
    "..khhhhk..W.",
    ".khhhhhhk.Wi",
    "kHHHHHHHHkWi",
    "..ksssssk.W.",
    "..ksksksk.W.",
    "..kssssskkW.",
    ".kvvovvvkssk",
    ".kvvovvvk.k.",
    "..kjjjjjk...",
    "..kjk.kjk...",
    "..kek.kek...",
]

DYNAMITE = [
    "...f..",
    "..fk..",
    "...k..",
    ".kkkk.",
    "krrrRk",
    "krrrRk",
    "kwwwwk",
    "krrrRk",
    "krrrRk",
    "krrrRk",
    ".kkkk.",
]

HAND = [
    ".kk.........",
    "kssk........",
    "kssk........",
    "ksskkkk.....",
    "ksskssskk...",
    "ksssssssskk.",
    "kssssssssssk",
    "kssssssssssk",
    ".ksssssssssk",
    "..kssssssSk.",
    "...kssssSk..",
    "....kkkkk...",
]


def icon():
    size = 32
    rows = []
    for y in range(size):
        row = ""
        for x in range(size):
            peak = 16
            height = 26 - abs(x - peak) * 1.4
            top = size - 1 - height
            if y >= 29:
                row += "G" if y == 29 else "W"
            elif y >= top:
                row += "d" if (x + y) % 5 == 0 else ("k" if y - top < 1 else "D")
            else:
                row += "."
        rows.append(row)
    return rows


def save(name, rows, scale=1):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row.ljust(w, ".")):
            img.putpixel((x, y), PALETTE[ch])
    if scale != 1:
        img = img.resize((w * scale, len(rows) * scale), Image.NEAREST)
    img.save(OUT / name)
    print("wrote", OUT / name)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    save("boss.png", BOSS)
    save("worker.png", WORKER)
    save("dynamite.png", DYNAMITE)
    save("cursor_hand.png", HAND, 2)
    save("icon.png", icon(), 4)
