class_name CrtOverlay
extends CanvasLayer
## Full-screen CRT TV overlay (scanlines, curved glass, colour fringing,
## vignette, flicker). Sits above the game and the HUD. Toggle with F2 or the
## checkbox in the Boss tab; the choice is saved as Game.crt.

var _rect: ColorRect


func _ready() -> void:
	layer = 50
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/crt.gdshader")
	_rect.material = mat
	add_child(_rect)
	refresh()
	Game.changed.connect(refresh)


func refresh() -> void:
	visible = Game.crt
