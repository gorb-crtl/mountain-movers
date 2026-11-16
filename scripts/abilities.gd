class_name Abilities
extends Node2D
## One-use items: grenade, large bird, earthquake, airstrike, nuke.

signal shake(amount: float)
signal flash_screen(strength: float)

var mountain: Mountain
var rocks: RockManager
var depot: TruckDepot
var effects: Effects

var _textures := {}


func _ready() -> void:
	for id in ["grenade", "bird", "nuke", "airstrike"]:
		_textures[id] = load("res://assets/sprites/%s.png" % id)


## Uses an item at a world point. Returns false if it couldn't be used.
func use(id: String, at: Vector2) -> bool:
	match id:
		"grenade":
			_grenade(at)
		"bird":
			_bird(at)
		"quake":
			_quake()
		"airstrike":
			_airstrike(at)
		"nuke":
			_nuke(at)
		_:
			return false
	return true


func _sprite(id: String, at: Vector2, _scale_hint := 0.0) -> Sprite2D:
	var scale_f := Game.CELL
	var s := Sprite2D.new()
	s.texture = _textures[id]
	s.scale = Vector2(scale_f, scale_f)
	s.position = at
	add_child(s)
	return s


func _boom(at: Vector2, radius: float, dmg: float, sound: String, shake_amt: float, power: float) -> void:
	var hv := mountain.damage_circle(mountain.world_to_cell(at), radius, dmg, true)
	effects.explosion(at, radius * Game.CELL)
	Sfx.play(sound, 0.0, 0.05, 0)
	shake.emit(shake_amt)
	rocks.spawn_harvest(hv, at, power, 3.0)


func _grenade(at: Vector2) -> void:
	var g := _sprite("grenade", at + Vector2(0, -160), 2.0)
	var tw := create_tween()
	tw.tween_property(g, "position", at, 0.45).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(g, "rotation", 8.0, 0.45)
	tw.tween_interval(0.25)
	tw.tween_callback(func():
		g.queue_free()
		_boom(at, 6.0, Game.click_damage() * 40.0, "grenade", 0.2, 260.0))


func _bird(at: Vector2) -> void:
	Sfx.play("bird", -2.0, 0.05, 0)
	var b := _sprite("bird", at + Vector2(-700, -500), 3.0)
	var radius := 5.0 + Game.level * 0.8
	var carried := {"n": 0, "value": 0.0, "colors": PackedColorArray()}
	var tw := create_tween()
	tw.tween_property(b, "position", at + Vector2(0, -10), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		var hv := mountain.scoop_circle(mountain.world_to_cell(at), radius)
		carried["n"] = hv["n"]
		carried["value"] = hv["value"]
		carried["colors"] = hv["colors"]
		Sfx.play("crumble", 0.0)
		for i in 12:
			effects.debris(at, Color(0.5, 0.45, 0.4), 4.0)
		var load_node := RockBlob.new()
		load_node.colors = (hv["colors"] as PackedColorArray).slice(0, Rock.MAX_DRAW)
		load_node.count = int(hv["n"])
		load_node.position = Vector2(0, 30) / Game.CELL
		load_node.scale = Vector2(1, 1) / Game.CELL
		b.add_child(load_node))
	var drop := Vector2(depot.unload_x(), -140)
	tw.tween_property(b, "position", drop, 1.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		var n: int = carried["n"]
		if n > 0:
			var k := depot.deposit(n, float(carried["value"]))
			if k < n:
				var frac := float(k) / float(n)
				rocks.spawn(n - k, float(carried["value"]) * (1.0 - frac), (carried["colors"] as PackedColorArray).slice(int(n * frac)), drop + Vector2(0, 20))
		for c in b.get_children():
			c.queue_free()
		if randf() < 0.5:
			Game.say(Quips.pick(Quips.BIRD), 3.0))
	tw.tween_property(b, "position", drop + Vector2(-900, -500), 1.2)
	tw.tween_callback(b.queue_free)


func _quake() -> void:
	Sfx.play("rumble", 2.0, 0.0, 0)
	for pulse in 3:
		var tw := create_tween()
		tw.tween_interval(pulse * 0.6)
		tw.tween_callback(func():
			shake.emit(0.5)
			var hv := mountain.damage_surface(2, Game.click_damage() * 15.0)
			rocks.spawn_harvest(hv, Vector2(mountain.global_position.x + mountain.w * Game.CELL * 0.5, 50), 80.0, 4.0))


func _airstrike(at: Vector2) -> void:
	Sfx.play("engine", 0.0, 0.0, 0)
	var left := mountain.global_position.x
	var width := mountain.w * Game.CELL
	var plane := _sprite("airstrike", Vector2(left - 300, -mountain.h * Game.CELL - 160), 3.0)
	plane.flip_h = true
	var tw := create_tween()
	tw.tween_property(plane, "position:x", left + width + 300, 2.4)
	tw.tween_callback(plane.queue_free)
	for i in 8:
		var x := left + width * (float(i) + 0.5) / 8.0
		var t := create_tween()
		t.tween_interval(0.3 + 2.0 * (float(i) + 0.5) / 8.0)
		t.tween_callback(func():
			var c := mountain.surface_cell_near(x, 40)
			if c.x >= 0:
				_boom(mountain.cell_to_world(c), 7.0, Game.click_damage() * 60.0, "explosion", 0.25, 280.0))


func _nuke(at: Vector2) -> void:
	var n := _sprite("nuke", at + Vector2(0, -900), 3.0)
	var tw := create_tween()
	tw.tween_property(n, "position", at, 1.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func():
		n.queue_free()
		flash_screen.emit(1.0)
		var r := 26.0 + Game.level * 3.0
		_boom(at, r, Game.click_damage() * 2000.0, "nuke", 1.2, 420.0)
		for i in 40:
			effects.smoke(at + Vector2(randf_range(-30, 30), -randf_range(0, 220)), randf_range(20, 40), 3.0, Color(0.55, 0.45, 0.4, 0.8), 40.0)
		for i in 25:
			effects.smoke(at + Vector2(randf_range(-110, 110), -220 + randf_range(-40, 40)), randf_range(30, 50), 3.2, Color(0.75, 0.5, 0.35, 0.8), 30.0)
		Game.say(Quips.pick(Quips.NUKE), 4.0))


## Little drawable pile of rock (for things being carried).
class RockBlob extends Node2D:
	var colors := PackedColorArray()
	var count := 9

	func _draw() -> void:
		Rock.draw_blob(self, Vector2.ZERO, count, colors, Game.CELL)
