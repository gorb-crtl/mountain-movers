#!/usr/bin/env python3
"""Generates the placeholder pixel art in assets/sprites/.

Real art can simply overwrite these PNGs (keep the file names). Sizes can
change too; the game scales sprites by fixed factors, so tweak those in code
if new art is much bigger.

Usage: python3 tools/gen_placeholder_art.py   (needs Pillow)
"""
from pathlib import Path
from PIL import Image, ImageDraw

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


K = (34, 26, 22, 255)


def canvas(w, h):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def box(d, xy, fill, outline=K):
    d.rectangle(xy, fill=fill, outline=outline)


def wheel(d, cx, cy, r):
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(25, 25, 25, 255), outline=K)
    d.rectangle((cx - 1, cy - 1, cx + 1, cy + 1), fill=(150, 150, 150, 255))


def truck():
    # Dump truck facing left (it drives off to the left). Bed is x 16..47, y 4..15.
    img, d = canvas(48, 25)
    yellow, shade = (250, 200, 30, 255), (200, 150, 10, 255)
    box(d, (16, 4, 47, 15), yellow)
    for x in range(20, 46, 6):
        d.line((x, 5, x, 14), fill=shade)
    box(d, (2, 6, 15, 15), yellow)
    box(d, (4, 8, 10, 11), (150, 210, 255, 255))
    box(d, (0, 15, 47, 18), (70, 70, 75, 255))
    box(d, (0, 12, 2, 15), (220, 60, 40, 255))
    wheel(d, 9, 20, 4)
    wheel(d, 34, 20, 4)
    wheel(d, 42, 20, 4)
    return img


def soldier(gun_len=6, gun=(50, 50, 50, 255), big=False):
    img, d = canvas(14, 16)
    green, dark = (90, 120, 60, 255), (60, 85, 40, 255)
    box(d, (5, 0, 10, 2), dark)                          # helmet
    box(d, (6, 3, 9, 5), (241, 194, 125, 255), None)     # face
    d.point((6, 4), fill=K)
    box(d, (5, 6, 10, 11), green)                        # body
    box(d, (5, 12, 6, 15), dark, None)                   # legs
    box(d, (9, 12, 10, 15), dark, None)
    y = 8
    d.rectangle((6 - gun_len, y, 8, y + (2 if big else 1)), fill=gun)  # gun pointing left
    return img


def technical():
    img, d = canvas(42, 26)
    body, shade = (170, 165, 150, 255), (120, 115, 105, 255)
    box(d, (0, 12, 41, 19), body)           # truck body (cab on the left)
    box(d, (2, 6, 14, 12), body)            # cab
    box(d, (4, 8, 9, 11), (150, 210, 255, 255))
    d.line((16, 12, 41, 12), fill=shade)
    box(d, (26, 6, 29, 11), (60, 60, 60, 255))   # mount
    box(d, (12, 5, 30, 7), (40, 40, 40, 255))    # .50 cal barrel pointing left
    box(d, (30, 2, 35, 11), (90, 120, 60, 255))  # gunner
    box(d, (30, 0, 35, 2), (60, 85, 40, 255))
    wheel(d, 8, 21, 4)
    wheel(d, 33, 21, 4)
    return img


def tank():
    img, d = canvas(44, 22)
    green, dark = (95, 115, 60, 255), (65, 80, 40, 255)
    box(d, (2, 12, 41, 20), (50, 50, 50, 255))   # tracks
    for x in range(6, 40, 7):
        wheel(d, x, 17, 2)
    box(d, (0, 8, 43, 12), green)                # hull
    box(d, (14, 2, 32, 8), green)                # turret
    d.line((0, 4, 14, 5), fill=dark, width=2)    # barrel pointing left
    box(d, (22, 0, 26, 2), dark)
    return img


def bulldozer():
    img, d = canvas(40, 24)
    yellow, shade = (250, 190, 20, 255), (190, 140, 10, 255)
    box(d, (0, 4, 4, 21), (120, 120, 120, 255))     # blade on the left
    d.line((4, 12, 10, 14), fill=K, width=2)        # arm
    box(d, (10, 8, 33, 16), yellow)                  # body
    box(d, (22, 0, 33, 8), yellow)                   # cab
    box(d, (24, 2, 31, 6), (150, 210, 255, 255))
    d.line((12, 9, 20, 9), fill=shade)
    box(d, (8, 16, 37, 23), (40, 40, 40, 255))      # tracks
    for x in range(12, 36, 6):
        wheel(d, x, 19, 2)
    return img


def bird():
    img, d = canvas(28, 16)
    brown, dark = (120, 80, 45, 255), (80, 50, 25, 255)
    d.polygon([(0, 2), (12, 7), (16, 7), (27, 0), (20, 9), (8, 9)], fill=brown, outline=K)  # wings
    box(d, (9, 6, 17, 10), dark)                 # body
    box(d, (4, 5, 9, 8), (240, 240, 240, 255))   # white head
    d.point((5, 6), fill=K)
    d.polygon([(2, 7), (4, 6), (4, 8)], fill=(250, 200, 30, 255))  # beak
    d.line((11, 11, 10, 14), fill=(250, 200, 30, 255))  # talons
    d.line((15, 11, 16, 14), fill=(250, 200, 30, 255))
    return img


def grenade():
    img, d = canvas(8, 10)
    d.ellipse((0, 2, 7, 9), fill=(80, 110, 50, 255), outline=K)
    box(d, (3, 0, 5, 2), (150, 150, 150, 255))
    d.line((5, 1, 7, 0), fill=(150, 150, 150, 255))
    return img


def nuke():
    img, d = canvas(12, 20)
    d.ellipse((0, 4, 11, 19), fill=(90, 95, 100, 255), outline=K)
    d.polygon([(2, 4), (9, 4), (11, 0), (0, 0)], fill=(70, 70, 75, 255), outline=K)
    box(d, (3, 10, 8, 13), (250, 210, 30, 255))
    d.point((5, 11), fill=K)
    return img


def earthquake():
    img, d = canvas(16, 12)
    d.line([(0, 8), (3, 4), (6, 9), (9, 2), (12, 8), (15, 5)], fill=(200, 120, 40, 255), width=2)
    return img


def plane():
    img, d = canvas(24, 10)
    box(d, (2, 3, 21, 6), (120, 130, 140, 255))
    d.polygon([(8, 4), (14, 4), (10, 9)], fill=(90, 100, 110, 255))
    d.polygon([(18, 3), (23, 0), (21, 3)], fill=(90, 100, 110, 255))
    return img


def save_img(name, img):
    img.save(OUT / name)
    print("wrote", OUT / name)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    save("boss.png", BOSS)
    save_img("truck.png", truck())
    save_img("soldier.png", soldier())
    save_img("gunner.png", soldier(gun_len=8, gun=(30, 30, 30, 255), big=True))
    save_img("technical.png", technical())
    save_img("tank.png", tank())
    save_img("bulldozer.png", bulldozer())
    save_img("bird.png", bird())
    save_img("grenade.png", grenade())
    save_img("nuke.png", nuke())
    save_img("quake.png", earthquake())
    save_img("airstrike.png", plane())
    save("cursor_hand.png", HAND, 2)
    save("icon.png", icon(), 4)
