extends Node2D
## Placeholder ground, drawn in world space under everything.
## The sky lives in SkyLayer (screen space). Swap either for real art later.

const GROUND_COLOR := Color(0.42, 0.30, 0.20)
const GRASS_COLOR := Color(0.33, 0.55, 0.25)


func _draw() -> void:
	draw_rect(Rect2(-8000, 0, 16000, 2000), GROUND_COLOR)
	draw_rect(Rect2(-8000, 0, 16000, 6), GRASS_COLOR)
	# A road for the trucks, heading off to the quarry on the left.
	draw_rect(Rect2(-8000, 6, 7800, 10), Color(0.30, 0.28, 0.27))
	for x in range(-8000, -200, 60):
		draw_rect(Rect2(x, 10, 26, 2), Color(0.9, 0.85, 0.5))
