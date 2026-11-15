class_name UpgradeDefs
extends RefCounted
## Upgrade, unit and item definitions. Effects are computed in game_state.gd;
## this file holds names, flavour text and prices so balancing is easy to tweak.
## Money prices are multiplied by Game.value_mult() so later mountains scale.

# Crew & trucks: bought with money, reset whenever the mountain regrows.
const RUN: Array = [
	{"id": "strength", "name": "Protein Shakes", "desc": "Hit the mountain harder.", "base": 10.0, "growth": 1.45, "max": -1},
	{"id": "gloves", "name": "Bigger Gloves", "desc": "Carry more rock in your hand.", "base": 15.0, "growth": 1.6, "max": -1},
	{"id": "grip", "name": "Wider Fistful", "desc": "Break off a bigger chunk per click.", "base": 30.0, "growth": 2.0, "max": 12},
	{"id": "intern", "name": "Hire Intern", "desc": "Unpaid stick person. Digs, then hauls rock to the truck.", "base": 20.0, "growth": 1.3, "max": -1},
	{"id": "wheelbarrow", "name": "Wheelbarrows", "desc": "Interns carry more per trip.", "base": 50.0, "growth": 1.7, "max": -1},
	{"id": "coffee", "name": "Office Coffee", "desc": "Interns walk and dig faster. Mostly jitter.", "base": 70.0, "growth": 1.8, "max": 15},
	{"id": "truck_cap", "name": "Bigger Truck Bed", "desc": "Trucks hold more rock per trip.", "base": 40.0, "growth": 1.7, "max": -1},
	{"id": "truck_speed", "name": "Truck Engine", "desc": "Trucks make the round trip faster.", "base": 60.0, "growth": 1.8, "max": 15},
	{"id": "truck_count", "name": "Buy Another Truck", "desc": "One more dump truck in the fleet.", "base": 150.0, "growth": 2.6, "max": 7},
	{"id": "appraiser", "name": "Shady Appraiser", "desc": "Every truckload sells for 25% more.", "base": 120.0, "growth": 1.9, "max": -1},
]

# Military: also money, also reset on regrow.
const MILITARY: Array = [
	{"id": "soldier", "name": "Hire Soldier", "desc": "Shoots the mountain with a rifle. Doesn't ask questions.", "base": 120.0, "growth": 1.35, "max": 20},
	{"id": "gunner", "name": "Machine Gunner", "desc": "Sprays the mountain. Very loud.", "base": 600.0, "growth": 1.5, "max": 12},
	{"id": "technical", "name": ".50 BMG Pickup", "desc": "A pickup truck with a .50 cal bolted on the back.", "base": 2500.0, "growth": 1.7, "max": 8},
	{"id": "tank", "name": "Tank", "desc": "Explosive shells. Paperwork is someone else's problem.", "base": 9000.0, "growth": 1.9, "max": 6},
	{"id": "bulldozer", "name": "Bulldozer", "desc": "Shoves into the base of the mountain over and over.", "base": 4000.0, "growth": 1.8, "max": 6},
	{"id": "guns", "name": "Weapon Upgrade", "desc": "All guns do +50% damage.", "base": 400.0, "growth": 1.9, "max": -1},
	{"id": "shells", "name": "Bigger Shells", "desc": "Tank shells blow bigger holes.", "base": 5000.0, "growth": 2.0, "max": 10},
	{"id": "diesel", "name": "Racing Diesel", "desc": "Bulldozers and the pickup hit harder.", "base": 3000.0, "growth": 1.9, "max": -1},
]

# One-use items, bought with money, used from the hotbar (keys 1-5).
const ITEMS: Array = [
	{"id": "grenade", "name": "Grenade", "desc": "Small boom. Pull pin, throw, enjoy.", "base": 25.0, "growth": 1.0, "key": "1", "color": Color(0.35, 0.55, 0.25)},
	{"id": "bird", "name": "Large Bird", "desc": "Swoops in, grabs a chunk of mountain, drops it in a truck.", "base": 80.0, "growth": 1.0, "key": "2", "color": Color(0.55, 0.40, 0.25)},
	{"id": "quake", "name": "Earthquake", "desc": "Shakes the whole surface loose. Insurance won't cover it.", "base": 300.0, "growth": 1.0, "key": "3", "color": Color(0.6, 0.45, 0.3)},
	{"id": "airstrike", "name": "Airstrike", "desc": "A row of bombs across the mountain.", "base": 900.0, "growth": 1.0, "key": "4", "color": Color(0.4, 0.45, 0.5)},
	{"id": "nuke", "name": "Nuke", "desc": "Absolutely not OSHA compliant.", "base": 5000.0, "growth": 1.0, "key": "5", "color": Color(0.95, 0.85, 0.2)},
]

# Permanent upgrades: bought with Boss Approval, kept forever.
const PERM: Array = [
	{"id": "gym", "name": "Company Gym", "desc": "x1.6 hand damage, forever.", "base": 2.0, "growth": 1.6, "max": -1},
	{"id": "union", "name": "Intern Union", "desc": "x1.5 intern dig and carry, forever.", "base": 2.0, "growth": 1.6, "max": -1},
	{"id": "fleet", "name": "Fleet Contract", "desc": "x1.5 truck capacity, forever.", "base": 3.0, "growth": 1.7, "max": -1},
	{"id": "pentagon", "name": "Pentagon Friend", "desc": "x1.6 military damage, forever.", "base": 4.0, "growth": 1.7, "max": -1},
	{"id": "seed", "name": "Seed Funding", "desc": "Start each mountain with more cash.", "base": 3.0, "growth": 1.7, "max": -1},
	{"id": "geology", "name": "Geology Degree", "desc": "x1.5 rock value, forever.", "base": 3.0, "growth": 1.7, "max": -1},
	{"id": "luck", "name": "Lucky Hard Hat", "desc": "More ore and finds in new mountains.", "base": 4.0, "growth": 1.8, "max": 10},
	{"id": "headhunter", "name": "Headhunter", "desc": "Start each mountain with 2 more interns.", "base": 3.0, "growth": 1.8, "max": -1},
	{"id": "stockpile", "name": "Supply Closet", "desc": "Start each mountain with 2 grenades and a bird per level.", "base": 4.0, "growth": 2.0, "max": 5},
]


static func find(list: Array, id: String) -> Dictionary:
	for d in list:
		if d["id"] == id:
			return d
	return {}


static func find_any(id: String) -> Dictionary:
	for list in [RUN, MILITARY, ITEMS, PERM]:
		var d := find(list, id)
		if not d.is_empty():
			return d
	return {}


static func cost(def: Dictionary, level: int) -> float:
	return floor(float(def["base"]) * pow(float(def["growth"]), level))
