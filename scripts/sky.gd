extends Control
## Screen-space sky with drifting clouds, sun and far hills (placeholder).

var _clouds: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size)
	for i in 7:
		_clouds.append(Vector3(randf_range(0, 1280), randf_range(70, 300), randf_range(6, 18)))


func _process(delta: float) -> void:
	for i in _clouds.size():
		var c: Vector3 = _clouds[i]
		c.x += c.z * delta
		if c.x > 1320:
			c.x = -140
		_clouds[i] = c
	queue_redraw()


func _draw() -> void:
	var top := Color(0.36, 0.62, 0.92)
	var bottom := Color(0.98, 0.84, 0.62)
	var bands := 14
	var h := size.y
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, i * h / bands, size.x, h / bands + 1), top.lerp(bottom, t))
	draw_circle(Vector2(size.x * 0.62, 140), 34, Color(1, 0.95, 0.6))
	for c in _clouds:
		var p := Vector2(c.x, c.y)
		for k in 4:
			draw_rect(Rect2(p + Vector2(k * 18, -8 * (k % 2)), Vector2(36, 18)), Color(1, 1, 1, 0.85))
	var hills := PackedVector2Array([Vector2(0, h)])
	for x in range(0, int(size.x) + 40, 40):
		hills.append(Vector2(x, h * 0.72 - 50 * sin(x * 0.009) - 25 * sin(x * 0.027)))
	hills.append(Vector2(size.x, h))
	draw_colored_polygon(hills, Color(0.58, 0.64, 0.80))
