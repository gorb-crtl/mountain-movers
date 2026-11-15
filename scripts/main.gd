extends Node2D
## Wires everything together: input, the hand, camera, trucks, interns,
## military, items, the mountain-cleared / prestige flow and autosave.

const AUTOSAVE_SECONDS := 15.0
const HOLD_DIG_RATE := 4.0
const THROW_DRAG_PX := 24.0
const MAX_FLOATERS := 40

var world: Node2D
var camera: CameraRig
var mountain: Mountain
var rocks: RockManager
var depot: TruckDepot
var interns: InternCrew
var military: Military
var abilities: Abilities
var effects: Effects
var hand: Hand
var hud: Hud
var boss: Boss

var _holding := false
var _press_screen := Vector2.ZERO
var _drag_px := 0.0
var _hold_accum := 0.0
var _mouse_vel := Vector2.ZERO
var _last_mouse := Vector2.ZERO
var _shake := 0.0
var _autosave := AUTOSAVE_SECONDS
var _floaters := 0


func _ready() -> void:
	var sky_layer := CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var sky := Control.new()
	sky.set_script(preload("res://scripts/sky.gd"))
	sky_layer.add_child(sky)

	world = Node2D.new()
	add_child(world)
	var ground := Node2D.new()
	ground.set_script(preload("res://scripts/background.gd"))
	world.add_child(ground)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape2D.new()
	floor_shape.shape = WorldBoundaryShape2D.new()
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	mountain = Mountain.new()
	world.add_child(mountain)
	mountain.item_found.connect(_on_item_found)
	mountain.cleared.connect(_on_cleared)

	depot = TruckDepot.new()
	world.add_child(depot)
	depot.sold.connect(_on_truck_sold)

	effects = Effects.new()
	rocks = RockManager.new()
	world.add_child(rocks)

	military = Military.new()
	military.mountain = mountain
	military.rocks = rocks
	military.effects = effects
	military.shake_cb = add_shake
	world.add_child(military)

	interns = InternCrew.new()
	interns.mountain = mountain
	interns.rocks = rocks
	interns.depot = depot
	interns.effects = effects
	world.add_child(interns)

	abilities = Abilities.new()
	abilities.mountain = mountain
	abilities.rocks = rocks
	abilities.depot = depot
	abilities.effects = effects
	abilities.shake.connect(add_shake)
	world.add_child(abilities)

	world.add_child(effects)
	hand = Hand.new()
	world.add_child(hand)

	camera = CameraRig.new()
	world.add_child(camera)
	camera.make_current()

	hud = Hud.new()
	hud.mountain = mountain
	hud.depot = depot
	hud.hand = hand
	add_child(hud)
	boss = hud.boss
	hud.regrow_confirmed.connect(_on_regrow)
	hud.wipe_confirmed.connect(_on_wipe)
	hud.send_truck.connect(func(): depot.send_now())
	hud.item_selected.connect(_arm_item)
	abilities.flash_screen.connect(hud.flash)

	var blob := Game.load_game()
	if blob.is_empty() or not mountain.deserialize(blob.get("mountain", {})):
		_new_mountain()
	else:
		_layout_world()
		rocks.deserialize(blob.get("rocks", []))
		depot.deserialize(blob.get("trucks", []))
	camera.frame(_world_focus_rect(), Hud.PLAY_AREA)

	if Game.won:
		_show_victory()
	elif not Game.intro_done:
		hud.show_popup("MOUNTAIN MOVERS", "Your first day at Mountain Movers Inc.\n\nThe boss points out the window.\n\"See that mountain over there? I want it gone!\"\n\nClick the mountain to break off rock. Drag it to the dump truck and let go. When the truck is full it drives off and sells the load. Spend the money on interns, trucks and... the army.",
			[["Yes, boss.", func():
				Game.intro_done = true
				Game.say(Quips.pick(Quips.INTRO))]])
	else:
		Game.say("Oh, you're back. The mountain isn't going to move itself.")


func _new_mountain() -> void:
	var size := Game.mountain_size()
	mountain.generate(size.x, size.y, Game.mountain_seed, Game.hp_mult(), Game.luck(), Game.level)
	_layout_world()
	rocks.clear_all()
	depot.reset()
	interns.reset()
	military.reset()
	hand.clear()


## Mountain's bottom-left corner sits at world (0, 0); trucks park on the left,
## the military camps on the right.
func _layout_world() -> void:
	mountain.set_cell_scale(Game.CELL)
	mountain.position = Vector2(0, -mountain.h * Game.CELL)
	var mw := mountain.w * Game.CELL
	depot.spot_x = -240.0
	military.camp_x = mw + 10.0
	camera.bounds = Rect2(-900, -mountain.h * Game.CELL - 300, mw + 1800, mountain.h * Game.CELL + 360)


func _world_focus_rect() -> Rect2:
	var mw := mountain.w * Game.CELL
	var mh := mountain.h * Game.CELL
	return Rect2(-260, -mh - 40, mw + 520, mh + 80)


# ----------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_popup_open():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if hud.mouse_over_ui(mb.position) and mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_left_press(mb.position)
			else:
				_on_left_release()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			if camera.drag_moved < 6.0:
				if hand.armed_item != "":
					_arm_item("")
				else:
					_drop_hand(Vector2.ZERO)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				_arm_item(UpgradeDefs.ITEMS[key - KEY_1]["id"])
			KEY_ESCAPE:
				_arm_item("")
			KEY_F:
				camera.frame(_world_focus_rect(), Hud.PLAY_AREA)
			KEY_F9, KEY_F10, KEY_F11:
				if OS.is_debug_build():
					_debug_key(key)


func _debug_key(key: Key) -> void:
	match key:
		KEY_F9:
			Game.add_money(5000.0 * Game.value_mult())
		KEY_F10:
			Game.approval += 25
			Game.changed.emit()
		KEY_F11:
			mountain.force_clear()


func _arm_item(id: String) -> void:
	if id != "" and Game.item_count(id) <= 0:
		hud.toast("None left! Buy more in the Items tab.", Color(1, 0.6, 0.5))
		Sfx.play("deny")
		id = ""
	if id == hand.armed_item:
		id = ""
	hand.armed_item = id
	hud.set_armed(id)


func _on_left_press(screen_pos: Vector2) -> void:
	var p := get_global_mouse_position()
	if hand.armed_item != "":
		var id := hand.armed_item
		if Game.use_item(id):
			abilities.use(id, p)
		_arm_item("")
		return
	Game.stats["clicks"] = int(Game.stats["clicks"]) + 1
	_holding = true
	_press_screen = screen_pos
	_drag_px = 0.0
	_hold_accum = 0.0
	if depot.is_over_bed(p) and not hand.is_empty():
		_deposit_hand()
		return
	if _grab_rock_at(p):
		return
	_dig(p)


func _on_left_release() -> void:
	if not _holding:
		return
	_holding = false
	if hand.is_empty():
		return
	var p := get_global_mouse_position()
	if depot.is_over_bed(p):
		_deposit_hand()
	elif _drag_px > THROW_DRAG_PX and not _over_mountain(p):
		_drop_hand(_mouse_vel.limit_length(1100.0))


func _over_mountain(p: Vector2) -> bool:
	return mountain.is_solid(mountain.world_to_cell(p))


func _grab_rock_at(p: Vector2) -> bool:
	var r := rocks.rock_at(p, 4.0 / camera.zoom.x)
	if r == null:
		return false
	if r.find_name != "":
		hand.finds.append({"name": r.find_name, "value": r.value})
		rocks.remove(r)
		Sfx.play("grab", -2.0)
		return true
	if hand.room() <= 0:
		_hand_full_hint()
		return true
	var got := r.take(hand.room())
	hand.add(int(got["n"]), float(got["value"]), got["colors"])
	if r.pixels <= 0:
		rocks.remove(r)
	Sfx.play("grab", -4.0)
	return true


func _dig(p: Vector2) -> void:
	var c := mountain.world_to_cell(p)
	if not mountain.is_solid(c):
		return
	var hv := mountain.damage_circle(c, Game.click_radius(), Game.click_damage())
	Sfx.play("dig", -4.0, 0.12, 50)
	effects.debris(p, Color(0.6, 0.55, 0.5, 0.8), 2.5, 0.4)
	var n: int = hv["n"]
	if n == 0:
		return
	Sfx.play("crumble", -10.0, 0.1, 80)
	var cols: PackedColorArray = hv["colors"]
	for i in mini(n, 6):
		effects.debris(p, cols[i], Game.CELL * 0.6, 0.6)
	var take := mini(hand.room(), n)
	var value: float = hv["value"]
	if take > 0:
		hand.add(take, value * take / float(n), cols.slice(0, take))
	if take < n:
		rocks.spawn(n - take, value * float(n - take) / float(n), cols.slice(take), p, Vector2(randf_range(-60, 60), -80))
		if take == 0:
			_hand_full_hint()


func _hand_full_hint() -> void:
	if _floaters < 3:
		_float_text(get_global_mouse_position() + Vector2(10, -20), "Hand full! Take it to the truck.", Color(1, 0.7, 0.5), 13)


func _deposit_hand() -> void:
	var any := false
	for f in hand.finds:
		if depot.deposit_find(float(f["value"])):
			any = true
	if any:
		hand.finds = []
	if hand.n > 0:
		var k := depot.deposit(hand.n, hand.value)
		if k > 0:
			any = true
			var frac := float(k) / float(hand.n)
			hand.value *= (1.0 - frac)
			hand.n -= k
			hand.colors = hand.colors.slice(int(hand.colors.size() * frac))
			if hand.n <= 0:
				hand.clear()
	if not any:
		Sfx.play("deny")
		_float_text(get_global_mouse_position() + Vector2(10, -20), "Truck's full or away. Hang on!", Color(1, 0.7, 0.5), 13)


## Drops (or throws) whatever is in the hand as physics rocks.
func _drop_hand(vel: Vector2) -> void:
	var p := get_global_mouse_position()
	if hand.n > 0:
		rocks.spawn(hand.n, hand.value, hand.colors, p, vel)
	for f in hand.finds:
		rocks.spawn(1, float(f["value"]), PackedColorArray([Color(1, 0.85, 0.3)]), p, vel, f["name"])
	if not hand.is_empty():
		Sfx.play("grab", -6.0)
	hand.clear()


# --------------------------------------------------------------- frame

func _process(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var world_mouse := get_global_mouse_position()
	var inst := (world_mouse - _last_mouse) / maxf(delta, 0.001)
	_mouse_vel = _mouse_vel.lerp(inst, 0.35)
	_last_mouse = world_mouse
	var over_ui := hud.mouse_over_ui(mouse)
	hand.visible = not over_ui
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if over_ui else Input.MOUSE_MODE_HIDDEN

	if _holding:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_on_left_release()
		else:
			_drag_px += (mouse - _press_screen).length()
			_press_screen = mouse
			# Keep digging / scooping while the button is held.
			_hold_accum += HOLD_DIG_RATE * delta
			if _hold_accum >= 1.0:
				_hold_accum -= 1.0
				if not _grab_rock_at(world_mouse) and _over_mountain(world_mouse):
					_dig(world_mouse)

	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		var amt := minf(_shake, 1.0) * 14.0 / camera.zoom.x
		camera.offset = Vector2(randf_range(-amt, amt), randf_range(-amt, amt))
	else:
		camera.offset = Vector2.ZERO

	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = AUTOSAVE_SECONDS
		_save()


func _physics_process(_delta: float) -> void:
	depot.absorb_rocks(rocks)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _save() -> void:
	# Whatever is in your hand gets dropped where you stand.
	var world_blob := {"mountain": mountain.serialize(), "rocks": rocks.serialize(), "trucks": depot.serialize()}
	if hand.n > 0:
		(world_blob["rocks"] as Array).append([depot.unload_x(), -20.0, hand.n, hand.value, "", ["777777"]])
	Game.save_game(world_blob)


# ------------------------------------------------------------- events

func _on_item_found(item_name: String, base_value: float, _mat: int, pos: Vector2) -> void:
	var value := Game.find_value(base_value)
	Game.stats["finds"] = int(Game.stats["finds"]) + 1
	rocks.spawn(1, value, PackedColorArray([Color(1, 0.85, 0.3)]), pos, Vector2(randf_range(-30, 30), -160), item_name)
	_float_text(pos + Vector2(-30, -30), "Found: %s! (worth $%s)" % [item_name, Game.fmt(value * Game.sell_mult())], Color(1, 0.75, 1), 16)
	Sfx.play("find")
	if randf() < 0.5:
		Game.say(Quips.pick(Quips.ITEM), 3.5)


func _on_truck_sold(amount: float) -> void:
	Sfx.play("cash", -2.0, 0.02, 0)
	hud.toast("Truck sold its load: +$%s" % Game.fmt(amount))
	if randf() < 0.15:
		Game.say(Quips.pick(Quips.TRUCK), 3.0)


func _on_cleared() -> void:
	_holding = false
	var award := Game.clear_award()
	var last := Game.level >= Game.MOUNTAIN_COUNT - 1
	Sfx.play("clear", 0.0, 0.0, 0)
	_save()
	hud.show_popup("MOUNTAIN MOVED!",
		"%s is gone.\n\nBoss: \"%s\"\n\n+%d Boss Approval%s" % [
			Game.mountain_name(), Quips.pick(Quips.CLEAR), award,
			"" if last else "\n\n...but a bigger one is already growing back. Your crew, trucks and army are reassigned. Spend your approval in the Boss tab."],
		[["Collect & continue", _advance]])


func _advance() -> void:
	Game.complete_mountain()
	if Game.won:
		_show_victory()
		return
	_new_mountain()
	camera.frame(_world_focus_rect(), Hud.PLAY_AREA)
	_save()
	Game.say(Quips.pick(Quips.NEW_MOUNTAIN))


func _on_regrow() -> void:
	Game.bail_out(mountain.moved_fraction())
	_new_mountain()
	camera.frame(_world_focus_rect(), Hud.PLAY_AREA)
	_save()
	Game.say(Quips.pick(Quips.BAILOUT))


func _on_wipe() -> void:
	Game.wipe()
	get_tree().reload_current_scene()


func _show_victory() -> void:
	Game.say(Quips.pick(Quips.VICTORY), 999.0)
	hud.show_popup("YOU WIN!",
		"All seven mountains are gone. The horizon is flat. For the first time in recorded history, the boss is happy.\n\nPixels moved: %s\nTruckloads: %d\nFinds: %d" % [
			Game.fmt(float(Game.stats["pixels"])), int(Game.stats.get("trucks", 0)), int(Game.stats["finds"])],
		[["Start over", _on_wipe], ["Admire the view", func(): pass]])


func _float_text(pos: Vector2, text: String, color: Color, size := 14) -> void:
	if _floaters >= MAX_FLOATERS:
		return
	_floaters += 1
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos
	l.scale = Vector2.ONE / camera.zoom.x
	l.z_index = 60
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 50.0 / camera.zoom.x, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.5)
	tw.chain().tween_callback(func():
		_floaters -= 1
		l.queue_free())
