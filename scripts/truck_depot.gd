class_name TruckDepot
extends Node2D
## The dump truck fleet. One truck at a time parks at the loading spot; the rest
## queue behind it. A full truck honks, drives off to sell its load, and comes back.

signal sold(amount: float)

const TRUCK_SCALE := 2.0
const SLOT_SPACING := 112.0
const OFFSCREEN := 1700.0
const DRIVE_SPEED := 220.0

## World x of the parked truck's left edge (set by main).
var spot_x := -220.0
var effects: Effects
var trucks: Array = []     # [{"node", "state", "n", "v", "t", "finds"}]
var line: Array = []       # trucks waiting/loading, front first
var _tex: Texture2D = preload("res://assets/sprites/truck.png")


func _process(delta: float) -> void:
	_sync_count()
	var cap := Game.truck_capacity()
	for i in line.size():
		var tr: Dictionary = line[i]
		var node: Node2D = tr["node"]
		var target := spot_x - i * SLOT_SPACING
		node.position.x = move_toward(node.position.x, target, DRIVE_SPEED * delta)
	var front: Variant = loading_truck()
	if front and int(front["n"]) >= cap:
		front["t"] = float(front["t"]) - delta
		if float(front["t"]) <= 0.0:
			_depart(front)
	for tr in trucks:
		var node: Node2D = tr["node"]
		match tr["state"]:
			"leaving":
				tr["speed"] = float(tr.get("speed", 0.0)) + 500.0 * delta
				node.position.x -= float(tr["speed"]) * delta
				if effects and randf() < 0.5:
					effects.dust(Vector2(node.position.x + 90.0, -2.0), 1)
				if node.position.x < spot_x - OFFSCREEN:
					tr["state"] = "away"
					tr["t"] = Game.truck_trip_time()
					node.visible = false
			"away":
				tr["t"] = float(tr["t"]) - delta
				if float(tr["t"]) <= 0.0:
					var paid := Game.sell_load(float(tr["v"]))
					sold.emit(paid)
					tr["n"] = 0
					tr["v"] = 0.0
					tr["state"] = "line"
					node.visible = true
					node.position.x = spot_x - OFFSCREEN
					line.append(tr)
		node.set("load_frac", float(tr["n"]) / float(cap))
		node.set("label", "%d/%d" % [int(tr["n"]), cap] if tr == front else "")


func _sync_count() -> void:
	while trucks.size() < Game.truck_count():
		_add_truck(0, 0.0, trucks.size() > 0)
	while trucks.size() > Game.truck_count():
		var tr: Dictionary = trucks.pop_back()
		line.erase(tr)
		(tr["node"] as Node2D).queue_free()


func _add_truck(n: int, v: float, drive_in: bool) -> void:
	var node := TruckNode.new()
	node.texture = _tex
	node.position = Vector2(spot_x - (OFFSCREEN if drive_in else line.size() * SLOT_SPACING), 0)
	add_child(node)
	var tr := {"node": node, "state": "line", "n": n, "v": v, "t": 0.6}
	trucks.append(tr)
	line.append(tr)


## The truck currently parked at the loading spot (or null).
func loading_truck() -> Variant:
	if line.is_empty():
		return null
	var tr: Dictionary = line[0]
	if absf((tr["node"] as Node2D).position.x - spot_x) > 2.0:
		return null
	return tr


## Where interns walk to unload (world x).
func unload_x() -> float:
	return spot_x + 64.0 * TRUCK_SCALE * 0.5 + 30.0


## Area above the parked truck's bed. Drop or throw rocks here.
func bed_rect() -> Rect2:
	return Rect2(spot_x + 26.0, -110.0, 76.0, 92.0)


func is_over_bed(p: Vector2) -> bool:
	return loading_truck() != null and bed_rect().has_point(p)


## Puts rock in the parked truck. Returns how many pixels fit.
func deposit(n: int, value: float) -> int:
	var tr: Variant = loading_truck()
	if tr == null or n <= 0:
		return 0
	var cap := Game.truck_capacity()
	var room := cap - int(tr["n"])
	if room <= 0:
		return 0
	var k := mini(room, n)
	tr["n"] = int(tr["n"]) + k
	tr["v"] = float(tr["v"]) + value * float(k) / float(n)
	tr["t"] = 0.6
	Sfx.play("drop", -4.0)
	(tr["node"] as TruckNode).bump()
	return k


## Finds always fit, however full the truck is (the boss insists).
func deposit_find(value: float) -> bool:
	var tr: Variant = loading_truck()
	if tr == null:
		return false
	tr["v"] = float(tr["v"]) + value
	tr["n"] = maxi(int(tr["n"]), 1)
	Sfx.play("find")
	return true


func send_now() -> void:
	var tr: Variant = loading_truck()
	if tr and int(tr["n"]) > 0:
		_depart(tr)


func _depart(tr: Dictionary) -> void:
	line.erase(tr)
	tr["state"] = "leaving"
	tr["speed"] = 0.0
	Sfx.play("horn", -3.0, 0.02)
	Sfx.play("engine", -6.0, 0.05)


## Pulls physics rocks that land in the bed into the truck.
func absorb_rocks(rocks: RockManager) -> void:
	var tr: Variant = loading_truck()
	if tr == null:
		return
	var rect := bed_rect()
	for r in rocks.rocks.duplicate():
		if not is_instance_valid(r) or not rect.has_point(r.position):
			continue
		if r.find_name != "":
			if deposit_find(r.value):
				rocks.remove(r)
			continue
		var k := deposit(r.pixels, r.value)
		if k <= 0:
			return
		r.take(k)
		if r.pixels <= 0:
			rocks.remove(r)


func reset() -> void:
	for tr in trucks:
		(tr["node"] as Node2D).queue_free()
	trucks.clear()
	line.clear()


func serialize() -> Array:
	var out := []
	for tr in trucks:
		out.append([int(tr["n"]), float(tr["v"])])
	return out


func deserialize(list: Array) -> void:
	reset()
	for e in list:
		_add_truck(int(e[0]), float(e[1]), false)


## One truck's sprite plus its load pile and counter.
class TruckNode extends Node2D:
	var texture: Texture2D
	var load_frac := 0.0:
		set(v):
			if absf(v - load_frac) > 0.001:
				load_frac = v
				queue_redraw()
	var label := "":
		set(v):
			if v != label:
				label = v
				queue_redraw()
	var _bump := 0.0

	func bump() -> void:
		_bump = 1.0

	func _process(delta: float) -> void:
		if _bump > 0.0:
			_bump = maxf(0.0, _bump - delta * 5.0)
			queue_redraw()

	func _draw() -> void:
		var s := TruckDepot.TRUCK_SCALE
		var h := texture.get_height() * s
		var off := Vector2(0, -h + _bump * 2.0)
		# Load pile peeking out of the bed.
		if load_frac > 0.0:
			var bed_l := 17.0 * s
			var bed_r := 47.0 * s
			var top := -h + 5.0 * s
			var height := clampf(load_frac, 0.0, 1.0) * 22.0
			var pile := PackedVector2Array([
				Vector2(bed_l, top), Vector2(bed_l + 8, top - height * 0.7),
				Vector2((bed_l + bed_r) * 0.5, top - height), Vector2(bed_r - 8, top - height * 0.75),
				Vector2(bed_r, top)])
			draw_colored_polygon(pile, Color(0.45, 0.42, 0.42))
		draw_texture_rect(texture, Rect2(off, Vector2(texture.get_width(), texture.get_height()) * s), false)
		if label != "":
			var font := ThemeDB.fallback_font
			draw_string_outline(font, Vector2(30, -h - 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(font, Vector2(30, -h - 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.95, 0.6))
