class_name Debris
extends Node2D
## Cheap pixel particles for rocks flying off the mountain.

const MAX_PARTICLES := 1500
const GRAVITY := 900.0

var _pos: PackedVector2Array = []
var _vel: PackedVector2Array = []
var _life: PackedFloat32Array = []
var _col: PackedColorArray = []
var _size: PackedFloat32Array = []


func spawn(at: Vector2, color: Color, size: float, power := 1.0) -> void:
	if _pos.size() >= MAX_PARTICLES:
		return
	_pos.append(at)
	_vel.append(Vector2(randf_range(-90, 90), randf_range(-260, -60)) * power)
	_life.append(randf_range(0.6, 1.2))
	_col.append(color)
	_size.append(maxf(2.0, size))


func _process(delta: float) -> void:
	var i := _pos.size() - 1
	while i >= 0:
		_life[i] -= delta
		if _life[i] <= 0.0 or _pos[i].y > 740.0:
			_remove(i)
		else:
			_vel[i] = _vel[i] + Vector2(0, GRAVITY * delta)
			_pos[i] = _pos[i] + _vel[i] * delta
		i -= 1
	queue_redraw()


func _remove(i: int) -> void:
	var last := _pos.size() - 1
	_pos[i] = _pos[last]
	_vel[i] = _vel[last]
	_life[i] = _life[last]
	_col[i] = _col[last]
	_size[i] = _size[last]
	_pos.resize(last)
	_vel.resize(last)
	_life.resize(last)
	_col.resize(last)
	_size.resize(last)


func _draw() -> void:
	for i in _pos.size():
		var s := _size[i]
		draw_rect(Rect2(_pos[i] - Vector2(s, s) * 0.5, Vector2(s, s)), _col[i])
