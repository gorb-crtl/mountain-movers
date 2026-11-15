class_name Boss
extends Node2D
## The boss, standing in the bottom-left corner of the screen, pointing at the
## mountain and having opinions. Lives in the HUD layer, so it ignores the camera.

const SCALE := 4.0

var _sprite: Sprite2D
var _bubble: PanelContainer
var _label: Label
var _hide_at := 0.0
var _idle_at := 0.0
var _time := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/boss.png")
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.centered = false
	_sprite.position = Vector2(0, -_sprite.texture.get_height() * SCALE)
	add_child(_sprite)

	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1)
	sb.border_color = Color(0.1, 0.1, 0.1)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(8)
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(190, 0)
	_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	_label.add_theme_font_size_override("font_size", 14)
	_bubble.add_child(_label)
	add_child(_bubble)
	_bubble.visible = false
	_idle_at = randf_range(20, 35)
	Game.boss_says.connect(say)


func say(text: String, duration := 5.0) -> void:
	_label.text = text
	_bubble.visible = true
	if duration < 900.0:
		Sfx.play("boss", -8.0, 0.05, 0)
	_bubble.reset_size()
	_bubble.position = Vector2(4, -_sprite.texture.get_height() * SCALE - 16 - _bubble.size.y)
	_hide_at = _time + duration
	var tw := create_tween()
	_sprite.scale = Vector2(SCALE * 1.08, SCALE * 0.92)
	tw.tween_property(_sprite, "scale", Vector2(SCALE, SCALE), 0.2)


func _process(delta: float) -> void:
	_time += delta
	if _bubble.visible and _time > _hide_at:
		_bubble.visible = false
	if _time > _idle_at:
		_idle_at = _time + randf_range(25, 45)
		say(Quips.pick(Quips.IDLE))
	# Tiny impatient bob.
	_sprite.position.y = -_sprite.texture.get_height() * SCALE + (2.0 if fmod(_time, 1.0) < 0.5 else 0.0)
