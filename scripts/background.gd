extends Node2D
## Placeholder ground, drawn in world space under everything.
## The sky lives in sky.gd (screen space). Swap either for real art later.

const GROUND_COLOR := Color(0.07, 0.063, 0.085)
const EDGE_COLOR := Color(0.24, 0.21, 0.27)


func _draw() -> void:
	draw_rect(Rect2(-8000, 0, 16000, 2000), GROUND_COLOR)
	draw_rect(Rect2(-8000, 0, 16000, 2), EDGE_COLOR)
	# Speckles so the ground isn't a flat slab.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 900:
		var x := rng.randf_range(-3000, 6000)
		var y := rng.randf_range(4, 200)
		draw_rect(Rect2(x, y, 2, 2), Color(0.16, 0.14, 0.19, 0.6 * (1.0 - y / 220.0)))
	# The road the trucks take to the quarry, off to the left.
	draw_rect(Rect2(-8000, 3, 7800, 6), Color(0.11, 0.10, 0.13))
	for x in range(-8000, -220, 48):
		draw_rect(Rect2(x, 5, 18, 2), Color(0.55, 0.42, 0.2, 0.6))
