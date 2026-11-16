class_name InternCrew
extends Node2D
## Stick-figure interns. Each one: pick up a loose rock (or dig some off the
## mountain), walk it to the truck, unload, repeat. This is the idle engine.
## Past MAX_SIMULATED interns, the extra ones make the simulated ones stronger.

const MAX_SIMULATED := 60
const HEIGHT := 16.0

var mountain: Mountain
var rocks: RockManager
var depot: TruckDepot
var effects: Effects

var _crew: Array = []   # [{"x","state","n","v","cols","rock","dig","t","anim","dir","finds"}]


func _process(delta: float) -> void:
	if mountain == null:
		return
	_sync()
	var boost := maxf(1.0, float(Game.intern_count()) / float(MAX_SIMULATED))
	var speed := Game.intern_speed()
	for it in _crew:
		_think(it, delta, speed, boost)
	queue_redraw()


func _sync() -> void:
	var want := mini(Game.intern_count(), MAX_SIMULATED)
	while _crew.size() < want:
		_crew.append({"x": depot.unload_x() + randf_range(-20, 20), "state": "idle", "n": 0, "v": 0.0,
			"cols": PackedColorArray(), "rock": null, "dig": Vector2i(-1, -1), "t": randf() * 0.5,
			"anim": randf() * TAU, "dir": 1.0})
	while _crew.size() > want:
		var it: Dictionary = _crew.pop_back()
		_release_claim(it)


func _think(it: Dictionary, delta: float, speed: float, boost: float) -> void:
	var cap := int(Game.intern_capacity() * boost)
	match it["state"]:
		"idle":
			it["t"] = float(it["t"]) - delta
			if float(it["t"]) > 0.0:
				return
			if int(it["n"]) >= cap or (int(it["n"]) > 0 and randf() < 0.3):
				it["state"] = "to_truck"
				return
			var r := rocks.free_ground_rock(float(it["x"]), depot.bed_rect())
			if r:
				r.claimed_by = it
				it["rock"] = r
				it["state"] = "to_rock"
			else:
				var c := mountain.surface_cell_near(float(it["x"]) + randf_range(-200, 200), 400)
				if c.x < 0:
					it["t"] = 1.0
					return
				it["dig"] = c
				it["state"] = "to_dig"
		"to_rock":
			var r: Rock = it["rock"]
			if not is_instance_valid(r) or r.pixels <= 0:
				it["state"] = "idle"
				it["rock"] = null
				return
			if _walk(it, r.position.x, speed, delta):
				var got := r.take(cap - int(it["n"]))
				_add_load(it, got)
				if r.pixels <= 0:
					rocks.remove(r)
				else:
					r.claimed_by = null
				it["rock"] = null
				it["state"] = "to_truck"
				Sfx.play("grab", -14.0)
		"to_dig":
			var c: Vector2i = it["dig"]
			if not mountain.is_solid(c):
				c = mountain.surface_cell_near(mountain.cell_to_world(c).x, 20)
				if c.x < 0:
					it["state"] = "idle"
					return
				it["dig"] = c
			if _walk(it, mountain.cell_to_world(c).x, speed, delta):
				it["state"] = "digging"
				it["t"] = 1.0 / Game.intern_dig_rate()
		"digging":
			it["t"] = float(it["t"]) - delta
			it["anim"] = float(it["anim"]) + delta * 14.0
			if float(it["t"]) > 0.0:
				return
			it["t"] = 1.0 / Game.intern_dig_rate()
			var c: Vector2i = it["dig"]
			if not mountain.is_solid(c):
				c = mountain.surface_cell_near(float(it["x"]), 3)
			if c.x < 0:
				it["state"] = "to_truck" if int(it["n"]) > 0 else "idle"
				return
			it["dig"] = c
			var hv := mountain.damage_circle(c, 0.5 + 0.3 * (boost - 1.0), Game.intern_damage() * boost)
			Sfx.play("dig", -16.0, 0.15, 60)
			if int(hv["n"]) > 0:
				effects.debris(mountain.cell_to_world(c), (hv["colors"] as PackedColorArray)[0], Game.CELL * 0.6, 0.5)
				var room := cap - int(it["n"])
				var take := mini(room, int(hv["n"]))
				_add_load(it, {"n": take, "value": float(hv["value"]) * take / float(hv["n"]), "colors": (hv["colors"] as PackedColorArray).slice(0, take)})
				if take < int(hv["n"]):
					var frac := float(take) / float(hv["n"])
					rocks.spawn(int(hv["n"]) - take, float(hv["value"]) * (1.0 - frac), (hv["colors"] as PackedColorArray).slice(take), mountain.cell_to_world(c), Vector2(randf_range(-40, 40), -60))
			if int(it["n"]) >= cap:
				it["state"] = "to_truck"
		"to_truck":
			if _walk(it, depot.unload_x() + randf_range(-6, 6), speed, delta):
				var k := depot.deposit(int(it["n"]), float(it["v"]))
				if k > 0:
					var frac := float(k) / float(it["n"])
					it["v"] = float(it["v"]) * (1.0 - frac)
					it["n"] = int(it["n"]) - k
					var cols: PackedColorArray = it["cols"]
					it["cols"] = cols.slice(int(cols.size() * frac))
				if int(it["n"]) <= 0:
					it["state"] = "idle"
					it["t"] = 0.2
				else:
					it["state"] = "waiting"
					it["t"] = 0.5
		"waiting":
			# Truck is away or full: wait by the loading spot.
			it["t"] = float(it["t"]) - delta
			if float(it["t"]) <= 0.0:
				it["state"] = "to_truck"


## Walks along the terrain. Returns true when arrived.
func _walk(it: Dictionary, target_x: float, speed: float, delta: float) -> bool:
	var x: float = it["x"]
	if absf(target_x - x) < 3.0:
		return true
	it["dir"] = signf(target_x - x)
	# Slower uphill, carrying a full load.
	var slope := absf(_ground_y(x + float(it["dir"]) * 4.0) - _ground_y(x)) / 4.0
	var s := speed / (1.0 + slope * 1.5)
	it["x"] = move_toward(x, target_x, s * delta)
	it["anim"] = float(it["anim"]) + delta * s * 0.25
	return false


func _ground_y(x: float) -> float:
	return minf(mountain.surface_y_at(x), 0.0)


func _add_load(it: Dictionary, got: Dictionary) -> void:
	it["n"] = int(it["n"]) + int(got["n"])
	it["v"] = float(it["v"]) + float(got["value"])
	var cols: PackedColorArray = it["cols"]
	for c in got["colors"]:
		if cols.size() < 16:
			cols.append(c)
	it["cols"] = cols


func _release_claim(it: Dictionary) -> void:
	var r: Variant = it.get("rock")
	if r != null and is_instance_valid(r):
		(r as Rock).claimed_by = null


func reset() -> void:
	for it in _crew:
		_release_claim(it)
	_crew.clear()


# Tiny pixel people, one art pixel = one mountain pixel. h = hard hat, o = body.
const FRAMES := {
	"walk_a": [".h.", ".o.", "ooo", ".o.", "o.o", "o.o"],
	"walk_b": [".h.", ".o.", "ooo", ".o.", ".o.", ".o."],
	"stand": [".h.", ".o.", "ooo", ".o.", ".o.", "o.o"],
	"carry_a": ["oho", "ooo", ".o.", ".o.", "o.o", "o.o"],
	"carry_b": ["oho", "ooo", ".o.", ".o.", ".o.", ".o."],
	"dig_a": [".h..", ".o.p", ".oo.", ".o..", ".o..", "o.o."],
	"dig_b": [".h.p", ".oop", ".o..", ".o..", ".o..", "o.o."],
}
const BODY := Color(0.88, 0.85, 0.78)
const HAT := Color(0.95, 0.68, 0.22)
const PICK := Color(0.6, 0.62, 0.7)


func _draw() -> void:
	var c := Game.CELL
	for it in _crew:
		var x: float = it["x"]
		var a: float = it["anim"]
		var dir: float = it["dir"]
		var carrying := int(it["n"]) > 0
		var frame := "stand"
		match it["state"]:
			"to_rock", "to_dig", "to_truck":
				frame = ("carry_" if carrying else "walk_") + ("a" if fmod(a, TAU) < PI else "b")
			"digging":
				frame = "dig_a" if fmod(a, TAU) < PI else "dig_b"
			_:
				frame = "carry_a" if carrying else "stand"
		var rows: Array = FRAMES[frame]
		var h := rows.size()
		# Feet on the ground, everything snapped to the mountain's pixel grid.
		var base := Vector2(roundf(x / c) * c, roundf(_ground_y(x) / c) * c)
		var top_left := base - Vector2(1.5 * c, h * c)
		for ry in h:
			var row: String = rows[ry]
			for rx in row.length():
				var ch := row[rx]
				if ch == ".":
					continue
				var col := BODY if ch == "o" else (HAT if ch == "h" else PICK)
				var px := rx if dir >= 0 else (2 - rx)
				draw_rect(Rect2(top_left + Vector2(px, ry) * c, Vector2(c, c)), col)
		if carrying:
			var n := mini(int(it["n"]), 9)
			Rock.draw_blob(self, top_left + Vector2(1.5 * c, -1.5 * c), n, it["cols"], c)
