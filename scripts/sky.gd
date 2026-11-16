extends Control
## Screen-space backdrop: a dark gradient, faint stars, drifting dust and far
## ridges. Placeholder art; swap for a texture whenever.

const TOP := Color(0.035, 0.032, 0.05)
const BOTTOM := Color(0.10, 0.085, 0.12)

var _stars: Array = []
var _dust: Array = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	for i in 70:
		_stars.append(Vector3(randf() * 1280, randf() * 420, randf()))
	for i in 40:
		_dust.append(Vector4(randf() * 1280, randf() * 720, randf_range(4, 14), randf_range(1, 2)))


func _process(delta: float) -> void:
	_t += delta
	for i in _dust.size():
		var d: Vector4 = _dust[i]
		d.x += d.z * delta
		d.y += sin(_t * 0.5 + i) * 3.0 * delta
		if d.x > size.x + 10:
			d.x = -10
		_dust[i] = d
	queue_redraw()


func _draw() -> void:
	var bands := 24
	var h := size.y
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, i * h / bands, size.x, h / bands + 1), TOP.lerp(BOTTOM, t))
	for s in _stars:
		var tw := 0.25 + 0.2 * sin(_t * (0.6 + s.z) + s.x)
		draw_rect(Rect2(s.x, s.y, 1 + int(s.z > 0.85), 1 + int(s.z > 0.85)), Color(0.85, 0.82, 0.95, tw * (0.4 + s.z * 0.6)))
	# A big, dim moon.
	draw_circle(Vector2(size.x * 0.66, 130), 46, Color(0.16, 0.15, 0.19))
	draw_circle(Vector2(size.x * 0.66 - 10, 122), 40, Color(0.19, 0.18, 0.22))
	# Far ridges, two layers.
	for layer in 2:
		var pts := PackedVector2Array([Vector2(0, h)])
		var base := h * (0.70 + 0.06 * layer)
		for x in range(0, int(size.x) + 40, 24):
			var y := base - (45 - layer * 15) * sin(x * (0.007 + layer * 0.004) + layer) - 22 * sin(x * 0.023 + layer * 2.0)
			pts.append(Vector2(x, y))
		pts.append(Vector2(size.x, h))
		draw_colored_polygon(pts, Color(0.075, 0.068, 0.095) if layer == 0 else Color(0.06, 0.055, 0.075))
	for d in _dust:
		draw_rect(Rect2(d.x, d.y, d.w, d.w), Color(0.9, 0.8, 0.7, 0.07))
