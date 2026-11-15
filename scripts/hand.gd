class_name Hand
extends Node2D
## The player's hand: follows the mouse in the world and holds a fistful of rock.

var n := 0
var value := 0.0
var colors := PackedColorArray()
var finds: Array = []          # [{"name", "value"}] carried fossils/artefacts
var armed_item := ""           # one-use item waiting for a click
var _tex: Texture2D = preload("res://assets/sprites/cursor_hand.png")
var _item_tex: Dictionary = {}


func _ready() -> void:
	z_index = 50
	for id in ["grenade", "bird", "quake", "airstrike", "nuke"]:
		_item_tex[id] = load("res://assets/sprites/%s.png" % id)


func _process(_delta: float) -> void:
	global_position = get_global_mouse_position()
	queue_redraw()


func room() -> int:
	return maxi(0, Game.hand_capacity() - n)


func is_empty() -> bool:
	return n == 0 and finds.is_empty()


func add(k: int, v: float, cols: PackedColorArray) -> void:
	n += k
	value += v
	for c in cols:
		if colors.size() >= Rock.MAX_DRAW:
			break
		colors.append(c)


func clear() -> void:
	n = 0
	value = 0.0
	colors = PackedColorArray()
	finds = []


func _draw() -> void:
	var z := get_viewport().get_canvas_transform().get_scale().x
	var inv := 1.0 / maxf(z, 0.01)
	if armed_item != "":
		var t: Texture2D = _item_tex.get(armed_item)
		if t:
			var sz := t.get_size() * 2.0 * inv
			draw_texture_rect(t, Rect2(Vector2(6, 6) * inv, sz), false)
		draw_arc(Vector2.ZERO, 10.0 * inv, 0, TAU, 20, Color(1, 0.3, 0.2), 2.0 * inv)
		return
	if n > 0:
		var r := clampf(Game.CELL * 0.55 * sqrt(float(n)), 3.0, Rock.MAX_RADIUS)
		Rock.draw_blob(self, Vector2(0, 4.0 * inv + r * 0.4), r, colors)
	for i in finds.size():
		draw_circle(Vector2(10 + i * 6, -6) * inv, 4.0 * inv, Color(1, 0.85, 0.3))
	draw_texture_rect(_tex, Rect2(Vector2(-4, -2) * inv, _tex.get_size() * inv), false)
	if n > 0 or not finds.is_empty():
		var font := ThemeDB.fallback_font
		var txt := "%d/%d" % [n, Game.hand_capacity()]
		draw_set_transform(Vector2(14, 22) * inv, 0, Vector2(inv, inv))
		draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color.BLACK)
		draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE if room() > 0 else Color(1, 0.5, 0.4))
		draw_set_transform(Vector2.ZERO)
