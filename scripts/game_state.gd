extends Node
## Global game state, autoloaded as "Game".
## Holds money, upgrades, prestige progress and save/load. Gameplay nodes read
## derived stats (hand damage, truck capacity, ...) from the helpers below.

signal changed
signal boss_says(text: String, duration: float)

const MOUNTAIN_COUNT := 7
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 2
## World units per mountain pixel.
const CELL := 5.0

const MOUNTAINS: Array = [
	{"name": "Lil' Hill", "width": 90},
	{"name": "Mt. Mildly Annoying", "width": 140},
	{"name": "Big Bertha", "width": 200},
	{"name": "Mt. Paperwork", "width": 270},
	{"name": "The Unmovable Ridge", "width": 350},
	{"name": "Mt. Overtime", "width": 440},
	{"name": "Mt. Everything", "width": 560},
]

var money: float = 0.0
var approval: int = 0
var level: int = 0                 # which mountain (0..6)
var mountain_seed: int = 0
var run_upgrades: Dictionary = {}  # id -> level (crew, trucks, military); reset on regrow
var perm_upgrades: Dictionary = {} # id -> level, kept forever
var inventory: Dictionary = {}     # one-use item id -> count
var won: bool = false
var intro_done: bool = false
var volume: float = 0.8
var crt := true   # CRT TV overlay on/off
var stats: Dictionary = {"pixels": 0, "clicks": 0, "finds": 0, "earned": 0.0, "mountains": 0, "trucks": 0, "caveins": 0}


func _ready() -> void:
	randomize()
	start_run()


# ---------------------------------------------------------------- upgrades

func run_lvl(id: String) -> int:
	return int(run_upgrades.get(id, 0))


func perm_lvl(id: String) -> int:
	return int(perm_upgrades.get(id, 0))


func item_count(id: String) -> int:
	return int(inventory.get(id, 0))


func run_cost(id: String) -> float:
	return UpgradeDefs.cost(UpgradeDefs.find_any(id), run_lvl(id)) * value_mult()


func item_cost(id: String) -> float:
	return UpgradeDefs.cost(UpgradeDefs.find(UpgradeDefs.ITEMS, id), 0) * value_mult()


func perm_cost(id: String) -> int:
	return int(UpgradeDefs.cost(UpgradeDefs.find(UpgradeDefs.PERM, id), perm_lvl(id)))


func is_maxed(def: Dictionary, lvl: int) -> bool:
	return int(def.get("max", -1)) >= 0 and lvl >= int(def["max"])


func buy_run(id: String) -> bool:
	var def := UpgradeDefs.find_any(id)
	var lvl := run_lvl(id)
	if def.is_empty() or is_maxed(def, lvl):
		return false
	var price := run_cost(id)
	if money < price:
		return false
	money -= price
	run_upgrades[id] = lvl + 1
	Sfx.play("buy")
	if not UpgradeDefs.find(UpgradeDefs.MILITARY, id).is_empty() and lvl == 0 and randf() < 0.6:
		say(Quips.pick(Quips.MILITARY))
	elif randf() < 0.2:
		say(Quips.pick(Quips.UPGRADE))
	changed.emit()
	return true


func buy_item(id: String) -> bool:
	var price := item_cost(id)
	if money < price:
		return false
	money -= price
	inventory[id] = item_count(id) + 1
	Sfx.play("buy")
	changed.emit()
	return true


func use_item(id: String) -> bool:
	if item_count(id) <= 0:
		return false
	inventory[id] = item_count(id) - 1
	changed.emit()
	return true


func buy_perm(id: String) -> bool:
	var def := UpgradeDefs.find(UpgradeDefs.PERM, id)
	var lvl := perm_lvl(id)
	if def.is_empty() or is_maxed(def, lvl):
		return false
	var price := perm_cost(id)
	if approval < price:
		return false
	approval -= price
	perm_upgrades[id] = lvl + 1
	Sfx.play("buy")
	if id == "headhunter":
		run_upgrades["intern"] = run_lvl("intern") + 2
	changed.emit()
	return true


# ----------------------------------------------------------- derived stats

func hp_mult() -> float:
	return pow(4.0, level)


func value_mult() -> float:
	return pow(3.6, level)


## Hand: damage per click, chunk radius (in pixels), carry capacity (pixels).
func click_damage() -> float:
	var g := run_lvl("strength")
	return (1.0 + g) * pow(1.1, g) * pow(1.6, perm_lvl("gym")) * level_damage_boost()


func level_damage_boost() -> float:
	# Later mountains are tougher; your arms keep up a little on their own.
	return pow(2.0, level)


func click_radius() -> float:
	return 0.5 + 0.7 * run_lvl("grip")


func hand_capacity() -> int:
	return int(4 + 4 * run_lvl("gloves") + 2 * run_lvl("grip") * run_lvl("grip"))


## Interns.
func intern_count() -> int:
	return run_lvl("intern")


func intern_speed() -> float:
	return 60.0 * (1.0 + 0.15 * run_lvl("coffee"))


func intern_dig_rate() -> float:
	return 1.2 * (1.0 + 0.2 * run_lvl("coffee"))


func intern_damage() -> float:
	return 1.0 * pow(1.5, perm_lvl("union")) * level_damage_boost() * (1.0 + 0.5 * run_lvl("wheelbarrow"))


func intern_capacity() -> int:
	return int((3 + 3 * run_lvl("wheelbarrow")) * pow(1.5, perm_lvl("union")))


## Trucks.
func truck_count() -> int:
	return 1 + run_lvl("truck_count")


func truck_capacity() -> int:
	return int(40 * (1.0 + 0.6 * run_lvl("truck_cap")) * pow(1.5, perm_lvl("fleet")) * pow(1.6, level))


func truck_trip_time() -> float:
	return 14.0 / (1.0 + 0.25 * run_lvl("truck_speed"))


## Military.
func gun_mult() -> float:
	return pow(1.5, run_lvl("guns")) * pow(1.6, perm_lvl("pentagon")) * level_damage_boost()


func diesel_mult() -> float:
	return 1.0 + 0.5 * run_lvl("diesel")


func shell_radius() -> float:
	return 3.0 + 0.8 * run_lvl("shells")


func sell_mult() -> float:
	return (1.0 + 0.25 * run_lvl("appraiser")) * pow(1.5, perm_lvl("geology"))


func luck() -> float:
	return 1.0 + 0.2 * perm_lvl("luck")


func starting_cash() -> float:
	var s := perm_lvl("seed")
	return 0.0 if s == 0 else 50.0 * pow(3.0, s - 1) * value_mult()


func mountain_name() -> String:
	return MOUNTAINS[mini(level, MOUNTAIN_COUNT - 1)]["name"]


func mountain_size() -> Vector2i:
	var w: int = MOUNTAINS[mini(level, MOUNTAIN_COUNT - 1)]["width"]
	return Vector2i(w, int(w * 0.5))


# ------------------------------------------------------------ money

## Raw value of one pixel of a material (before the truck's sell bonus).
func pixel_value(mat: int) -> float:
	return float(Materials.DATA[mat]["value"]) * value_mult()


func find_value(base_value: float) -> float:
	return base_value * value_mult()


## A truck came back from the quarry. Returns the cash paid.
func sell_load(raw_value: float) -> float:
	var paid := raw_value * sell_mult()
	money += paid
	stats["earned"] = float(stats["earned"]) + paid
	stats["trucks"] = int(stats["trucks"]) + 1
	changed.emit()
	return paid


func add_money(amount: float) -> void:
	money += amount
	stats["earned"] = float(stats["earned"]) + amount
	changed.emit()


# --------------------------------------------------------------- prestige

func clear_award() -> int:
	return int(round(5.0 * pow(2.2, level)))


func bailout_award(fraction_moved: float) -> int:
	return int(floor(clear_award() * 0.5 * fraction_moved * fraction_moved))


## Mountain fully moved: pay out approval and move on to the next one.
func complete_mountain() -> int:
	var award := clear_award()
	approval += award
	stats["mountains"] = int(stats["mountains"]) + 1
	level += 1
	if level >= MOUNTAIN_COUNT:
		level = MOUNTAIN_COUNT - 1
		won = true
	start_run()
	return award


## Give up on the current mountain: it regrows (same size), partial approval.
func bail_out(fraction_moved: float) -> int:
	var award := bailout_award(fraction_moved)
	approval += award
	start_run()
	return award


func start_run() -> void:
	money = starting_cash()
	run_upgrades = {}
	if perm_lvl("headhunter") > 0:
		run_upgrades["intern"] = perm_lvl("headhunter") * 2
	inventory = {}
	if perm_lvl("stockpile") > 0:
		inventory["grenade"] = 2 * perm_lvl("stockpile")
		inventory["bird"] = perm_lvl("stockpile")
	mountain_seed = randi()
	changed.emit()


func wipe() -> void:
	money = 0.0
	approval = 0
	level = 0
	perm_upgrades = {}
	won = false
	intro_done = false
	stats = {"pixels": 0, "clicks": 0, "finds": 0, "earned": 0.0, "mountains": 0, "trucks": 0, "caveins": 0}
	start_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func say(text: String, duration := 5.0) -> void:
	boss_says.emit(text, duration)


# ------------------------------------------------------------- save / load

## `world` holds everything the main scene needs to restore (mountain, rocks, trucks).
func save_game(world: Dictionary) -> void:
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"approval": approval,
		"level": level,
		"mountain_seed": mountain_seed,
		"run_upgrades": run_upgrades,
		"perm_upgrades": perm_upgrades,
		"inventory": inventory,
		"won": won,
		"intro_done": intro_done,
		"volume": volume,
		"crt": crt,
		"stats": stats,
		"world": world,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Loads the save if there is one. Returns the saved world blob ({} if none).
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	if int(d.get("version", 1)) < SAVE_VERSION:
		# Old prototype save: keep the prestige progress, start the mountain fresh.
		approval = int(d.get("approval", 0))
		perm_upgrades = _int_values(d.get("perm_upgrades", {}))
		level = clampi(int(d.get("level", 0)), 0, MOUNTAIN_COUNT - 1)
		intro_done = bool(d.get("intro_done", false))
		start_run()
		return {}
	money = float(d.get("money", 0.0))
	approval = int(d.get("approval", 0))
	level = clampi(int(d.get("level", 0)), 0, MOUNTAIN_COUNT - 1)
	mountain_seed = int(d.get("mountain_seed", randi()))
	run_upgrades = _int_values(d.get("run_upgrades", {}))
	perm_upgrades = _int_values(d.get("perm_upgrades", {}))
	inventory = _int_values(d.get("inventory", {}))
	won = bool(d.get("won", false))
	intro_done = bool(d.get("intro_done", false))
	volume = float(d.get("volume", 0.8))
	crt = bool(d.get("crt", true))
	var saved_stats: Dictionary = d.get("stats", {})
	for k in saved_stats:
		stats[k] = saved_stats[k]
	changed.emit()
	return d.get("world", {})


func _int_values(src: Dictionary) -> Dictionary:
	var out := {}
	for k in src:
		out[str(k)] = int(src[k])
	return out


# ------------------------------------------------------------- formatting

static func fmt(n: float) -> String:
	if n < 1000.0:
		return str(snappedf(n, 0.1)) if n < 100.0 and n != floor(n) else str(int(n))
	var suffixes := ["K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No"]
	var i := -1
	while n >= 1000.0 and i < suffixes.size() - 1:
		n /= 1000.0
		i += 1
	return "%.2f%s" % [n, suffixes[i]]
