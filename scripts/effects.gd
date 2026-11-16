class_name Effects
extends Node2D
## Cheap visual effects drawn in one node: debris pixels, gun tracers,
## explosion flashes and smoke.

const MAX_PARTICLES := 1500
const GRAVITY := 900.0

var _pos: PackedVector2Array = []
var _vel: PackedVector2Array = []
var _life: PackedFloat32Array = []
var _col: PackedColorArray = []
var _size: PackedFloat32Array = []
var _gravity: PackedFloat32Array = []
var _tracers: Array = []   # [from, to, life, color]
var _flashes: Array = []   # [pos, radius, life, max_life, color]
var _rings: Array = []     # [pos, radius, life, max_life, color]
var _sparkles: Array = []  # [pos, life, color]
var _pops: Array = []      # [pos, text, color, life, max_life, size]
var _font: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")


func debris(at: Vector2, color: Color, size: float, power := 1.0) -> void:
	_add(at, Vector2(randf_range(-90, 90), randf_range(-260, -60)) * power, randf_range(0.5, 1.0), color, size, GRAVITY)


func smoke(at: Vector2, size: float, life := 1.6, color := Color(0.35, 0.33, 0.32, 0.7), rise := 60.0) -> void:
	_add(at, Vector2(randf_range(-30, 30), -randf_range(rise * 0.5, rise)), life, color, size, -10.0)


func tracer(from: Vector2, to: Vector2, color := Color(1, 0.9, 0.5)) -> void:
	_tracers.append([from, to, 0.06, color])


func flash(at: Vector2, radius: float, color := Color(1, 0.85, 0.4), life := 0.25) -> void:
	_flashes.append([at, radius, life, life, color])


## Expanding thin circle (clicks, landings).
func ring(at: Vector2, radius: float, color := Color(1, 0.9, 0.7, 0.8), life := 0.25) -> void:
	_rings.append([at, radius, life, life, color])


## Little four-point glint.
func sparkle(at: Vector2, color: Color) -> void:
	if _sparkles.size() < 60:
		_sparkles.append([at, 0.5, color])


## Floating text that stays the same size on screen whatever the zoom.
func pop(at: Vector2, text: String, color := Color.WHITE, size := 12, life := 0.9) -> void:
	if _pops.size() > 40:
		_pops.pop_front()
	_pops.append([at + Vector2(randf_range(-4, 4), 0), text, color, life, life, size])


## Gold coins bursting out (truck sold its load).
func coins(at: Vector2, count: int) -> void:
	for i in count:
		var c := Color(1, 0.82, 0.3) if i % 3 else Color(1, 0.95, 0.6)
		_add(at, Vector2(randf_range(-160, 160), randf_range(-420, -180)), randf_range(0.8, 1.4), c, randf_range(3, 5), GRAVITY)


func dust(at: Vector2, amount := 4) -> void:
	for i in amount:
		_add(at + Vector2(randf_range(-4, 4), -1), Vector2(randf_range(-50, 50), randf_range(-30, -5)), randf_range(0.3, 0.6), Color(0.5, 0.45, 0.45, 0.5), randf_range(2, 4), 40.0)


func explosion(at: Vector2, radius: float) -> void:
	flash(at, radius * 1.3)
	flash(at, radius * 0.7, Color(1, 1, 0.9), 0.12)
	for i in int(clampf(radius * 0.8, 8, 60)):
		var c: Color = [Color(1, 0.8, 0.2), Color(1, 0.45, 0.1), Color(0.3, 0.3, 0.3)][i % 3]
		_add(at, Vector2.from_angle(randf() * TAU) * randf_range(radius * 2.0, radius * 6.0), randf_range(0.3, 0.8), c, randf_range(3, 7), GRAVITY * 0.5)
	for i in int(clampf(radius * 0.3, 4, 30)):
		smoke(at + Vector2(randf_range(-radius, radius), randf_range(-radius, radius) * 0.5), randf_range(8, 18))


func _add(at: Vector2, vel: Vector2, life: float, color: Color, size: float, grav: float) -> void:
	if _pos.size() >= MAX_PARTICLES:
		return
	_pos.append(at)
	_vel.append(vel)
	_life.append(life)
	_col.append(color)
	# Everything is built from mountain-sized pixels.
	_size.append(maxf(1.0, roundf(size / Game.CELL)) * Game.CELL)
	_gravity.append(grav)


func _process(delta: float) -> void:
	var i := _pos.size() - 1
	while i >= 0:
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
		else:
			_vel[i] = _vel[i] + Vector2(0, _gravity[i] * delta)
			var p := _pos[i] + _vel[i] * delta
			if p.y > 0.0 and _gravity[i] > 0.0:
				p.y = 0.0
				_vel[i] = Vector2(_vel[i].x * 0.5, -_vel[i].y * 0.3)
			_pos[i] = p
		i -= 1
	for t in _tracers:
		t[2] -= delta
	_tracers = _tracers.filter(func(t): return t[2] > 0.0)
	for f in _flashes:
		f[2] -= delta
	_flashes = _flashes.filter(func(f): return f[2] > 0.0)
	for r in _rings:
		r[2] -= delta
	_rings = _rings.filter(func(r): return r[2] > 0.0)
	for sp in _sparkles:
		sp[1] -= delta
	_sparkles = _sparkles.filter(func(sp): return sp[1] > 0.0)
	for p in _pops:
		p[3] -= delta
		p[0] = (p[0] as Vector2) + Vector2(0, -40.0 * delta / _zoom())
	_pops = _pops.filter(func(p): return p[3] > 0.0)
	queue_redraw()


## A filled circle made of mountain-sized pixels.
func _pixel_disc(center: Vector2, radius: float, c: Color) -> void:
	var cell := Game.CELL
	var cc := (center / cell).round()
	var r := int(ceil(radius / cell))
	var r2 := (radius / cell) * (radius / cell)
	for dy in range(-r, r + 1):
		# One rect per row keeps this cheap even for a nuke.
		var half := sqrt(maxf(0.0, r2 - dy * dy))
		var span := int(floor(half))
		if span <= 0 and dy * dy > r2:
			continue
		draw_rect(Rect2((cc + Vector2(-span, dy)) * cell - Vector2(cell, cell) * 0.5, Vector2(span * 2 + 1, 1) * cell), c)


## A circle outline made of mountain-sized pixels.
func _pixel_ring(center: Vector2, radius: float, c: Color) -> void:
	var cell := Game.CELL
	var cc := (center / cell).round()
	var steps := maxi(8, int(radius / cell * 6.0))
	var last := Vector2(INF, INF)
	for i in steps:
		var p := (cc + Vector2.from_angle(TAU * i / steps) * radius / cell).round()
		if p != last:
			draw_rect(Rect2(p * cell - Vector2(cell, cell) * 0.5, Vector2(cell, cell)), c)
			last = p


func _zoom() -> float:
	return maxf(get_viewport().get_canvas_transform().get_scale().x, 0.01)


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_life[i] = _life[last]
	_col[i] = _col[last]
	_size[i] = _size[last]
	_gravity[i] = _gravity[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_col.resize(last)
	_size.resize(last)
	_gravity.resize(last)


func _draw() -> void:
	var cell := Game.CELL
	for f in _flashes:
		var t: float = f[2] / f[3]
		var c: Color = f[4]
		c.a = t * 0.85
		_pixel_disc(f[0], f[1] * (1.4 - 0.4 * t), c)
	for i in _pos.size():
		var s := _size[i]
		var c := _col[i]
		if _gravity[i] < 0.0:
			c.a *= clampf(_life[i], 0.0, 1.0)
			s = roundf(s * (1.0 + (1.6 - _life[i]) * 0.6) / cell) * cell
		var p := (_pos[i] / cell).round() * cell
		draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), c)
	for t in _tracers:
		draw_line(t[0], t[1], t[3], 1.5)
	var inv := 1.0 / _zoom()
	for r in _rings:
		var t: float = 1.0 - r[2] / r[3]
		var c: Color = r[4]
		c.a *= 1.0 - t
		_pixel_ring(r[0], (r[1] as float) * (0.4 + 0.8 * t), c)
	for sp in _sparkles:
		var t: float = sp[1] / 0.5
		var c: Color = sp[2]
		c.a = sin(t * PI)
		var p: Vector2 = ((sp[0] as Vector2) / cell).round() * cell - Vector2(cell, cell) * 0.5
		draw_rect(Rect2(p, Vector2(cell, cell)), c)
		if t > 0.3 and t < 0.7:
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_rect(Rect2(p + d * cell, Vector2(cell, cell)), Color(c, c.a * 0.5))
	for p in _pops:
		var t: float = p[3] / p[4]
		var c: Color = p[2]
		c.a = clampf(t * 2.0, 0.0, 1.0)
		var punch := 1.0 + 0.5 * maxf(0.0, (t - 0.8) * 5.0)
		draw_set_transform(p[0], 0, Vector2(inv, inv) * punch)
		var size: int = p[5]
		var w := _font.get_string_size(p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string_outline(_font, Vector2(-w * 0.5, 0), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, c.a))
		draw_string(_font, Vector2(-w * 0.5, 0), p[1], HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
	draw_set_transform(Vector2.ZERO)
