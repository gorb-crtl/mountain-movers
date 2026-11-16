class_name Materials
extends RefCounted
## Everything a mountain pixel can be made of.
## Colors are placeholder art: tweak them freely, or swap the mountain renderer
## to sample real textures later.

enum { AIR, DIRT, STONE, HARD_ROCK, COPPER, IRON, GOLD, GEM, FOSSIL, ARTEFACT }

# kind:
#   "rubble" -> pays a small disposal fee the moment it is removed
#   "ore"    -> goes into the loot bag, sell it for real money
#   "item"   -> one pixel of a multi-pixel fossil or artefact; dig out every
#               pixel of it to collect the whole find
const DATA: Array = [
	{"name": "Air", "hp": 0.0, "value": 0.0, "kind": "air", "color": Color(0, 0, 0, 0)},
	{"name": "Dirt", "hp": 1.0, "value": 0.5, "kind": "rubble", "color": Color(0.33, 0.25, 0.22)},
	{"name": "Stone", "hp": 3.0, "value": 1.0, "kind": "rubble", "color": Color(0.30, 0.29, 0.33)},
	{"name": "Hard Rock", "hp": 8.0, "value": 2.0, "kind": "rubble", "color": Color(0.19, 0.18, 0.23)},
	{"name": "Copper Ore", "hp": 4.0, "value": 12.0, "kind": "ore", "color": Color(0.85, 0.48, 0.25)},
	{"name": "Iron Ore", "hp": 6.0, "value": 30.0, "kind": "ore", "color": Color(0.72, 0.66, 0.62)},
	{"name": "Gold Ore", "hp": 10.0, "value": 110.0, "kind": "ore", "color": Color(1.0, 0.78, 0.25)},
	{"name": "Gem", "hp": 14.0, "value": 450.0, "kind": "ore", "color": Color(0.31, 0.94, 0.88)},
	{"name": "Fossil", "hp": 3.0, "value": 0.0, "kind": "item", "color": Color(0.94, 0.90, 0.78)},
	{"name": "Artefact", "hp": 5.0, "value": 0.0, "kind": "item", "color": Color(0.78, 0.42, 0.98)},
]

const ORES: Array = [COPPER, IRON, GOLD, GEM]

# Multi-pixel finds. "X" = a pixel of the find. Value is the base payout
# (scaled up by the mountain level and sell bonuses).
const FOSSILS: Array = [
	{"name": "Suspiciously Large Rib", "value": 150.0, "pattern": ["X.X.X", "XXXXX", "X.X.X"]},
	{"name": "Dino Skull (Probably)", "value": 260.0, "pattern": [".XXX.", "XX.XX", "XXXXX", ".X.X."]},
	{"name": "Fish That Gave Up", "value": 120.0, "pattern": ["X..X.", "XXXXX", "X..X."]},
	{"name": "Fossilized Sandwich", "value": 180.0, "pattern": ["XXXX", "X..X", "XXXX"]},
	{"name": "Ancient Snail, Very Slow", "value": 140.0, "pattern": [".XX", "X.X", "XXX"]},
]

const ARTEFACTS: Array = [
	{"name": "Ancient Toaster", "value": 400.0, "pattern": ["XXXX", "X..X", "XXXX"]},
	{"name": "Cursed Spork", "value": 350.0, "pattern": ["X.X", "XXX", ".X.", ".X."]},
	{"name": "Prehistoric Stapler", "value": 380.0, "pattern": ["XXXX", "X...", "XXXX"]},
	{"name": "Somebody's Car Keys", "value": 300.0, "pattern": ["XX.", "XXX", ".X."]},
	{"name": "Golden Rubber Duck", "value": 600.0, "pattern": [".XX.", "XXXX", ".XX."]},
	{"name": "Previous Intern's Hard Hat", "value": 450.0, "pattern": [".XX.", "XXXX"]},
]
