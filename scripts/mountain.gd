class_name Mountain
extends Node2D
## The destructible mountain: a big grid of pixels, each with a material and HP.
## Rendered as a single Image/texture that is patched as pixels change.
## The bottom edge of the grid sits on the ground (node position is its top-left).
## Digging returns a "harvest" of the pixels that broke off, which the caller
## turns into rocks (in your hand, on the ground, in a bird's claws...).

signal item_found(item_name: String, base_value: float, mat: int, world_pos: Vector2)
signal cleared

## Once this fraction (or less) of the mountain is left, the rest crumbles.
const CLEAR_THRESHOLD := 0.005

var w := 0
var h := 0
var cell_scale := 1.0
var hp_mult := 1.0
var mat := PackedByteArray()
var hp := PackedFloat32Array()
var item_of := PackedInt32Array()   # cell -> item id (0 = none)
var items: Dictionary = {}          # item id -> {"name", "value", "left"}
var initial_solid := 0
var solid := 0
var top := PackedInt32Array()       # per column: y of the top-most solid pixel (h if none)
var _harvesting := false
var _h_n := 0
var _h_value := 0.0
var _h_cols := PackedColorArray()
var _h_pos := PackedVector2Array()
var _h_vals := PackedFloat32Array()

var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _dirty := false
var _cleared := false
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _process(_delta: float) -> void:
	if _dirty and _texture:
		_texture.update(_image)
		_dirty = false


# ------------------------------------------------------------- generation

func generate(p_w: int, p_h: int, seed_value: int, p_hp_mult: float, luck: float, level: int) -> void:
	w = p_w
	h = p_h
	hp_mult = p_hp_mult
	initial_solid = 0
	_rng.seed = seed_value
	var n := w * h
	mat.resize(n)
	mat.fill(Materials.AIR)
	item_of.resize(n)
	item_of.fill(0)
	items.clear()

	var shape := FastNoiseLite.new()
	shape.seed = seed_value
	shape.frequency = 4.0 / float(w)
	var vein_a := FastNoiseLite.new()
	vein_a.seed = seed_value + 11
	vein_a.frequency = 0.09
	var vein_b := FastNoiseLite.new()
	vein_b.seed = seed_value + 23
	vein_b.frequency = 0.07
	var layer := FastNoiseLite.new()
	layer.seed = seed_value + 37
	layer.frequency = 0.05

	# Height profile: a lumpy peak, a bit off-centre so each mountain differs.
	var peak := (w - 1) * _rng.randf_range(0.4, 0.6)
	var surface := PackedInt32Array()
	surface.resize(w)
	for x in w:
		var half := peak if x < peak else (w - 1) - peak
		var t := clampf(absf(x - peak) / maxf(half, 1.0), 0.0, 1.0)
		var height := h * (0.55 * pow(1.0 - t, 1.15) + 0.42 * (1.0 - t * t))
		height += shape.get_noise_1d(x) * h * 0.12 * (1.0 - t * 0.6)
		height = clampf(height, 1.0, h - 1.0)
		surface[x] = h - int(height)

	var off := (luck - 1.0) * 0.15
	for x in w:
		for y in range(surface[x], h):
			var depth := y - surface[x]
			var depth_frac := float(y) / float(h) # 0 top of grid, 1 at ground
			var m := Materials.STONE
			var ln := layer.get_noise_2d(x, y)
			if depth < 2 + int(2.0 * (ln + 1.0)):
				m = Materials.DIRT
			elif depth_frac + ln * 0.25 > 0.62:
				m = Materials.HARD_ROCK
			var a := vein_a.get_noise_2d(x, y)
			var b := vein_b.get_noise_2d(x, y)
			if depth > 2 and a > 0.42 - off:
				m = Materials.COPPER
			elif depth > 5 and b > 0.5 - off:
				m = Materials.IRON
			elif depth > 8 and depth_frac > 0.35 and a < -0.55 + off:
				m = Materials.GOLD
			elif depth > 10 and depth_frac > 0.5 and _rng.randf() < 0.0025 * luck:
				m = Materials.GEM
			mat[y * w + x] = m

	# Bury fossils and artefacts.
	var area := float(w * h)
	_place_finds(Materials.FOSSILS, Materials.FOSSIL, int(2 + area / 2500.0 * luck), surface)
	_place_finds(Materials.ARTEFACTS, Materials.ARTEFACT, int(1 + area / 5000.0 * luck), surface)
	_rebuild()


func _place_finds(defs: Array, find_mat: int, count: int, surface: PackedInt32Array) -> void:
	for _i in count:
		var def: Dictionary = defs[_rng.randi() % defs.size()]
		var pattern: Array = def["pattern"]
		var ph := pattern.size()
		var pw: int = (pattern[0] as String).length()
		for _attempt in 40:
			var x0 := _rng.randi_range(0, w - pw)
			var y0 := _rng.randi_range(0, h - ph)
			if not _fits(pattern, x0, y0, surface):
				continue
			var id := items.size() + 1
			while items.has(id):
				id += 1
			var cells := 0
			for py in ph:
				var row: String = pattern[py]
				for px in pw:
					if row[px] == "X":
						var i := (y0 + py) * w + (x0 + px)
						mat[i] = find_mat
						item_of[i] = id
						cells += 1
			items[id] = {"name": def["name"], "value": def["value"], "left": cells}
			break


func _fits(pattern: Array, x0: int, y0: int, surface: PackedInt32Array) -> bool:
	for py in pattern.size():
		var row: String = pattern[py]
		for px in row.length():
			var x := x0 + px
			var y := y0 + py
			if y < surface[x] + 3:
				return false
			var i := y * w + x
			if item_of[i] != 0:
				return false
	return true


func _rebuild() -> void:
	var n := w * h
	hp.resize(n)
	solid = 0
	_image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	for i in n:
		var m := mat[i]
		if m == Materials.AIR:
			hp[i] = 0.0
			continue
		solid += 1
		hp[i] = _max_hp(m)
		_image.set_pixel(i % w, i / w, _cell_color(i))
	top.resize(w)
	for x in w:
		_rescan_top(x, 0)
	initial_solid = maxi(initial_solid, solid) if initial_solid > 0 else solid
	_cleared = false
	_texture = ImageTexture.create_from_image(_image)
	_sprite.texture = _texture
	_dirty = false


func _max_hp(m: int) -> float:
	return float(Materials.DATA[m]["hp"]) * hp_mult


# --------------------------------------------------------------- display

## World-space y of the walkable surface at world x (mountain top or ground).
func surface_y_at(world_x: float) -> float:
	var x := floori((world_x - global_position.x) / cell_scale)
	if x < 0 or x >= w:
		return global_position.y + h * cell_scale
	return global_position.y + top[x] * cell_scale


func set_cell_scale(s: float) -> void:
	cell_scale = s
	_sprite.scale = Vector2(s, s)


func pixel_size() -> Vector2:
	return Vector2(w, h) * cell_scale


func world_to_cell(world: Vector2) -> Vector2i:
	var local := (world - global_position) / cell_scale
	return Vector2i(floori(local.x), floori(local.y))


func cell_to_world(c: Vector2i) -> Vector2:
	return global_position + (Vector2(c) + Vector2(0.5, 0.5)) * cell_scale


func _base_color(i: int) -> Color:
	var base: Color = Materials.DATA[mat[i]]["color"]
	var x := i % w
	var y := i / w
	var hsh := posmod((x * 73856093) ^ (y * 19349663), 9)
	var v := (float(hsh) - 4.0) * 0.03
	return base.lightened(v) if v > 0.0 else base.darkened(-v)


func _cell_color(i: int) -> Color:
	var c := _base_color(i)
	var dmg := 1.0 - hp[i] / _max_hp(mat[i])
	if dmg > 0.0:
		c = c.darkened(dmg * 0.55)
	return c


# ------------------------------------------------------------- digging

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func is_solid(c: Vector2i) -> bool:
	return in_bounds(c) and mat[c.y * w + c.x] != Materials.AIR


func _begin_harvest() -> void:
	_harvesting = true
	_h_n = 0
	_h_value = 0.0
	_h_cols = PackedColorArray()
	_h_pos = PackedVector2Array()
	_h_vals = PackedFloat32Array()


func _end_harvest() -> Dictionary:
	_harvesting = false
	return {"n": _h_n, "value": _h_value, "colors": _h_cols, "pos": _h_pos, "vals": _h_vals}


## Damages every pixel within `radius` cells of `center`.
## Returns a harvest: {"n", "value", "colors", "pos", "vals"} of the pixels that broke off.
func damage_circle(center: Vector2i, radius: float, dmg: float, falloff := false) -> Dictionary:
	_begin_harvest()
	var r := int(ceil(radius))
	var r2 := radius * radius
	for dy in range(-r, r + 1):
		var y := center.y + dy
		if y < 0 or y >= h:
			continue
		for dx in range(-r, r + 1):
			var x := center.x + dx
			if x < 0 or x >= w:
				continue
			var d2 := float(dx * dx + dy * dy)
			if d2 > r2:
				continue
			var amount := dmg
			if falloff:
				amount = dmg * (1.0 - 0.6 * sqrt(d2) / maxf(radius, 1.0))
			_damage(y * w + x, amount)
	return _end_harvest()


## Damages a rectangle of cells (used by bulldozers).
func damage_rect(rect: Rect2i, dmg: float) -> Dictionary:
	_begin_harvest()
	for y in range(maxi(rect.position.y, 0), mini(rect.end.y, h)):
		for x in range(maxi(rect.position.x, 0), mini(rect.end.x, w)):
			_damage(y * w + x, dmg)
	return _end_harvest()


## Removes every pixel in a circle outright, no HP check (the bird).
func scoop_circle(center: Vector2i, radius: float) -> Dictionary:
	return damage_circle(center, radius, INF)


## Damages the top `depth` pixels of every column (earthquake).
func damage_surface(depth: int, dmg: float) -> Dictionary:
	_begin_harvest()
	for x in w:
		var y0 := top[x]
		for y in range(y0, mini(y0 + depth, h)):
			_damage(y * w + x, dmg)
	return _end_harvest()


func _damage(i: int, amount: float) -> bool:
	if mat[i] == Materials.AIR:
		return false
	hp[i] -= amount
	if hp[i] > 0.0:
		_image.set_pixel(i % w, i / w, _cell_color(i))
		_dirty = true
		return false
	_destroy(i)
	return true


func _destroy(i: int) -> void:
	var m := mat[i]
	var col := _base_color(i)
	var c := Vector2i(i % w, i / w)
	mat[i] = Materials.AIR
	hp[i] = 0.0
	solid -= 1
	Game.stats["pixels"] = int(Game.stats["pixels"]) + 1
	_image.set_pixel(c.x, c.y, Color(0, 0, 0, 0))
	_dirty = true
	if c.y == top[c.x]:
		_rescan_top(c.x, c.y)
	var wp := cell_to_world(c)
	if _harvesting:
		var pv := Game.pixel_value(m)
		_h_n += 1
		_h_value += pv
		_h_vals.append(pv)
		_h_cols.append(col)
		_h_pos.append(wp)
	var id := item_of[i]
	if id != 0:
		item_of[i] = 0
		if items.has(id):
			var it: Dictionary = items[id]
			it["left"] = int(it["left"]) - 1
			if int(it["left"]) <= 0:
				items.erase(id)
				item_found.emit(it["name"], float(it["value"]), m, wp)
	if not _cleared and solid <= int(initial_solid * CLEAR_THRESHOLD):
		_cleared = true
		_finish_clear.call_deferred()


func _rescan_top(x: int, from_y: int) -> void:
	var y := from_y
	while y < h and mat[y * w + x] == Materials.AIR:
		y += 1
	top[x] = y


func _finish_clear() -> void:
	_harvesting = false
	for i in w * h:
		if mat[i] != Materials.AIR:
			_destroy(i)
	cleared.emit()


## Debug / cheat: remove everything right now.
func force_clear() -> void:
	if _cleared:
		return
	_cleared = true
	_finish_clear()


func moved_fraction() -> float:
	if initial_solid == 0:
		return 0.0
	return 1.0 - float(solid) / float(initial_solid)


## Top-most solid pixel of a random column (where an intern would dig).
func random_surface_cell() -> Vector2i:
	for _attempt in 12:
		var x := _rng.randi_range(0, w - 1)
		if top[x] < h:
			return Vector2i(x, top[x])
	return Vector2i(-1, -1)


## Top-most solid pixel near world x (searching outwards), or (-1,-1).
func surface_cell_near(world_x: float, search := 40) -> Vector2i:
	var cx := floori((world_x - global_position.x) / cell_scale)
	for d in search:
		for x in [cx - d, cx + d]:
			if x >= 0 and x < w and top[x] < h:
				return Vector2i(x, top[x])
	return Vector2i(-1, -1)


## Solid pixel nearest to a world point along the line towards `from` (for guns).
func first_solid_towards(target: Vector2i, from_world: Vector2) -> Vector2i:
	var start := world_to_cell(from_world)
	var steps := maxi(absi(target.x - start.x), absi(target.y - start.y))
	for i in steps + 1:
		var t := float(i) / maxf(steps, 1.0)
		var c := Vector2i(roundi(lerpf(start.x, target.x, t)), roundi(lerpf(start.y, target.y, t)))
		if is_solid(c):
			return c
	return target


# ------------------------------------------------------------- save / load

func serialize() -> Dictionary:
	var item_list := []
	for id in items:
		var it: Dictionary = items[id]
		item_list.append({"id": id, "name": it["name"], "value": it["value"], "left": it["left"]})
	return {
		"w": w, "h": h, "hp_mult": hp_mult, "initial": initial_solid,
		"mat": Marshalls.raw_to_base64(mat.compress(FileAccess.COMPRESSION_DEFLATE)),
		"item_of": Marshalls.raw_to_base64(item_of.to_byte_array().compress(FileAccess.COMPRESSION_DEFLATE)),
		"items": item_list,
	}


func deserialize(d: Dictionary) -> bool:
	if not d.has("mat"):
		return false
	var nw := int(d["w"])
	var nh := int(d["h"])
	var m := Marshalls.base64_to_raw(d["mat"]).decompress(nw * nh, FileAccess.COMPRESSION_DEFLATE)
	var io := Marshalls.base64_to_raw(d["item_of"]).decompress(nw * nh * 4, FileAccess.COMPRESSION_DEFLATE).to_int32_array()
	if m.size() != nw * nh or io.size() != nw * nh:
		return false
	w = nw
	h = nh
	hp_mult = float(d["hp_mult"])
	mat = m
	item_of = io
	items.clear()
	for it in d.get("items", []):
		items[int(it["id"])] = {"name": it["name"], "value": float(it["value"]), "left": int(it["left"])}
	initial_solid = int(d.get("initial", 0))
	_rebuild()
	return true
