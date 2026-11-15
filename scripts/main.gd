extends Node2D
## Wires everything together: input, the mountain, interns, dynamite,
## effects, boss lines, mountain-cleared / prestige flow and autosave.

## Where the mountain is allowed to sit (left of the side panel, above ground).
const MOUNTAIN_AREA := Rect2(150, 70, 770, 590)
const GROUND_Y := 670.0
const AUTOSAVE_SECONDS := 15.0
const MAX_FLOATERS := 40

var mountain: Mountain
var workers: WorkerCrew
var debris: Debris
var boss: Boss
var hud: Hud
var world: Node2D

var _holding := false
var _jack_accum := 0.0
var _dyn_cooldown := 0.0
var _dynamites: Array = []   # [{"node": Sprite2D, "fuse": float}]
var _shake := 0.0
var _autosave := AUTOSAVE_SECONDS
var _floaters := 0
var _particle_budget := 0
var _dynamite_tex: Texture2D = preload("res://assets/sprites/dynamite.png")


func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	var bg := Node2D.new()
	bg.set_script(preload("res://scripts/background.gd"))
	world.add_child(bg)

	mountain = Mountain.new()
	world.add_child(mountain)
	mountain.cell_destroyed.connect(_on_cell_destroyed)
	mountain.item_found.connect(_on_item_found)
	mountain.cleared.connect(_on_cleared)

	workers = WorkerCrew.new()
	workers.mountain = mountain
	world.add_child(workers)

	boss = Boss.new()
	boss.position = Vector2(12, GROUND_Y)
	world.add_child(boss)

	debris = Debris.new()
	world.add_child(debris)

	hud = Hud.new()
	hud.mountain = mountain
	add_child(hud)
	hud.regrow_confirmed.connect(_on_regrow)
	hud.wipe_confirmed.connect(_on_wipe)

	var cursor := preload("res://assets/sprites/cursor_hand.png")
	Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(4, 2))

	var blob := Game.load_game()
	if blob.is_empty() or not mountain.deserialize(blob):
		_new_mountain()
	_layout_mountain()

	if Game.won:
		_show_victory()
	elif not Game.intro_done:
		hud.show_popup("MOUNTAIN MOVERS", "Your first day at Mountain Movers Inc.\n\nThe boss points out the window.\n\"See that mountain over there? I want it gone!\"\n\nClick to grab rock. Sell what you find. Buy upgrades. Move the mountain.",
			[["Yes, boss.", func():
				Game.intro_done = true
				Game.say(Quips.pick(Quips.INTRO))]])
	else:
		Game.say("Oh, you're back. The mountain isn't going to move itself.")


func _new_mountain() -> void:
	var size := Game.mountain_size()
	mountain.generate(size.x, size.y, Game.mountain_seed, Game.hp_mult(), Game.luck(), Game.level)
	workers.reset()


func _layout_mountain() -> void:
	var s := minf(MOUNTAIN_AREA.size.x / mountain.w, MOUNTAIN_AREA.size.y / mountain.h)
	mountain.set_cell_scale(s)
	var size := mountain.pixel_size()
	mountain.position = Vector2(MOUNTAIN_AREA.position.x + (MOUNTAIN_AREA.size.x - size.x) * 0.5, GROUND_Y - size.y)


# ----------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if hud.is_popup_open():
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_holding = mb.pressed
			if mb.pressed:
				Game.stats["clicks"] = int(Game.stats["clicks"]) + 1
				_grab(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_throw_dynamite(mb.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_SPACE:
			_throw_dynamite(get_global_mouse_position())
		elif OS.is_debug_build():
			_debug_key(key)


func _debug_key(key: Key) -> void:
	match key:
		KEY_F9:
			Game.add_money(1000.0 * Game.value_mult())
			Game.changed.emit()
		KEY_F10:
			Game.approval += 25
			Game.changed.emit()
		KEY_F11:
			mountain.force_clear()


func _grab(screen_pos: Vector2) -> void:
	var c := mountain.world_to_cell(screen_pos)
	if not mountain.in_bounds(c):
		return
	_particle_budget = 60
	mountain.damage_circle(c, Game.click_radius(), Game.click_damage())


func _throw_dynamite(at: Vector2) -> void:
	if Game.dynamite_level() == 0 or _dyn_cooldown > 0.0:
		return
	if at.x > Hud.PANEL_X or at.y < 60:
		return
	_dyn_cooldown = Game.dynamite_cooldown()
	var s := Sprite2D.new()
	s.texture = _dynamite_tex
	s.scale = Vector2(3, 3)
	s.position = at
	world.add_child(s)
	_dynamites.append({"node": s, "fuse": 1.2})


func _explode(at: Vector2) -> void:
	var c := mountain.world_to_cell(at)
	var r := Game.dynamite_radius()
	_particle_budget = 250
	mountain.damage_circle(c, r, Game.dynamite_damage(), true)
	_shake = 0.35
	for i in 30:
		debris.spawn(at, [Color(1, 0.8, 0.2), Color(1, 0.4, 0.1), Color(0.3, 0.3, 0.3)][i % 3], 6.0, 1.8)
	if randf() < 0.35:
		Game.say(Quips.pick(Quips.DYNAMITE), 3.0)


# --------------------------------------------------------------- frame

func _process(delta: float) -> void:
	# Jackhammer: hold to dig.
	if _holding and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_holding = false
	var rate := Game.jackhammer_rate()
	if _holding and rate > 0.0 and not hud.is_popup_open():
		_jack_accum += rate * delta
		while _jack_accum >= 1.0:
			_jack_accum -= 1.0
			_grab(get_global_mouse_position())
	else:
		_jack_accum = 0.0

	# Dynamite fuses.
	_dyn_cooldown = maxf(0.0, _dyn_cooldown - delta)
	for i in range(_dynamites.size() - 1, -1, -1):
		var d: Dictionary = _dynamites[i]
		d["fuse"] = float(d["fuse"]) - delta
		var node: Sprite2D = d["node"]
		node.rotation = sin(float(d["fuse"]) * 30.0) * 0.2
		if float(d["fuse"]) <= 0.0:
			_explode(node.position)
			node.queue_free()
			_dynamites.remove_at(i)
	if Game.dynamite_level() == 0:
		hud.dynamite_status = "Dynamite: locked"
	elif _dyn_cooldown > 0.0:
		hud.dynamite_status = "Dynamite: %.1fs" % _dyn_cooldown
	else:
		hud.dynamite_status = "Dynamite: READY\n(right-click)"

	# Screen shake.
	if _shake > 0.0:
		_shake -= delta
		world.position = Vector2(randf_range(-6, 6), randf_range(-6, 6)) * (_shake / 0.35)
	else:
		world.position = Vector2.ZERO

	_particle_budget = maxi(_particle_budget, 12)

	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = AUTOSAVE_SECONDS
		_save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()


func _save() -> void:
	Game.save_game(mountain.serialize())


# ------------------------------------------------------------- events

func _on_cell_destroyed(mat: int, pos: Vector2, color: Color) -> void:
	Game.collect(mat)
	if _particle_budget > 0:
		_particle_budget -= 1
		debris.spawn(pos, color, mountain.cell_scale)
	if Materials.DATA[mat]["kind"] == "ore":
		_float_text(pos, "+" + Materials.DATA[mat]["name"], Materials.DATA[mat]["color"])


func _on_item_found(item_name: String, base_value: float, _mat: int, pos: Vector2) -> void:
	var value := Game.collect_item(item_name, base_value)
	_float_text(pos + Vector2(0, -20), "Found: %s! ($%s)" % [item_name, Game.fmt(value)], Color(1, 0.75, 1), 18)
	Game.say(Quips.pick(Quips.ITEM), 3.5)


func _on_cleared() -> void:
	_holding = false
	var award := Game.clear_award()
	var last := Game.level >= Game.MOUNTAIN_COUNT - 1
	_save()
	hud.show_popup("MOUNTAIN MOVED!",
		"%s is gone.\n\nBoss: \"%s\"\n\n+%d Boss Approval%s" % [
			Game.mountain_name(), Quips.pick(Quips.CLEAR), award,
			"" if last else "\n\n...but a bigger one is already growing back."],
		[["Collect & continue", _advance]])


func _advance() -> void:
	Game.complete_mountain()
	if Game.won:
		_show_victory()
		return
	_new_mountain()
	_layout_mountain()
	_save()
	Game.say(Quips.pick(Quips.NEW_MOUNTAIN))


func _on_regrow() -> void:
	Game.bail_out(mountain.moved_fraction())
	_new_mountain()
	_layout_mountain()
	_save()
	Game.say(Quips.pick(Quips.BAILOUT))


func _on_wipe() -> void:
	Game.wipe()
	_new_mountain()
	_layout_mountain()
	get_tree().reload_current_scene()


func _show_victory() -> void:
	Game.say(Quips.pick(Quips.VICTORY), 999.0)
	hud.show_popup("YOU WIN!",
		"All seven mountains are gone. The horizon is flat. For the first time in recorded history, the boss is happy.\n\nPixels moved: %s\nFinds: %d" % [
			Game.fmt(float(Game.stats["pixels"])), int(Game.stats["finds"])],
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
	l.position = pos + Vector2(-20, -10)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 50, 1.2)
	tw.tween_property(l, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(func():
		_floaters -= 1
		l.queue_free())
