extends Node2D
## Placeholder sky, distant hills and ground, drawn in code.
## Replace with a TextureRect / parallax layers once real art exists.

const GROUND_Y := 670.0
var _t := 0.0
var _clouds: Array = []


func _ready() -> void:
	for i in 6:
		_clouds.append(Vector3(randf_range(0, 940), randf_range(70, 260), randf_range(8, 22)))


func _process(delta: float) -> void:
	_t += delta
	for i in _clouds.size():
		var c: Vector3 = _clouds[i]
		c.x += c.z * delta
		if c.x > 980:
			c.x = -120
		_clouds[i] = c
	queue_redraw()


func _draw() -> void:
	# Sky in chunky bands for a pixel-art feel.
	var top := Color(0.36, 0.62, 0.92)
	var bottom := Color(0.98, 0.84, 0.62)
	var bands := 12
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, i * GROUND_Y / bands, 1280, GROUND_Y / bands + 1), top.lerp(bottom, t))
	draw_circle(Vector2(820, 140), 34, Color(1, 0.95, 0.6))
	for c in _clouds:
		var p := Vector2(c.x, c.y)
		for k in 4:
			draw_rect(Rect2(p + Vector2(k * 18, -8 * (k % 2)), Vector2(36, 18)), Color(1, 1, 1, 0.85))
	# Distant hills (a mountain's smug cousins).
	var hills := PackedVector2Array([Vector2(0, GROUND_Y)])
	for x in range(0, 960, 40):
		hills.append(Vector2(x, GROUND_Y - 110 - 60 * sin(x * 0.012) - 30 * sin(x * 0.031)))
	hills.append(Vector2(960, GROUND_Y))
	draw_colored_polygon(hills, Color(0.55, 0.62, 0.78))
	# Ground.
	draw_rect(Rect2(0, GROUND_Y, 1280, 50), Color(0.33, 0.55, 0.25))
	draw_rect(Rect2(0, GROUND_Y + 8, 1280, 42), Color(0.42, 0.30, 0.20))
