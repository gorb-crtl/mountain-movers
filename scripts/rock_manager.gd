class_name RockManager
extends Node2D
## Spawns, tracks and merges loose rocks. Keeps the count capped so the physics
## engine survives a nuke.

const MAX_ROCKS := 170
const MAX_PIXELS_PER_ROCK := 36

var rocks: Array[Rock] = []


func _physics_process(_delta: float) -> void:
	# Tidy up anything that fell out of the world.
	for i in range(rocks.size() - 1, -1, -1):
		var r := rocks[i]
		if not is_instance_valid(r):
			rocks.remove_at(i)
		elif r.position.y > 400.0:
			remove(r)


## Turns a mountain harvest into flying rocks. `blast_center` pushes them outward.
func spawn_harvest(harvest: Dictionary, blast_center: Vector2, power: float, bucket_cells := 3.0) -> void:
	var n: int = harvest.get("n", 0)
	if n == 0:
		return
	var pos: PackedVector2Array = harvest["pos"]
	var cols: PackedColorArray = harvest["colors"]
	var vals: PackedFloat32Array = harvest["vals"]
	var bucket := Game.CELL * bucket_cells
	var groups := {}
	for i in n:
		var key := Vector2i(floori(pos[i].x / bucket), floori(pos[i].y / bucket))
		if not groups.has(key):
			groups[key] = {"n": 0, "v": 0.0, "c": PackedColorArray(), "p": Vector2.ZERO}
		var g: Dictionary = groups[key]
		g["n"] = int(g["n"]) + 1
		g["v"] = float(g["v"]) + vals[i]
		var gc: PackedColorArray = g["c"]
		gc.append(cols[i])
		g["c"] = gc
		g["p"] = (g["p"] as Vector2) + pos[i]
	for key in groups:
		var g: Dictionary = groups[key]
		var gn: int = g["n"]
		var center: Vector2 = (g["p"] as Vector2) / float(gn)
		var dir := (center - blast_center).normalized()
		if dir == Vector2.ZERO:
			dir = Vector2.UP
		var vel := (dir * power + Vector2(randf_range(-40, 40), -power * 0.5)) if power > 0.0 else Vector2(randf_range(-20, 20), 0)
		spawn(gn, float(g["v"]), g["c"], center, vel)


## Spawns one rock (or merges it into a neighbour when there are too many).
func spawn(n: int, value: float, cols: PackedColorArray, at: Vector2, vel := Vector2.ZERO, find_name := "") -> Rock:
	if n <= 0:
		return null
	if find_name == "" and rocks.size() >= MAX_ROCKS:
		var target := _nearest(at, INF, true)
		if target:
			target.absorb(n, value, cols)
			return target
	while find_name == "" and n > MAX_PIXELS_PER_ROCK and rocks.size() < MAX_ROCKS:
		var part := MAX_PIXELS_PER_ROCK
		var frac := float(part) / float(n)
		spawn(part, value * frac, cols.slice(0, int(cols.size() * frac)), at + Vector2(randf_range(-6, 6), randf_range(-6, 0)), vel)
		cols = cols.slice(int(cols.size() * frac))
		value -= value * frac
		n -= part
	var r := Rock.new()
	r.position = at
	r.linear_velocity = vel
	r.angular_velocity = randf_range(-4, 4)
	add_child(r)
	r.setup(n, value, cols if not cols.is_empty() else PackedColorArray([Color(0.5, 0.5, 0.5)]), find_name)
	rocks.append(r)
	return r


func remove(r: Rock) -> void:
	rocks.erase(r)
	if is_instance_valid(r):
		r.queue_free()


## Nearest rock to a point within max_dist (edge distance), optionally ignoring finds.
func _nearest(at: Vector2, max_dist: float, skip_finds := false) -> Rock:
	var best: Rock = null
	var best_d := max_dist
	for r in rocks:
		if not is_instance_valid(r) or (skip_finds and r.find_name != ""):
			continue
		var d := r.position.distance_to(at) - r.radius
		if d < best_d:
			best_d = d
			best = r
	return best


func rock_at(at: Vector2, slack := 6.0) -> Rock:
	return _nearest(at, slack)


## A rock lying on the ground that no intern has claimed yet, nearest to x.
func free_ground_rock(near_x: float, exclude_rect: Rect2) -> Rock:
	var best: Rock = null
	var best_d := INF
	for r in rocks:
		if not is_instance_valid(r) or r.claimed_by != null:
			continue
		if r.position.y < -r.radius - 12.0 or r.linear_velocity.length() > 40.0:
			continue  # still flying / sitting up high
		if exclude_rect.has_point(r.position):
			continue
		var d := absf(r.position.x - near_x)
		if d < best_d:
			best_d = d
			best = r
	return best


func total_value() -> float:
	var v := 0.0
	for r in rocks:
		if is_instance_valid(r):
			v += r.value
	return v


func clear_all() -> void:
	for r in rocks:
		if is_instance_valid(r):
			r.queue_free()
	rocks.clear()


func serialize() -> Array:
	var out := []
	for r in rocks:
		if is_instance_valid(r):
			var hexes := []
			for c in r.colors.slice(0, 9):
				hexes.append(c.to_html(false))
			out.append([r.position.x, r.position.y, r.pixels, r.value, r.find_name, hexes])
	return out


func deserialize(list: Array) -> void:
	clear_all()
	for e in list:
		var cols := PackedColorArray()
		for h in e[5]:
			cols.append(Color(h))
		spawn(int(e[2]), float(e[3]), cols, Vector2(float(e[0]), minf(float(e[1]), -10.0)), Vector2.ZERO, str(e[4]))
