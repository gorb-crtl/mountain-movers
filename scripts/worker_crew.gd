class_name WorkerCrew
extends Node2D
## The interns. They dig the surface of the mountain on their own (the idle part).
## Only a handful are drawn; the rest are "on break" but still counted.

const MAX_VISIBLE := 24
const MAX_HITS_PER_FRAME := 40

var mountain: Mountain
var _accum := 0.0
var _sprites: Array[Sprite2D] = []
var _next := 0
var _texture: Texture2D = preload("res://assets/sprites/worker.png")


func _process(delta: float) -> void:
	if mountain == null:
		return
	_sync_sprites()
	var count := Game.worker_count()
	if count == 0:
		return
	_accum += count * Game.worker_rate() * delta
	var hits := int(_accum)
	if hits <= 0:
		return
	_accum -= hits
	# With lots of interns, batch their hits so the frame rate survives.
	var batches := mini(hits, MAX_HITS_PER_FRAME)
	var dmg := Game.worker_damage() * float(hits) / float(batches)
	for _i in batches:
		var c := mountain.random_surface_cell()
		if c.x < 0:
			return
		mountain.damage_circle(c, 0.5, dmg)
		_show_hit(c)


func _sync_sprites() -> void:
	var want := mini(Game.worker_count(), MAX_VISIBLE)
	while _sprites.size() < want:
		var s := Sprite2D.new()
		s.texture = _texture
		s.scale = Vector2(2, 2)
		s.offset = Vector2(0, -_texture.get_height() * 0.5)
		var c := mountain.random_surface_cell()
		s.position = mountain.cell_to_world(c) if c.x >= 0 else Vector2(500, 660)
		add_child(s)
		_sprites.append(s)
	while _sprites.size() > want:
		_sprites.pop_back().queue_free()


func _show_hit(c: Vector2i) -> void:
	if _sprites.is_empty():
		return
	var s := _sprites[_next % _sprites.size()]
	_next += 1
	var target := mountain.cell_to_world(c) - Vector2(0, mountain.cell_scale * 0.5)
	s.flip_h = target.x < s.position.x
	var tw := s.create_tween()
	tw.tween_property(s, "position", target, 0.25)
	tw.tween_property(s, "rotation", 0.3 if not s.flip_h else -0.3, 0.06)
	tw.tween_property(s, "rotation", 0.0, 0.08)


func reset() -> void:
	for s in _sprites:
		s.queue_free()
	_sprites.clear()
	_accum = 0.0
