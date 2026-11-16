#!/usr/bin/env python3
"""Generates the placeholder pixel art in assets/sprites/.

Everything in the world is drawn at the mountain's pixel size: one pixel of a
sprite = one mountain pixel (Game.CELL world units). Keep that rule when making
real art and it'll all match. Overwrite a PNG (same name) to replace it.

boss.png is a strip of 3 frames (idle, walk 1, walk 2), each 20x24.

Usage: python3 tools/gen_placeholder_art.py   (needs Pillow)
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parent.parent / "assets" / "sprites"

PALETTE = {
    ".": (0, 0, 0, 0),
    "k": (24, 20, 26, 255),     # outline
    "K": (24, 20, 26, 255),
    "s": (236, 188, 140, 255),  # skin
    "S": (200, 150, 105, 255),  # skin shade
    "g": (150, 150, 150, 255),  # grey hair / wheel hub
    "y": (20, 20, 30, 255),     # sunglasses
    "m": (140, 50, 50, 255),    # mouth
    "c": (150, 90, 45, 255),    # cigar
    "o": (255, 120, 30, 255),   # ember
    "b": (47, 59, 89, 255),     # suit
    "B": (34, 42, 66, 255),     # suit shade
    "w": (238, 234, 225, 255),  # shirt / glove
    "W": (200, 195, 185, 255),  # glove shade
    "r": (205, 55, 45, 255),    # tie / red
    "R": (150, 35, 30, 255),
    "p": (30, 34, 50, 255),     # trousers
    "e": (12, 12, 14, 255),     # shoes
    "Y": (242, 184, 60, 255),   # machine yellow
    "q": (200, 140, 40, 255),   # yellow shade
    "v": (150, 210, 250, 255),  # window
    "D": (70, 68, 78, 255),     # chassis
    "d": (110, 108, 118, 255),
    "G": (75, 95, 50, 255),     # army dark
    "a": (110, 135, 70, 255),   # army
    "t": (175, 165, 140, 255),  # tan pickup
    "T": (135, 125, 105, 255),
    "n": (120, 82, 50, 255),    # bird brown
    "N": (85, 58, 35, 255),
    "f": (255, 225, 110, 255),  # spark / beak
    "z": (95, 100, 108, 255),   # bomb grey
}


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
    return img


BOSS_TOP = [
    "......kkkkkk........",
    ".....kssssssk.......",
    "....kssssssssk......",
    "....kgssssssgk......",
    "....kyyyyyyyyk......",
    "....ksyyssyysk......",
    "....kssssSsssk......",
    "....ksssmccccccco...",   # cigar clamped in his mouth
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
]
BOSS_LEGS = [
    [
        "......kppppppk......",
        "......kppkkppk......",
        "......kppk.kppk.....",
        "......kppk.kppk.....",
        ".....keeek.keeek....",
        ".....kkkkk.kkkkk....",
    ],
    [
        "......kppppppk......",
        ".....kppkkkppk......",
        "....kppk...kppk.....",
        "...kppk.....kppk....",
        "..keeek.....keeek...",
        "..kkkkk.....kkkkk...",
    ],
    [
        "......kppppppk......",
        "......kpppppk.......",
        ".......kppppk.......",
        ".......kppppk.......",
        "......keeeeek.......",
        "......kkkkkkk.......",
    ],
]

# Dump truck, facing left (it drives off to the left). 22x11.
# Bed interior is x 9..20, rim at y 0. The load pile is drawn above it in code.
TRUCK = [
    "........KKKKKKKKKKKKKK",
    "........KYYYYYYYYYYYYK",
    "..KKKKK.KYqYYqYYqYYqYK",
    ".KYYYYYKKYqYYqYYqYYqYK",
    ".KvvYYYKKYYYYYYYYYYYYK",
    ".KvvYYYKKYqYYqYYqYYqYK",
    "KrYYYYYYKKKKKKKKKKKKKK",
    "KDDDDDDDDDDDDDDDDDDDDK",
    ".KKK.........KKK.KKK..",
    "KgDgK.......KgDgKgDgK.",
    ".KKK.........KKK.KKK..",
]

SOLDIER = [
    ".GG..",
    "Gaaa.",
    ".ss..",
    "KKKa.",
    ".aaa.",
    ".aa..",
    ".a.a.",
    ".k.k.",
]

GUNNER = [
    "..GG..",
    ".Gaaa.",
    "..ss..",
    "KKKKa.",
    "KKKaa.",
    "..aa..",
    "..a.a.",
    "..k.k.",
]

TECHNICAL = [
    "...........GG....",
    "......KKKKKKaa...",
    "...........aa....",
    "..KKKKK....K.....",
    ".KvvttK....K.....",
    "KtttttttttttttttK",
    "KTTTTTTTTTTTTTTTK",
    "KKKKKKKKKKKKKKKKK",
    ".KgK.........KgK.",
    "..K...........K..",
]

TANK = [
    "......KKKKK.......",
    "KKKKKKaaaaaK......",
    "......aaaaaaa.....",
    "..GaaaaaaaaaaaaG..",
    ".GaaaaaaaaaaaaaaG.",
    "KKKKKKKKKKKKKKKKKK",
    "KdKdKdKdKdKdKdKdKK",
    ".KKKKKKKKKKKKKKKK.",
]

BULLDOZER = [
    "........KKKK...",
    "........KvvK...",
    "........KvvK...",
    "dd.KKKKKYYYYK..",
    "dd.KYYYYYYYYYK.",
    "ddKKYYYYqYYYYK.",
    "dd.KKKKKKKKKKKK",
    "dd.KdKdKdKdKdKK",
    "....KKKKKKKKKK.",
]

BIRD = [
    "N.........N",
    "nN.......Nn",
    ".nnN...Nnn.",
    "wf.NnnnnN..",
    "...NnnnN...",
    "....f..f...",
]

GRENADE = [
    ".g.",
    "GaG",
    "aaa",
    ".G.",
]

NUKE = [
    "KzzzK",
    ".KzK.",
    ".zzz.",
    "zzzzz",
    "zYKYz",
    "zzzzz",
    ".zzz.",
    "..z..",
]

PLANE = [
    "..........K.",
    ".........Kd.",
    "KzzzzzzzzzzK",
    ".KzzzKKzzzK.",
    ".....Kz.....",
]

QUAKE = [
    "..........",
    "......o...",
    "..o..o.o..",
    ".o.oo...o.",
    "o........o",
]

# Cursor: open glove, and a closed fist for when you're holding something.
HAND = [
    ".KK.....",
    "KwwK....",
    "KwwKKK..",
    "KwwwwwKK",
    "KwwwwwwK",
    "KwWwwwwK",
    ".KWwwwK.",
    "..KKKK..",
]

FIST = [
    "........",
    ".KKKKK..",
    "KwKwKwKK",
    "KwwwwwwK",
    "KwwwwwwK",
    "KWwwwwWK",
    ".KWWWWK.",
    "..KKKK..",
]


def icon():
    size = 16
    rows = []
    for y in range(size):
        row = ""
        for x in range(size):
            height = 13 - abs(x - 8) * 1.4
            top = size - 2 - height
            if y >= 14:
                row += "k"
            elif y >= top:
                row += "Y" if y - top < 1 else ("d" if (x + y) % 4 == 0 else "D")
            else:
                row += "."
        rows.append(row)
    return rows


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    frames = [BOSS_TOP + legs for legs in BOSS_LEGS]
    sheet = [frames[0][y] + frames[1][y] + frames[2][y] for y in range(24)]
    save("boss.png", sheet)
    save("truck.png", TRUCK)
    save("soldier.png", SOLDIER)
    save("gunner.png", GUNNER)
    save("technical.png", TECHNICAL)
    save("tank.png", TANK)
    save("bulldozer.png", BULLDOZER)
    save("bird.png", BIRD)
    save("grenade.png", GRENADE)
    save("nuke.png", NUKE)
    save("airstrike.png", PLANE)
    save("quake.png", QUAKE)
    save("cursor_hand.png", HAND)
    save("cursor_fist.png", FIST)
    # Bigger copies for the OS mouse cursor over the UI.
    save("cursor_ui.png", HAND, 3)
    save("icon.png", icon(), 8)
