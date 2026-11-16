#!/usr/bin/env python3
"""Generates 16x16 placeholder upgrade icons into assets/icons/<upgrade id>.png.

Each upgrade, military unit, item and perk in scripts/data/upgrades.gd has an
icon with the same id. Replace any PNG with real art (any size; the UI scales it).
Usage: python3 tools/gen_icons.py   (needs Pillow)
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "icons"
SPRITES = ROOT / "assets" / "sprites"

K = (20, 18, 24, 255)
SKIN = (236, 188, 140, 255)
AMBER = (242, 184, 75, 255)
GOLD = (255, 214, 90, 255)
GREEN = (120, 200, 110, 255)
ARMY = (110, 140, 70, 255)
GREY = (150, 150, 160, 255)
DARK = (80, 80, 90, 255)
RED = (220, 70, 60, 255)
BLUE = (90, 170, 240, 255)
BROWN = (150, 100, 60, 255)
WHITE = (240, 236, 225, 255)
CYAN = (90, 230, 215, 255)
PURPLE = (190, 120, 240, 255)


def new():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def from_sprite(name):
    """Fits an existing sprite into a 16x16 icon."""
    src = Image.open(SPRITES / name).convert("RGBA")
    if name == "boss.png":
        src = src.crop((0, 0, 20, 24))
    bbox = src.getbbox()
    src = src.crop(bbox)
    scale = min(16 / src.width, 16 / src.height)
    if scale >= 1:
        scale = int(scale)
        src = src.resize((src.width * scale, src.height * scale), Image.NEAREST)
    else:
        src = src.resize((max(1, round(src.width * scale)), max(1, round(src.height * scale))), Image.NEAREST)
    img, _ = new()
    img.paste(src, ((16 - src.width) // 2, (16 - src.height) // 2), src)
    return img


def fist(d, x=3, y=4, c=SKIN):
    d.rectangle((x, y, x + 8, y + 7), fill=c, outline=K)
    for i in range(3):
        d.line((x + 2 + i * 2, y, x + 2 + i * 2, y + 3), fill=K)
    d.rectangle((x + 8, y + 2, x + 10, y + 5), fill=c, outline=K)


def icons():
    out = {}
    # --- Crew
    img, d = new()  # strength: flexed arm
    d.rectangle((2, 9, 9, 13), fill=SKIN, outline=K)
    d.ellipse((5, 4, 11, 10), fill=SKIN, outline=K)
    d.rectangle((9, 2, 13, 7), fill=SKIN, outline=K)
    out["strength"] = img
    img, d = new()  # gloves
    d.rounded_rectangle((3, 3, 12, 13), 2, fill=AMBER, outline=K)
    d.rectangle((3, 12, 12, 14), fill=BROWN, outline=K)
    d.line((6, 3, 6, 7), fill=K)
    d.line((9, 3, 9, 7), fill=K)
    out["gloves"] = img
    img, d = new()  # grip: fist holding rocks
    d.rectangle((1, 1, 6, 5), fill=GREY, outline=K)
    d.rectangle((9, 0, 14, 4), fill=DARK, outline=K)
    fist(d, 2, 7)
    out["grip"] = img
    img, d = new()  # intern: stick figure with hard hat
    d.rectangle((5, 1, 10, 3), fill=AMBER)
    d.ellipse((6, 3, 9, 6), outline=WHITE)
    d.line((7, 7, 7, 11), fill=WHITE)
    d.line((7, 8, 4, 10), fill=WHITE)
    d.line((7, 8, 11, 10), fill=WHITE)
    d.line((7, 11, 5, 15), fill=WHITE)
    d.line((7, 11, 10, 15), fill=WHITE)
    out["intern"] = img
    img, d = new()  # wheelbarrow
    d.polygon([(1, 6), (12, 6), (10, 11), (3, 11)], fill=GREEN, outline=K)
    d.ellipse((4, 10, 8, 14), fill=DARK, outline=K)
    d.line((12, 6, 15, 4), fill=BROWN)
    d.rectangle((3, 4, 9, 6), fill=GREY)
    out["wheelbarrow"] = img
    img, d = new()  # coffee
    d.rectangle((3, 6, 10, 14), fill=WHITE, outline=K)
    d.ellipse((9, 8, 13, 12), outline=WHITE)
    d.rectangle((4, 7, 9, 8), fill=BROWN)
    for x in (5, 8):
        d.line((x, 1, x + 1, 4), fill=GREY)
    out["coffee"] = img
    img, d = new()  # truck_cap: overflowing bed
    d.rectangle((1, 7, 14, 12), fill=AMBER, outline=K)
    d.polygon([(2, 7), (5, 2), (9, 4), (13, 7)], fill=GREY, outline=K)
    d.ellipse((2, 11, 5, 14), fill=K)
    d.ellipse((10, 11, 13, 14), fill=K)
    out["truck_cap"] = img
    img, d = new()  # truck_speed: wheel + speed lines
    d.ellipse((6, 4, 14, 12), fill=DARK, outline=K)
    d.ellipse((9, 7, 11, 9), fill=GREY)
    for y in (5, 8, 11):
        d.line((0, y, 4, y), fill=AMBER)
    out["truck_speed"] = img
    img = from_sprite("truck.png")  # truck_count
    d = ImageDraw.Draw(img)
    d.rectangle((11, 0, 15, 4), fill=GREEN)
    d.line((13, 0, 13, 4), fill=K)
    d.line((11, 2, 15, 2), fill=K)
    out["truck_count"] = img
    img, d = new()  # appraiser: magnifying glass on a coin
    d.ellipse((1, 1, 10, 10), fill=GOLD, outline=K)
    d.text((4, 1), "$", fill=K)
    d.line((9, 9, 14, 14), fill=BROWN, width=2)
    out["appraiser"] = img
    # --- Military
    out["soldier"] = from_sprite("soldier.png")
    out["gunner"] = from_sprite("gunner.png")
    out["technical"] = from_sprite("technical.png")
    out["tank"] = from_sprite("tank.png")
    out["bulldozer"] = from_sprite("bulldozer.png")
    img, d = new()  # guns: bullets
    for x in (2, 6, 10):
        d.rectangle((x, 6, x + 3, 14), fill=GOLD, outline=K)
        d.polygon([(x, 6), (x + 1, 2), (x + 2, 2), (x + 3, 6)], fill=AMBER, outline=K)
    out["guns"] = img
    img, d = new()  # shells
    d.rectangle((5, 6, 10, 15), fill=GOLD, outline=K)
    d.polygon([(5, 6), (7, 0), (8, 0), (10, 6)], fill=DARK, outline=K)
    d.line((5, 12, 10, 12), fill=K)
    out["shells"] = img
    img, d = new()  # diesel: jerry can
    d.rectangle((3, 4, 12, 15), fill=RED, outline=K)
    d.rectangle((9, 1, 12, 4), fill=DARK, outline=K)
    d.line((4, 5, 11, 14), fill=K)
    d.line((11, 5, 4, 14), fill=K)
    out["diesel"] = img
    # --- Items (reuse sprites)
    for item in ("grenade", "bird", "quake", "airstrike", "nuke"):
        out[item] = from_sprite(item + ".png")
    # --- Perks
    img, d = new()  # gym: dumbbell
    d.rectangle((1, 4, 4, 12), fill=DARK, outline=K)
    d.rectangle((11, 4, 14, 12), fill=DARK, outline=K)
    d.rectangle((4, 7, 11, 9), fill=GREY, outline=K)
    out["gym"] = img
    img, d = new()  # union: raised fist
    fist(d, 3, 2)
    d.rectangle((5, 9, 10, 15), fill=SKIN, outline=K)
    out["union"] = img
    img = from_sprite("truck.png")  # fleet
    d = ImageDraw.Draw(img)
    d.text((10, 0), "x", fill=GOLD)
    out["fleet"] = img
    img, d = new()  # pentagon: star
    d.polygon([(8, 0), (10, 6), (15, 6), (11, 10), (13, 15), (8, 12), (3, 15), (5, 10), (1, 6), (6, 6)], fill=GOLD, outline=K)
    out["pentagon"] = img
    img, d = new()  # seed funding: money bag
    d.ellipse((2, 4, 13, 15), fill=BROWN, outline=K)
    d.rectangle((6, 1, 9, 5), fill=BROWN, outline=K)
    d.text((5, 6), "$", fill=GOLD)
    out["seed"] = img
    img, d = new()  # geology: gem
    d.polygon([(4, 2), (11, 2), (14, 6), (8, 14), (1, 6)], fill=CYAN, outline=K)
    d.line((1, 6, 14, 6), fill=K)
    d.line((8, 14, 6, 6), fill=K)
    d.line((8, 14, 10, 6), fill=K)
    out["geology"] = img
    img, d = new()  # luck: hard hat with clover
    d.pieslice((2, 4, 14, 16), 180, 360, fill=AMBER, outline=K)
    d.rectangle((0, 10, 15, 11), fill=AMBER, outline=K)
    for (x, y) in ((7, 4), (9, 6), (7, 8), (5, 6)):
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=GREEN)
    out["luck"] = img
    img, d = new()  # headhunter: person + plus
    d.ellipse((3, 1, 8, 6), fill=SKIN, outline=K)
    d.rectangle((2, 7, 9, 14), fill=BLUE, outline=K)
    d.rectangle((10, 6, 15, 7), fill=GREEN)
    d.rectangle((12, 4, 13, 9), fill=GREEN)
    out["headhunter"] = img
    img, d = new()  # stockpile: crate
    d.rectangle((1, 3, 14, 14), fill=BROWN, outline=K)
    d.line((1, 3, 14, 14), fill=K)
    d.line((14, 3, 1, 14), fill=K)
    d.rectangle((1, 8, 14, 9), fill=K)
    out["stockpile"] = img
    return out


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for name, img in icons().items():
        img.save(OUT / f"{name}.png")
    print("wrote", len(icons()), "icons to", OUT)
