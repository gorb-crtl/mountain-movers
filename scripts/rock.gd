class_name Rock
extends RigidBody2D
## A loose chunk of mountain. Pick it up, throw it, or drop it in a truck.
## Fossils and artefacts are special rocks with a find_name.

const MAX_DRAW := 49
const MAX_RADIUS := 26.0

var pixels := 0
var value := 0.0
var colors := PackedColorArray()
var find_name := ""
var radius := 3.0
var claimed_by: Variant = null   # an intern heading for it
var _shape: CircleShape2D
var _landed_at := -10.0

## Shared effects node, for landing dust (set by main).
static var effects: Effects


func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 2
	gravity_scale = 1.0
	can_sleep = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.9
	physics_material_override.bounce = 0.15
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)
	var cs := CollisionShape2D.new()
	_shape = CircleShape2D.new()
	cs.shape = _shape
	add_child(cs)


func _on_body_entered(_body: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var speed := linear_velocity.length()
	if speed < 140.0 or now - _landed_at < 0.3:
		return
	_landed_at = now
	Sfx.play("thud", clampf(-26.0 + speed * 0.012 + pixels * 0.2, -26.0, -8.0), 0.2, 25)
	if effects:
		effects.dust(position + Vector2(0, radius), 2 + mini(pixels / 4, 6))


func setup(n: int, v: float, cols: PackedColorArray, p_find_name := "") -> void:
	pixels = n
	value = v
	colors = cols.slice(0, MAX_DRAW)
	find_name = p_find_name
	_refresh()


func absorb(n: int, v: float, cols: PackedColorArray) -> void:
	pixels += n
	value += v
	for c in cols:
		if colors.size() >= MAX_DRAW:
			break
		colors.append(c)
	_refresh()


## Takes up to n pixels off this rock. Returns {"n", "value", "colors"}.
func take(n: int) -> Dictionary:
	var k := mini(n, pixels)
	var frac := float(k) / float(maxi(pixels, 1))
	var v := value * frac
	var nc := int(ceil(colors.size() * frac))
	var cols := colors.slice(0, nc)
	pixels -= k
	value -= v
	colors = colors.slice(nc)
	if colors.is_empty() and pixels > 0:
		colors.append(cols[0] if not cols.is_empty() else Color(0.5, 0.5, 0.5))
	_refresh()
	return {"n": k, "value": v, "colors": cols, "find_name": find_name if pixels == 0 else ""}


func _refresh() -> void:
	var cell := Game.CELL
	radius = clampf(cell * 0.55 * sqrt(float(maxi(pixels, 1))), cell * 0.5, MAX_RADIUS)
	if find_name != "":
		radius = maxf(radius, cell * 1.6)
	_shape.radius = radius
	mass = 0.2 + pixels * 0.05
	queue_redraw()


func _draw() -> void:
	draw_blob(self, Vector2.ZERO, radius, colors, find_name != "")


## Shared drawing for rocks, the hand and carried loads.
static func draw_blob(ci: CanvasItem, center: Vector2, r: float, cols: PackedColorArray, is_find := false) -> void:
	if cols.is_empty():
		return
	var k := int(ceil(sqrt(float(cols.size()))))
	var s := (r * 2.0) / float(k)
	var origin := center - Vector2(r, r)
	if is_find:
		ci.draw_circle(center, r + 3.0, Color(1, 0.9, 0.3, 0.55))
	var i := 0
	for y in k:
		for x in k:
			if i >= cols.size():
				break
			# Skip the corners so bigger rocks look rounder.
			if k >= 3 and ((x == 0 or x == k - 1) and (y == 0 or y == k - 1)):
				continue
			ci.draw_rect(Rect2(origin + Vector2(x, y) * s, Vector2(s + 0.5, s + 0.5)), cols[i])
			i += 1
