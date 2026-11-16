class_name CameraRig
extends Camera2D
## Pan with WASD / arrow keys / right or middle mouse drag (or screen edges),
## zoom with the mouse wheel. Bigger mountains need you to look around.

const PAN_SPEED := 700.0
const ZOOM_MIN := 0.25
const ZOOM_MAX := 3.0

var bounds := Rect2(-600, -1200, 2400, 1400)
var _drag_from := Vector2.ZERO
var _dragging := false
var drag_moved := 0.0


func _ready() -> void:
	position_smoothing_enabled = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(1.12, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / 1.12, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = mb.pressed
			_drag_from = mb.position
			if mb.pressed:
				drag_moved = 0.0
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		position -= mm.relative / zoom.x
		drag_moved += mm.relative.length()
		_clamp()
	elif event is InputEventMagnifyGesture:
		_zoom_at((event as InputEventMagnifyGesture).factor, get_viewport().get_mouse_position())
	elif event is InputEventPanGesture:
		position += (event as InputEventPanGesture).delta * 20.0 / zoom.x
		_clamp()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir != Vector2.ZERO:
		position += dir.normalized() * PAN_SPEED * delta / zoom.x
		_clamp()


func _zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen_point
	var z := clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	force_update_scroll()
	var after := get_canvas_transform().affine_inverse() * screen_point
	position += before - after
	_clamp()


## Frames a world rect in the given screen area (leaving room for the UI).
func frame(rect: Rect2, screen_area: Rect2) -> void:
	var z := clampf(minf(screen_area.size.x / rect.size.x, screen_area.size.y / rect.size.y), ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(z, z)
	var vp := get_viewport_rect().size
	# Camera centre sits so that rect's centre lands on the screen area's centre.
	var offset_px := screen_area.get_center() - vp * 0.5
	position = rect.get_center() - offset_px / z
	_clamp()


func _clamp() -> void:
	position.x = clampf(position.x, bounds.position.x, bounds.end.x)
	position.y = clampf(position.y, bounds.position.y, bounds.end.y)
