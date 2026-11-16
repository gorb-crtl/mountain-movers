class_name Military
extends Node2D
## Hired guns parked on the far (right) side of the mountain. They shoot the
## mountain on their own; whatever they knock loose falls as rocks to be hauled.

## One art pixel = one mountain pixel.
const SPRITE_SCALE := 5.0

## id -> fire stats. dmg is per shot before Game.gun_mult().
const UNITS := {
	"soldier": {"tex": "res://assets/sprites/soldier.png", "rate": 1.2, "dmg": 3.0, "radius": 0.5, "sound": "rifle", "vol": -14.0, "spacing": 30.0, "muzzle": Vector2(0, -22)},
	"gunner": {"tex": "res://assets/sprites/gunner.png", "rate": 8.0, "dmg": 1.6, "radius": 0.5, "sound": "mg", "vol": -16.0, "spacing": 35.0, "muzzle": Vector2(0, -22)},
	"technical": {"tex": "res://assets/sprites/technical.png", "rate": 3.0, "dmg": 14.0, "radius": 1.3, "sound": "bmg", "vol": -10.0, "spacing": 95.0, "muzzle": Vector2(30, -42)},
	"tank": {"tex": "res://assets/sprites/tank.png", "rate": 0.35, "dmg": 60.0, "radius": -1.0, "sound": "cannon", "vol": -4.0, "spacing": 100.0, "muzzle": Vector2(0, -32)},
}

var mountain: Mountain
var rocks: RockManager
var effects: Effects
var shake_cb: Callable

## World x where the military camp starts (just right of the mountain).
var camp_x := 600.0
var _units: Array = []   # [{"type", "node", "t"}]
var _dozers: Array = []  # [{"node", "state", "t", "home"}]
var _dozer_tex: Texture2D = preload("res://assets/sprites/bulldozer.png")


func _process(delta: float) -> void:
	if mountain == null:
		return
	_sync()
	for u in _units:
		var def: Dictionary = UNITS[u["type"]]
		u["t"] = float(u["t"]) - delta
		if float(u["t"]) <= 0.0:
			u["t"] = (1.0 / float(def["rate"])) * randf_range(0.85, 1.15)
			_fire(u, def)
	for d in _dozers:
		_drive_dozer(d, delta)


func _sync() -> void:
	# Lay the camp out left to right: bulldozers nearest, then troops, then vehicles.
	var want := {}
	for id in UNITS:
		want[id] = Game.run_lvl(id)
	var have := {}
	for u in _units:
		have[u["type"]] = int(have.get(u["type"], 0)) + 1
	var dirty := false
	for id in UNITS:
		if int(have.get(id, 0)) != int(want[id]):
			dirty = true
	if Game.run_lvl("bulldozer") != _dozers.size():
		dirty = true
	if dirty:
		_rebuild()


func _rebuild() -> void:
	for u in _units:
		(u["node"] as Node2D).queue_free()
	for d in _dozers:
		(d["node"] as Node2D).queue_free()
	_units.clear()
	_dozers.clear()
	var x := camp_x + 40.0
	for i in Game.run_lvl("bulldozer"):
		var s := _sprite(_dozer_tex)
		s.position = Vector2(x + i * 85.0, 0)
		_dozers.append({"node": s, "state": "push", "t": 0.0, "home": s.position.x + 60.0})
	x += 40.0 + Game.run_lvl("bulldozer") * 85.0
	for id in ["soldier", "gunner", "technical", "tank"]:
		var def: Dictionary = UNITS[id]
		var tex: Texture2D = load(def["tex"])
		for i in Game.run_lvl(id):
			var s := _sprite(tex)
			s.position = Vector2(x, 0)
			x += float(def["spacing"])
			_units.append({"type": id, "node": s, "t": randf() * 1.0})
		x += 20.0


func _sprite(tex: Texture2D) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	s.offset = Vector2(0, -tex.get_height())
	add_child(s)
	return s


func _fire(u: Dictionary, def: Dictionary) -> void:
	var node: Sprite2D = u["node"]
	var muzzle: Vector2 = node.position + (def["muzzle"] as Vector2)
	# Aim at the near (right) side of the mountain, anywhere up its face.
	var target := mountain.random_surface_cell()
	if target.x < 0:
		return
	if randf() < 0.6:
		target = mountain.surface_cell_near(mountain.global_position.x + mountain.w * Game.CELL * randf_range(0.5, 1.0), 60)
		if target.x < 0:
			return
	var hit := mountain.first_solid_towards(target, muzzle)
	var hit_pos := mountain.cell_to_world(hit)
	var mult := Game.gun_mult()
	if u["type"] == "technical":
		mult *= Game.diesel_mult()
	Sfx.play(def["sound"], float(def["vol"]), 0.1, 40)
	node.offset.x = 1.0
	get_tree().create_timer(0.06).timeout.connect(func(): node.offset.x = 0.0)
	if u["type"] == "tank":
		_shell(muzzle, hit, hit_pos, float(def["dmg"]) * mult)
		return
	effects.tracer(muzzle, hit_pos)
	effects.flash(muzzle, 4.0, Color(1, 0.9, 0.4), 0.05)
	var hv := mountain.damage_circle(hit, float(def["radius"]), float(def["dmg"]) * mult)
	_spill(hv, hit_pos, 60.0)


func _shell(from: Vector2, hit: Vector2i, hit_pos: Vector2, dmg: float) -> void:
	effects.flash(from, 10.0)
	effects.smoke(from, 10.0)
	var shell := Node2D.new()
	shell.position = from
	add_child(shell)
	var tw := create_tween()
	tw.tween_property(shell, "position", hit_pos, 0.25)
	tw.tween_callback(func():
		shell.queue_free()
		var r := Game.shell_radius()
		var hv := mountain.damage_circle(hit, r, dmg, true)
		effects.explosion(hit_pos, r * Game.CELL)
		Sfx.play("explosion", -6.0)
		if shake_cb.is_valid():
			shake_cb.call(0.12)
		_spill(hv, hit_pos, 220.0))


func _spill(hv: Dictionary, at: Vector2, power: float) -> void:
	if int(hv["n"]) == 0:
		return
	rocks.spawn_harvest(hv, at + Vector2(-10, 0), power, 3.0)
	effects.debris(at, (hv["colors"] as PackedColorArray)[0], Game.CELL * 0.7)


func _drive_dozer(d: Dictionary, delta: float) -> void:
	var node: Sprite2D = d["node"]
	var speed := 50.0
	match d["state"]:
		"push":
			# Find the mountain's right foot and shove into it.
			var foot_x := _right_foot_x()
			if foot_x == INF:
				return
			if node.position.x > foot_x + 2.0:
				d["fx"] = float(d.get("fx", node.position.x)) - speed * delta
				node.position.x = roundf(float(d["fx"]) / Game.CELL) * Game.CELL
			else:
				d["t"] = float(d["t"]) - delta
				if float(d["t"]) <= 0.0:
					d["t"] = 0.25
					var c := mountain.world_to_cell(Vector2(node.position.x - 4.0, -1.0))
					var height := int(20.0 / Game.CELL)
					var rect := Rect2i(c.x - 2, c.y - height + 1, 3, height)
					var hv := mountain.damage_rect(rect, 18.0 * Game.gun_mult() * Game.diesel_mult())
					Sfx.play("scrape", -10.0, 0.1, 200)
					if int(hv["n"]) > 0:
						rocks.spawn_harvest(hv, Vector2(node.position.x + 40, -10), 90.0, 3.0)
						if randf() < 0.3:
							d["state"] = "back"
		"back":
			d["fx"] = float(d.get("fx", node.position.x)) + speed * 1.5 * delta
			node.position.x = roundf(float(d["fx"]) / Game.CELL) * Game.CELL
			if node.position.x >= float(d["home"]):
				d["state"] = "push"


func _right_foot_x() -> float:
	# Right-most solid column that still has pixels near the ground.
	for x in range(mountain.w - 1, -1, -1):
		if _has_base(x):
			return mountain.global_position.x + (x + 1) * Game.CELL
	return INF


func _has_base(x: int) -> bool:
	for y in range(mountain.h - 4, mountain.h):
		if mountain.mat[y * mountain.w + x] != Materials.AIR:
			return true
	return false


func reset() -> void:
	for u in _units:
		(u["node"] as Node2D).queue_free()
	for d in _dozers:
		(d["node"] as Node2D).queue_free()
	_units.clear()
	_dozers.clear()
