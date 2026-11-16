class_name Hand
extends Node2D
## The player's hand: follows the mouse in the world and holds a fistful of rock.

var n := 0
var value := 0.0
var colors := PackedColorArray()
var finds: Array = []          # [{"name", "value"}] carried fossils/artefacts
var armed_item := ""           # one-use item waiting for a click
var _tex: Texture2D = preload("res://assets/sprites/cursor_hand.png")
var _fist: Texture2D = preload("res://assets/sprites/cursor_fist.png")
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
	# Drawn at the mountain's pixel size, but never smaller than 3 screen pixels
	# per art pixel so it stays usable when zoomed far out.
	var z := get_viewport().get_canvas_transform().get_scale().x
	var px := maxf(Game.CELL, 3.0 / maxf(z, 0.01))
	var inv := 1.0 / maxf(z, 0.01)
	if armed_item != "":
		var t: Texture2D = _item_tex.get(armed_item)
		if t:
			draw_texture_rect(t, Rect2(Vector2(1, 1) * px, t.get_size() * px), false)
		# Pixel crosshair.
		for d in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_rect(Rect2((d - Vector2(0.5, 0.5)) * px, Vector2(px, px)), Color(1, 0.35, 0.25))
		return
	var holding := n > 0 or not finds.is_empty()
	if n > 0:
		Rock.draw_blob(self, Vector2(4, 1) * px, n, colors, px)
	for i in finds.size():
		draw_rect(Rect2(Vector2(8 + i * 2, -2) * px, Vector2(px, px)), Color(1, 0.85, 0.3))
	var tex := _fist if holding else _tex
	draw_texture_rect(tex, Rect2(Vector2(-1, 0) * px, tex.get_size() * px), false)
	if holding:
		var font: Font = ThemeBuilder.title_font
		var txt := "%d/%d" % [n, Game.hand_capacity()]
		draw_set_transform(Vector2(9, 9) * px, 0, Vector2(inv, inv))
		draw_string_outline(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 4, Color.BLACK)
		draw_string(font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, ThemeBuilder.TEXT if room() > 0 else ThemeBuilder.BAD)
		draw_set_transform(Vector2.ZERO)
