class_name Boss
extends Node2D
## The boss. Lives in the HUD layer (ignores the camera). He stands in the
## bottom-left corner, wanders off now and then, comes back to check on you,
## and while he's away he sometimes just pokes his head in from the side of the
## screen to make a comment. His lines are typed out as plain text.
## boss.png is 3 frames side by side (idle, walk 1, walk 2), 20x24 each.

const SCALE := 5.0
const FRAME := Vector2(20, 24)
const HEAD_ROWS := 10
const CHARS_PER_SEC := 45.0
const WALK_SPEED := 70.0
const HOME_X := 14.0
const GROUND_Y := 708.0

const LEAVING: Array = [
	"I'll be in my office. Watching. Always watching.",
	"Back in five. Don't stop digging.",
	"Got a meeting with the board. Make me look good.",
]
const RETURNING: Array = [
	"Just checking in. ...Is THAT all you've done?",
	"I'm back. The mountain is still here. Why is that?",
	"Quick check-in. Keep it up. Or else.",
]

var right_edge := 960.0     # where the play area ends (set by the HUD)

var _sprite: Sprite2D
var _label: Label
var _full := ""
var _shown := 0.0
var _hide_at := 0.0
var _idle_at := 0.0
var _time := 0.0
var _last_blip := 0
var _state := "here"        # here, leaving, away, arriving, peek
var _state_t := 0.0
var _x := HOME_X
var _peek_side := -1        # -1 left, 1 right
var _peek_amt := 0.0        # 0 hidden .. 1 fully peeking


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = preload("res://assets/sprites/boss.png")
	_sprite.hframes = 3
	_sprite.scale = Vector2(SCALE, SCALE)
	_sprite.centered = false
	add_child(_sprite)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.size = Vector2(360, 0)
	_label.custom_minimum_size = Vector2(360, 0)
	_label.add_theme_font_override("font", preload("res://assets/fonts/PixelifySans.ttf"))
	_label.add_theme_font_size_override("font_size", 19)
	_label.add_theme_color_override("font_color", Color(0.96, 0.9, 0.78))
	_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03))
	_label.add_theme_constant_override("outline_size", 6)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_idle_at = randf_range(20, 35)
	_state_t = randf_range(45, 80)
	Game.boss_says.connect(say)


func is_away() -> bool:
	return _state in ["away", "peek"]


func say(text: String, duration := 5.0) -> void:
	# While he's out of the office, he pokes his head in to say it.
	if _state == "away" or _state == "peek":
		_state = "peek"
		_peek_side = -1 if randf() < 0.6 else 1
		_state_t = duration + text.length() / CHARS_PER_SEC + 0.6
	_full = "“" + text + "”"
	_shown = 0.0
	_last_blip = 0
	_label.text = _full
	_label.visible_characters = 0
	_label.modulate.a = 1.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if (_state == "peek" and _peek_side == 1) else HORIZONTAL_ALIGNMENT_LEFT
	_hide_at = _time + duration + _full.length() / CHARS_PER_SEC
	if _state == "here":
		_sprite.scale = Vector2(SCALE * 1.08, SCALE * 0.92)
		create_tween().tween_property(_sprite, "scale", Vector2(SCALE, SCALE), 0.2)


func _process(delta: float) -> void:
	_time += delta
	_state_t -= delta
	_update_state(delta)
	_update_text(delta)
	if _time > _idle_at:
		_idle_at = _time + randf_range(25, 45)
		if _state == "here" or (_state == "away" and randf() < 0.5):
			say(Quips.pick(Quips.IDLE))


func _update_state(delta: float) -> void:
	var full_h := FRAME.y * SCALE
	_sprite.region_enabled = false
	_sprite.hframes = 3
	_sprite.rotation = 0.0
	match _state:
		"here":
			_sprite.frame = 0
			_sprite.flip_h = false
			_x = HOME_X
			_sprite.position = Vector2(_x, GROUND_Y - full_h + (SCALE if fmod(_time, 1.0) < 0.5 else 0.0))
			if _state_t <= 0.0 and _full == "":
				_state = "leaving"
				say(Quips.pick(LEAVING), 3.0)
		"leaving":
			_walk(-1, delta)
			if _x < -FRAME.x * SCALE - 10:
				_state = "away"
				_state_t = randf_range(30, 60)
		"away":
			_sprite.visible = false
			if _state_t <= 0.0:
				_state = "arriving"
				_x = -FRAME.x * SCALE - 10
		"arriving":
			_sprite.visible = true
			_walk(1, delta)
			if _x >= HOME_X:
				_state = "here"
				_state_t = randf_range(60, 110)
				say(Quips.pick(RETURNING), 4.0)
		"peek":
			_sprite.visible = true
			var target := 1.0 if _state_t > 0.4 else 0.0
			_peek_amt = move_toward(_peek_amt, target, delta * 4.0)
			if _state_t <= 0.0 and _peek_amt <= 0.0:
				_state = "away"
				_state_t = maxf(_state_t, 8.0)
				_sprite.visible = false
			_draw_peek()
	_sprite.visible = _state != "away"
	_place_label()


func _walk(dir: int, delta: float) -> void:
	_sprite.visible = true
	_x += dir * WALK_SPEED * delta
	_sprite.flip_h = dir < 0
	_sprite.frame = 1 + int(_time * 6.0) % 2
	var bob := SCALE if _sprite.frame == 1 else 0.0
	_sprite.position = Vector2(roundf(_x / SCALE) * SCALE, GROUND_Y - FRAME.y * SCALE - bob)


## Only his head pokes in from the edge of the screen, tilted.
func _draw_peek() -> void:
	_sprite.hframes = 1
	_sprite.frame = 0
	_sprite.region_enabled = true
	_sprite.region_rect = Rect2(0, 0, FRAME.x, HEAD_ROWS)
	var head_w := 14.0 * SCALE
	var y := 330.0
	if _peek_side < 0:
		_sprite.flip_h = false
		_sprite.rotation = 0.35
		_sprite.position = Vector2(lerpf(-head_w - 40.0, -4.0 * SCALE, _peek_amt), y)
	else:
		_sprite.flip_h = true
		_sprite.rotation = -0.35
		_sprite.position = Vector2(lerpf(right_edge + 40.0, right_edge - head_w - 2.0 * SCALE, _peek_amt), y + 20.0)


func _place_label() -> void:
	var lw := _label.size.x
	match _state:
		"peek":
			if _peek_side < 0:
				_label.position = Vector2(_sprite.position.x + 18.0 * SCALE, _sprite.position.y + 10)
			else:
				_label.position = Vector2(_sprite.position.x - lw - 10.0, _sprite.position.y + 30)
		_:
			_label.position = Vector2(_sprite.position.x + FRAME.x * SCALE + 12.0, GROUND_Y - FRAME.y * SCALE - _label.size.y + 30.0)
			_label.position.x = maxf(_label.position.x, 8.0)


func _update_text(delta: float) -> void:
	if _full != "" and _shown < _full.length():
		_shown += delta * CHARS_PER_SEC
		var n := mini(int(_shown), _full.length())
		_label.visible_characters = n
		if n - _last_blip >= 3 and _full[n - 1] != " ":
			_last_blip = n
			Sfx.play("blip", -12.0, 0.3, 35)
	if _full != "" and _time > _hide_at:
		_label.modulate.a = maxf(0.0, _label.modulate.a - delta * 1.5)
		if _label.modulate.a <= 0.0:
			_full = ""
			_label.text = ""
