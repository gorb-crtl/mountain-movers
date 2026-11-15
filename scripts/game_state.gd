extends Node
## Global game state, autoloaded as "Game".
## Holds money, upgrades, prestige progress and save/load. Gameplay nodes read
## derived stats (click damage, worker rate, ...) from the helpers below.

signal changed
signal boss_says(text: String, duration: float)

const MOUNTAIN_COUNT := 7
const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

const MOUNTAINS: Array = [
	{"name": "Lil' Hill", "width": 100},
	{"name": "Mt. Mildly Annoying", "width": 150},
	{"name": "Big Bertha", "width": 210},
	{"name": "Mt. Paperwork", "width": 280},
	{"name": "The Unmovable Ridge", "width": 350},
	{"name": "Mt. Overtime", "width": 430},
	{"name": "Mt. Everything", "width": 520},
]

var money: float = 0.0
var approval: int = 0
var level: int = 0                 # which mountain (0..6)
var mountain_seed: int = 0
var run_upgrades: Dictionary = {}  # id -> level, reset on regrow
var perm_upgrades: Dictionary = {} # id -> level, kept forever
var ores: Dictionary = {}          # material id -> count in loot bag
var items: Array = []              # [{"name", "value"}] finds in loot bag
var won: bool = false
var intro_done: bool = false
var stats: Dictionary = {"pixels": 0, "clicks": 0, "finds": 0, "earned": 0.0, "mountains": 0}


func _ready() -> void:
	randomize()
	start_run()


# ---------------------------------------------------------------- upgrades

func run_lvl(id: String) -> int:
	return int(run_upgrades.get(id, 0))


func perm_lvl(id: String) -> int:
	return int(perm_upgrades.get(id, 0))


func run_cost(id: String) -> float:
	return UpgradeDefs.cost(UpgradeDefs.find(UpgradeDefs.RUN, id), run_lvl(id))


func perm_cost(id: String) -> int:
	return int(UpgradeDefs.cost(UpgradeDefs.find(UpgradeDefs.PERM, id), perm_lvl(id)))


func is_maxed(def: Dictionary, lvl: int) -> bool:
	return int(def["max"]) >= 0 and lvl >= int(def["max"])


func buy_run(id: String) -> bool:
	var def := UpgradeDefs.find(UpgradeDefs.RUN, id)
	var lvl := run_lvl(id)
	if def.is_empty() or is_maxed(def, lvl):
		return false
	var price := run_cost(id)
	if money < price:
		return false
	money -= price
	run_upgrades[id] = lvl + 1
	if id == "autosell":
		sell_all()
	if randf() < 0.25:
		say(Quips.pick(Quips.UPGRADE))
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
	# Some perks also apply right now, not just from the next mountain.
	if id == "headhunter":
		run_upgrades["intern"] = run_lvl("intern") + 2
	elif id == "license" and run_lvl("dynamite") < lvl + 1:
		run_upgrades["dynamite"] = lvl + 1
	changed.emit()
	return true


# ----------------------------------------------------------- derived stats

func hp_mult() -> float:
	return pow(4.0, level)


func value_mult() -> float:
	return pow(3.6, level)


func click_damage() -> float:
	var g := run_lvl("gloves")
	return (1.0 + g) * pow(1.1, g) * pow(1.6, perm_lvl("gym"))


func click_radius() -> float:
	# 0.5 = a single pixel. Each level widens the fistful.
	return 0.5 + 0.7 * run_lvl("grip")


func worker_count() -> int:
	return run_lvl("intern")


func worker_rate() -> float:
	# Hits per second, per intern.
	return 0.8 * (1.0 + 0.2 * run_lvl("coffee"))


func worker_damage() -> float:
	var s := run_lvl("shovels")
	return (1.0 + s) * pow(1.1, s) * pow(1.6, perm_lvl("union"))


func jackhammer_rate() -> float:
	var j := run_lvl("jackhammer")
	return 0.0 if j == 0 else 4.0 + 2.0 * j


func dynamite_level() -> int:
	return run_lvl("dynamite")


func dynamite_radius() -> float:
	return 4.0 + 1.5 * dynamite_level()


func dynamite_damage() -> float:
	return click_damage() * 25.0 * (1.0 + 0.5 * dynamite_level())


func dynamite_cooldown() -> float:
	return maxf(2.0, 8.0 - 0.5 * dynamite_level())


func sell_mult() -> float:
	return (1.0 + 0.25 * run_lvl("appraiser")) * pow(1.5, perm_lvl("geology"))


func luck() -> float:
	return 1.0 + 0.2 * perm_lvl("luck")


func auto_sell() -> bool:
	return run_lvl("autosell") > 0


func starting_cash() -> float:
	var s := perm_lvl("seed")
	return 0.0 if s == 0 else 50.0 * pow(3.0, s - 1) * value_mult()


func mountain_name() -> String:
	return MOUNTAINS[mini(level, MOUNTAIN_COUNT - 1)]["name"]


func mountain_size() -> Vector2i:
	var w: int = MOUNTAINS[mini(level, MOUNTAIN_COUNT - 1)]["width"]
	return Vector2i(w, int(w * 0.5))


# ------------------------------------------------------------ money & loot

func add_money(amount: float) -> void:
	money += amount
	stats["earned"] = float(stats["earned"]) + amount


func ore_value(mat: int) -> float:
	return float(Materials.DATA[mat]["value"]) * value_mult() * sell_mult()


## Called by the mountain for every pixel removed.
func collect(mat: int) -> void:
	stats["pixels"] = int(stats["pixels"]) + 1
	var def: Dictionary = Materials.DATA[mat]
	match def["kind"]:
		"rubble":
			add_money(float(def["value"]) * value_mult())
		"ore":
			if auto_sell():
				add_money(ore_value(mat))
			else:
				ores[mat] = int(ores.get(mat, 0)) + 1


## Called when every pixel of a fossil/artefact is dug out. Returns its value.
func collect_item(item_name: String, base_value: float) -> float:
	var value := base_value * value_mult() * sell_mult()
	stats["finds"] = int(stats["finds"]) + 1
	if auto_sell():
		add_money(value)
	else:
		items.append({"name": item_name, "value": value})
	changed.emit()
	return value


func loot_value() -> float:
	var total := 0.0
	for mat in ores:
		total += ore_value(int(mat)) * int(ores[mat])
	for it in items:
		total += float(it["value"])
	return total


func sell_all() -> float:
	var total := loot_value()
	add_money(total)
	ores.clear()
	items.clear()
	changed.emit()
	return total


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
	if perm_lvl("license") > 0:
		run_upgrades["dynamite"] = perm_lvl("license")
	ores = {}
	items = []
	mountain_seed = randi()
	changed.emit()


func wipe() -> void:
	money = 0.0
	approval = 0
	level = 0
	perm_upgrades = {}
	won = false
	intro_done = false
	stats = {"pixels": 0, "clicks": 0, "finds": 0, "earned": 0.0, "mountains": 0}
	start_run()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func say(text: String, duration := 5.0) -> void:
	boss_says.emit(text, duration)


# ------------------------------------------------------------- save / load

func save_game(mountain_blob: Dictionary) -> void:
	var data := {
		"version": SAVE_VERSION,
		"money": money,
		"approval": approval,
		"level": level,
		"mountain_seed": mountain_seed,
		"run_upgrades": run_upgrades,
		"perm_upgrades": perm_upgrades,
		"ores": ores,
		"items": items,
		"won": won,
		"intro_done": intro_done,
		"stats": stats,
		"mountain": mountain_blob,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


## Loads the save if there is one. Returns the saved mountain blob ({} if none).
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	money = float(d.get("money", 0.0))
	approval = int(d.get("approval", 0))
	level = clampi(int(d.get("level", 0)), 0, MOUNTAIN_COUNT - 1)
	mountain_seed = int(d.get("mountain_seed", randi()))
	run_upgrades = _int_values(d.get("run_upgrades", {}))
	perm_upgrades = _int_values(d.get("perm_upgrades", {}))
	ores = {}
	var saved_ores: Dictionary = d.get("ores", {})
	for k in saved_ores:
		ores[int(k)] = int(saved_ores[k])  # JSON turns int keys into strings
	items = d.get("items", [])
	won = bool(d.get("won", false))
	intro_done = bool(d.get("intro_done", false))
	var saved_stats: Dictionary = d.get("stats", {})
	for k in saved_stats:
		stats[k] = saved_stats[k]
	changed.emit()
	return d.get("mountain", {})


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
