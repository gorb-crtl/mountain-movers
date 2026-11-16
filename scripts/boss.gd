class_name Boss
extends Node2D
## The boss, standing in the bottom-left corner of the screen and having opinions.
## Lives in the HUD layer, so it ignores the camera. What he says is typed out
## next to him, letter by letter, with little mumble blips.

const SCALE := 4.0
const CHARS_PER_SEC := 45.0

var _sprite: Sprite2D
var _label: Label
var _full := ""
var _shown := 0.0
var _hide_at := 0.0
var _idle_at := 0.0
var _time := 0.0
var _last_blip := 0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/boss.png")
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.centered = false
	_sprite.position = Vector2(0, -_sprite.texture.get_height() * SCALE)
	add_child(_sprite)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(360, 0)
	_label.size = Vector2(360, 0)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_label.add_theme_font_override("font", preload("res://assets/fonts/PixelifySans.ttf"))
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(_sprite.texture.get_width() * SCALE + 14, -_sprite.texture.get_height() * SCALE)
	add_child(_label)
	_idle_at = randf_range(20, 35)
	Game.boss_says.connect(say)


func say(text: String, duration := 5.0) -> void:
	_full = "“" + text + "”"
	_shown = 0.0
	_last_blip = 0
	_label.text = ""
	_label.visible_characters = 0
	_label.text = _full
	_label.modulate.a = 1.0
	_hide_at = _time + duration + _full.length() / CHARS_PER_SEC
	var tw := create_tween()
	_sprite.scale = Vector2(SCALE * 1.08, SCALE * 0.92)
	tw.tween_property(_sprite, "scale", Vector2(SCALE, SCALE), 0.2)


func _process(delta: float) -> void:
	_time += delta
	if _full != "" and _shown < _full.length():
		_shown += delta * CHARS_PER_SEC
		var n := mini(int(_shown), _full.length())
		_label.visible_characters = n
		# A mumble blip every few letters.
		if n - _last_blip >= 3 and _full[n - 1] != " ":
			_last_blip = n
			Sfx.play("blip", -12.0, 0.3, 35)
	# Keep the text's bottom aligned with the boss's head.
	_label.position.y = -_sprite.texture.get_height() * SCALE - 6.0 - _label.size.y + 40.0
	if _full != "" and _time > _hide_at:
		_label.modulate.a = maxf(0.0, _label.modulate.a - delta * 1.5)
		if _label.modulate.a <= 0.0:
			_full = ""
			_label.text = ""
	if _time > _idle_at:
		_idle_at = _time + randf_range(25, 45)
		say(Quips.pick(Quips.IDLE))
	# Tiny impatient bob.
	_sprite.position.y = -_sprite.texture.get_height() * SCALE + (2.0 if fmod(_time, 1.0) < 0.5 else 0.0)
