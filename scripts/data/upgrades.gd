class_name UpgradeDefs
extends RefCounted
## Upgrade definitions. Effects are computed in game_state.gd; this file only
## holds names, flavour text and prices so balancing is easy to tweak.

# Run upgrades: bought with money, reset whenever the mountain regrows.
const RUN: Array = [
	{"id": "gloves", "name": "Bigger Gloves", "desc": "More damage per grab.", "base": 10.0, "growth": 1.45, "max": -1},
	{"id": "grip", "name": "Wider Fistful", "desc": "Grab a bigger chunk of mountain each click.", "base": 25.0, "growth": 2.1, "max": 12},
	{"id": "intern", "name": "Hire Intern", "desc": "An unpaid intern who digs on their own.", "base": 15.0, "growth": 1.3, "max": -1},
	{"id": "shovels", "name": "Better Shovels", "desc": "Interns hit harder.", "base": 60.0, "growth": 1.6, "max": -1},
	{"id": "coffee", "name": "Office Coffee", "desc": "Interns dig faster. Mostly jitter.", "base": 90.0, "growth": 1.8, "max": 15},
	{"id": "jackhammer", "name": "Jackhammer", "desc": "Hold the mouse button to dig automatically.", "base": 250.0, "growth": 2.6, "max": 6},
	{"id": "dynamite", "name": "Dynamite", "desc": "Right-click (or Space) to throw. Bigger boom per level.", "base": 200.0, "growth": 2.4, "max": 10},
	{"id": "appraiser", "name": "Shady Appraiser", "desc": "Loot sells for 25% more.", "base": 120.0, "growth": 1.9, "max": -1},
	{"id": "autosell", "name": "Auto-Seller 3000", "desc": "Loot sells itself the moment you dig it up.", "base": 500.0, "growth": 1.0, "max": 1},
]

# Permanent upgrades: bought with Boss Approval, kept forever.
const PERM: Array = [
	{"id": "gym", "name": "Company Gym", "desc": "x1.6 grab damage, forever.", "base": 2.0, "growth": 1.6, "max": -1},
	{"id": "union", "name": "Intern Union", "desc": "x1.6 intern damage, forever.", "base": 2.0, "growth": 1.6, "max": -1},
	{"id": "seed", "name": "Seed Funding", "desc": "Start each mountain with more cash.", "base": 3.0, "growth": 1.7, "max": -1},
	{"id": "geology", "name": "Geology Degree", "desc": "x1.5 loot value, forever.", "base": 3.0, "growth": 1.7, "max": -1},
	{"id": "luck", "name": "Lucky Hard Hat", "desc": "More ore and finds in new mountains.", "base": 4.0, "growth": 1.8, "max": 10},
	{"id": "headhunter", "name": "Headhunter", "desc": "Start each mountain with 2 more interns.", "base": 3.0, "growth": 1.8, "max": -1},
	{"id": "license", "name": "Explosives License", "desc": "Start each mountain with a Dynamite level.", "base": 6.0, "growth": 2.2, "max": 5},
]


static func find(list: Array, id: String) -> Dictionary:
	for d in list:
		if d["id"] == id:
			return d
	return {}


static func cost(def: Dictionary, level: int) -> float:
	return floor(float(def["base"]) * pow(float(def["growth"]), level))
