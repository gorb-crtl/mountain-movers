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


func debris(at: Vector2, color: Color, size: float, power := 1.0) -> void:
	_add(at, Vector2(randf_range(-90, 90), randf_range(-260, -60)) * power, randf_range(0.5, 1.0), color, size, GRAVITY)


func smoke(at: Vector2, size: float, life := 1.6, color := Color(0.35, 0.33, 0.32, 0.7), rise := 60.0) -> void:
	_add(at, Vector2(randf_range(-30, 30), -randf_range(rise * 0.5, rise)), life, color, size, -10.0)


func tracer(from: Vector2, to: Vector2, color := Color(1, 0.9, 0.5)) -> void:
	_tracers.append([from, to, 0.06, color])


func flash(at: Vector2, radius: float, color := Color(1, 0.85, 0.4), life := 0.25) -> void:
	_flashes.append([at, radius, life, life, color])


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
	_size.append(maxf(2.0, size))
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
	queue_redraw()


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
	for f in _flashes:
		var t: float = f[2] / f[3]
		var c: Color = f[4]
		c.a = t * 0.85
		draw_circle(f[0], f[1] * (1.4 - 0.4 * t), c)
	for i in _pos.size():
		var s := _size[i]
		var c := _col[i]
		if _gravity[i] < 0.0:
			c.a *= clampf(_life[i], 0.0, 1.0)
			s *= 1.0 + (1.6 - _life[i]) * 0.6
		draw_rect(Rect2(_pos[i] - Vector2(s, s) * 0.5, Vector2(s, s)), c)
	for t in _tracers:
		draw_line(t[0], t[1], t[3], 1.5)
