class_name Hud
extends CanvasLayer
## All UI, built in code so it is easy to read and restyle (colours live in
## theme_builder.gd). Top bar: money, approval, progress, truck. Right panel
## (collapsible, Tab key): Crew / Military / Items / Boss. Bottom: item hotbar.
## Bottom-left: the boss.

signal regrow_confirmed
signal wipe_confirmed
signal send_truck
signal item_selected(id: String)
signal panel_toggled(open: bool)


const TOP_H := 50.0
const PANEL_W := 316.0
const HANDLE_W := 22.0
const SCREEN := Vector2(1280, 720)

var mountain: Mountain
var depot: TruckDepot
var hand: Hand
var boss: Boss
var panel_open := true

var _root: Control
var _money: Label
var _shown_money := 0.0
var _approval: Label
var _mountain_label: Label
var _progress: ProgressBar
var _truck_label: Label
var _send_btn: Button
var _panel: PanelContainer
var _handle: Button
var _rows := {}       # id -> {"button", "name", "level", "price", "def", "kind"}
var _hotbar := {}     # id -> {"button", "count"}
var _hotbar_box: HBoxContainer
var _approval_big: Label
var _regrow_btn: Button
var _stats: Label
var _crt_check: CheckButton
var _toasts: VBoxContainer
var _flash: ColorRect
var _popup_bg: ColorRect
var _popup_title: Label
var _popup_body: Label
var _popup_buttons: HBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	_root = Control.new()
	_root.size = SCREEN
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = ThemeBuilder.build()
	add_child(_root)
	_build_vignette()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.size = SCREEN
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_build_top_bar()
	_build_side_panel()
	_build_hotbar()
	_toasts = VBoxContainer.new()
	_toasts.custom_minimum_size = Vector2(420, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_toasts)
	boss = Boss.new()
	_root.add_child(boss)
	_build_popup()
	_shown_money = Game.money
	_layout(false)
	Game.changed.connect(refresh)
	refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_TAB:
		toggle_panel()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.2
		refresh()
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 0.8)
	# Rolling money counter with a little punch when it goes up.
	var target := Game.money
	if absf(target - _shown_money) < 0.05 or absf(target - _shown_money) / maxf(target, 1.0) < 0.001:
		_shown_money = target
	else:
		if target > _shown_money and _money.scale.x < 1.05:
			_money.scale = Vector2(1.18, 1.18)
		_shown_money = lerpf(_shown_money, target, minf(1.0, delta * 9.0))
	_money.text = "$" + Game.fmt(_shown_money)
	_money.scale = _money.scale.lerp(Vector2.ONE, minf(1.0, delta * 10.0))


## Screen area the world shows through (for camera framing).
func play_area() -> Rect2:
	var right := SCREEN.x - (PANEL_W if panel_open else 0.0)
	return Rect2(0, TOP_H, right, SCREEN.y - TOP_H)


func flash(strength: float) -> void:
	_flash.color = Color(1, 0.97, 0.9, clampf(strength, 0.0, 1.0))


func toast(text: String, color := ThemeBuilder.TEXT) -> void:
	var l := _label(text, 16, color, ThemeBuilder.title_font)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	if _toasts.get_child_count() > 3:
		_toasts.get_child(0).queue_free()


## True if the mouse is over UI (so clicks shouldn't reach the world).
func mouse_over_ui(p: Vector2) -> bool:
	if is_popup_open() or p.y < TOP_H:
		return true
	if panel_open and p.x >= SCREEN.x - PANEL_W - HANDLE_W:
		return true
	if not panel_open and p.x >= SCREEN.x - HANDLE_W and p.y < TOP_H + 90:
		return true
	return _hotbar_box.get_global_rect().grow(4).has_point(p)


func toggle_panel() -> void:
	panel_open = not panel_open
	Sfx.play("tick", -6.0)
	_layout(true)
	panel_toggled.emit(panel_open)


func _layout(animate: bool) -> void:
	var panel_x := SCREEN.x - PANEL_W if panel_open else SCREEN.x + 4.0
	if animate:
		var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_panel, "position:x", panel_x, 0.22)
		tw.tween_property(_handle, "position:x", panel_x - HANDLE_W, 0.22)
	else:
		_panel.position.x = panel_x
		_handle.position.x = panel_x - HANDLE_W
	_handle.text = ">" if panel_open else "<"
	_handle.tooltip_text = ("Hide" if panel_open else "Show") + " the shop (Tab)"
	var area := play_area()
	if boss:
		boss.right_edge = area.end.x
	_toasts.position = Vector2(area.get_center().x - 210, TOP_H + 14)
	_hotbar_box.reset_size()
	_hotbar_box.position = Vector2(area.get_center().x - _hotbar_box.size.x * 0.5 + 60.0, SCREEN.y - _hotbar_box.size.y - 10)


# ---------------------------------------------------------------- builders

func _label(text: String, size := 16, color := ThemeBuilder.TEXT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font:
		l.add_theme_font_override("font", font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap(text: String, size := 14, color := ThemeBuilder.DIM) -> Label:
	var l := _label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(270, 0)
	return l


func _build_vignette() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 0.6))
	g.add_point(0.55, Color(0, 0, 0, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.05, 1.05)
	tex.width = 256
	tex.height = 256
	var vig := TextureRect.new()
	vig.texture = tex
	vig.size = SCREEN
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(vig)


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.size = Vector2(SCREEN.x, TOP_H)
	var sb := ThemeBuilder.box(Color(0.045, 0.04, 0.055, 0.92), ThemeBuilder.BORDER, 0, 10.0)
	sb.border_width_bottom = 1
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	bar.add_theme_stylebox_override("panel", sb)
	_root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	bar.add_child(hb)

	_money = _label("$0", 26, ThemeBuilder.MONEY, ThemeBuilder.title_font)
	_money.custom_minimum_size = Vector2(190, 0)
	_money.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money.pivot_offset = Vector2(10, 20)
	hb.add_child(_money)

	_approval = _label("", 16, ThemeBuilder.APPROVAL, ThemeBuilder.title_font)
	_approval.custom_minimum_size = Vector2(120, 0)
	_approval.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_approval.mouse_filter = Control.MOUSE_FILTER_PASS
	_approval.tooltip_text = "Boss Approval. Earned by moving mountains; spend it in the Boss tab."
	hb.add_child(_approval)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)
	_mountain_label = _label("", 14, ThemeBuilder.TEXT)
	vb.add_child(_mountain_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.show_percentage = false
	vb.add_child(_progress)

	_truck_label = _label("", 14, ThemeBuilder.ACCENT)
	_truck_label.custom_minimum_size = Vector2(170, 0)
	_truck_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(_truck_label)
	_send_btn = Button.new()
	_send_btn.text = "Send truck"
	_send_btn.tooltip_text = "Send the parked truck off now, even if it isn't full."
	_send_btn.pressed.connect(func(): send_truck.emit())
	hb.add_child(_send_btn)


func _build_side_panel() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(SCREEN.x - PANEL_W, TOP_H)
	_panel.size = Vector2(PANEL_W, SCREEN.y - TOP_H)
	var sb := ThemeBuilder.box(ThemeBuilder.BG, ThemeBuilder.BORDER, 0, 6.0)
	sb.border_width_left = 1
	_panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(_panel)
	var tabs := TabContainer.new()
	tabs.tab_changed.connect(func(_i): Sfx.play("tick", -10.0))
	_panel.add_child(tabs)

	var crew := _scroll_tab(tabs, "Crew")
	for def in UpgradeDefs.RUN:
		_rows[def["id"]] = _upgrade_row(crew, def, "run")

	var mil := _scroll_tab(tabs, "Army")
	for def in UpgradeDefs.MILITARY:
		_rows[def["id"]] = _upgrade_row(mil, def, "run")

	var items := _scroll_tab(tabs, "Items")
	items.add_child(_wrap("Buy here, then pick one on the hotbar (or press 1-5) and click where it goes."))
	for def in UpgradeDefs.ITEMS:
		_rows[def["id"]] = _upgrade_row(items, def, "item")

	var boss_tab := _scroll_tab(tabs, "Boss")
	_approval_big = _label("", 15, ThemeBuilder.APPROVAL, ThemeBuilder.title_font)
	boss_tab.add_child(_approval_big)
	boss_tab.add_child(_wrap("Permanent perks. Kept through every mountain."))
	for def in UpgradeDefs.PERM:
		_rows[def["id"]] = _upgrade_row(boss_tab, def, "perm")
	boss_tab.add_child(HSeparator.new())
	_regrow_btn = Button.new()
	_regrow_btn.custom_minimum_size = Vector2(0, 36)
	_regrow_btn.tooltip_text = "Restart this mountain for a share of the approval. Clearing it pays in full and moves you on."
	_regrow_btn.pressed.connect(_ask_regrow)
	boss_tab.add_child(_regrow_btn)
	var vol_row := HBoxContainer.new()
	vol_row.add_child(_label("Volume", 14, ThemeBuilder.DIM))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = Game.volume
	vol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol.value_changed.connect(func(v):
		Game.volume = v
		Sfx.play("grab"))
	vol_row.add_child(vol)
	boss_tab.add_child(vol_row)
	_crt_check = CheckButton.new()
	_crt_check.text = "CRT TV effect  (F2)"
	_crt_check.button_pressed = Game.crt
	_crt_check.tooltip_text = "Scanlines, curved glass and a bit of flicker, like an old TV."
	_crt_check.toggled.connect(func(on: bool):
		Game.crt = on
		Sfx.play("tick")
		Game.changed.emit())
	boss_tab.add_child(_crt_check)
	boss_tab.add_child(_wrap("Left-click the mountain to break off rock; drag it to the truck bed and let go. Hold to keep digging and to vacuum up loose rocks. Only right-click drops what you hold (flick the mouse while right-clicking to throw). Undercut the mountain to trigger cave-ins! WASD / right-drag to move, wheel to zoom, F to re-centre, Tab hides this panel."))
	_stats = _wrap("")
	boss_tab.add_child(_stats)
	var wipe := Button.new()
	wipe.text = "Wipe save"
	wipe.pressed.connect(_ask_wipe)
	boss_tab.add_child(wipe)

	_handle = Button.new()
	_handle.size = Vector2(HANDLE_W, 72)
	_handle.position = Vector2(SCREEN.x - PANEL_W - HANDLE_W, TOP_H + 10)
	_handle.add_theme_font_override("font", ThemeBuilder.title_font)
	_handle.pressed.connect(toggle_panel)
	_root.add_child(_handle)


func _scroll_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	sc.add_child(vb)
	return vb


## One shop row: [icon] Name / level underneath ........ price.
## The whole row is the buy button; hovering shows the description.
func _upgrade_row(parent: VBoxContainer, def: Dictionary, kind: String) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 54)
	btn.tooltip_text = def["desc"]
	btn.mouse_entered.connect(func(): Sfx.play("tick", -18.0, 0.1, 40))
	parent.add_child(btn)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -8
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.05, 0.045, 0.06), ThemeBuilder.BORDER, 1, 3.0))
	frame.custom_minimum_size = Vector2(44, 44)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(frame)
	var icon := TextureRect.new()
	var path := "res://assets/icons/%s.png" % def["id"]
	if ResourceLoader.exists(path):
		icon.texture = load(path)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(36, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 0)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)
	var name_l := _label(def["name"], 16, ThemeBuilder.TEXT)
	name_l.clip_text = true
	vb.add_child(name_l)
	var lvl := _label("", 11, ThemeBuilder.ACCENT, ThemeBuilder.title_font)
	vb.add_child(lvl)

	var price := _label("", 12, ThemeBuilder.MONEY, ThemeBuilder.title_font)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	price.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(price)

	var id: String = def["id"]
	btn.pressed.connect(func():
		var ok := false
		match kind:
			"run":
				ok = Game.buy_run(id)
			"item":
				ok = Game.buy_item(id)
			"perm":
				ok = Game.buy_perm(id)
		if ok:
			btn.modulate = Color(1.6, 1.4, 1.0)
			btn.create_tween().tween_property(btn, "modulate", Color.WHITE, 0.3)
			icon.scale = Vector2(1.3, 1.3)
			icon.pivot_offset = Vector2(18, 18)
			icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		else:
			Sfx.play("deny", -8.0))
	return {"button": btn, "name": name_l, "level": lvl, "price": price, "def": def, "kind": kind}


func _build_hotbar() -> void:
	_hotbar_box = HBoxContainer.new()
	_hotbar_box.add_theme_constant_override("separation", 6)
	_root.add_child(_hotbar_box)
	for def in UpgradeDefs.ITEMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(58, 58)
		b.toggle_mode = true
		b.tooltip_text = "%s  [%s]\n%s" % [def["name"], def["key"], def["desc"]]
		var id: String = def["id"]
		b.pressed.connect(func(): item_selected.emit(id))
		_hotbar_box.add_child(b)
		var icon := TextureRect.new()
		icon.texture = load("res://assets/icons/%s.png" % id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 9
		icon.offset_top = 9
		icon.offset_right = -9
		icon.offset_bottom = -9
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)
		var key := _label(def["key"], 10, ThemeBuilder.DIM, ThemeBuilder.title_font)
		key.position = Vector2(4, 1)
		b.add_child(key)
		var count := _label("", 11, ThemeBuilder.TEXT, ThemeBuilder.title_font)
		count.position = Vector2(34, 40)
		count.add_theme_color_override("font_outline_color", Color.BLACK)
		count.add_theme_constant_override("outline_size", 4)
		b.add_child(count)
		_hotbar[id] = {"button": b, "count": count}


func set_armed(id: String) -> void:
	for k in _hotbar:
		(_hotbar[k]["button"] as Button).set_pressed_no_signal(k == id)


# ----------------------------------------------------------------- popup

func _build_popup() -> void:
	_popup_bg = ColorRect.new()
	_popup_bg.color = Color(0, 0, 0, 0.7)
	_popup_bg.size = SCREEN
	_popup_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_popup_bg)
	var center := CenterContainer.new()
	center.size = SCREEN
	_popup_bg.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeBuilder.box(ThemeBuilder.BG_SOLID, ThemeBuilder.ACCENT, 1, 24.0))
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)
	_popup_title = _label("", 28, ThemeBuilder.ACCENT, ThemeBuilder.title_font)
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_popup_title)
	_popup_body = _label("", 18, ThemeBuilder.TEXT)
	_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_body.custom_minimum_size = Vector2(500, 0)
	_popup_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_popup_body)
	_popup_buttons = HBoxContainer.new()
	_popup_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_popup_buttons.add_theme_constant_override("separation", 16)
	vb.add_child(_popup_buttons)
	_popup_bg.visible = false


func is_popup_open() -> bool:
	return _popup_bg.visible


## buttons: Array of [text, Callable]
func show_popup(title: String, body: String, buttons: Array) -> void:
	_popup_title.text = title
	_popup_body.text = body
	for c in _popup_buttons.get_children():
		c.queue_free()
	for b in buttons:
		var btn := Button.new()
		btn.text = "  %s  " % b[0]
		btn.custom_minimum_size = Vector2(150, 42)
		var cb: Callable = b[1]
		btn.pressed.connect(func():
			_popup_bg.visible = false
			cb.call())
		_popup_buttons.add_child(btn)
	_popup_bg.visible = true
	_popup_bg.modulate.a = 0.0
	create_tween().tween_property(_popup_bg, "modulate:a", 1.0, 0.2)


func _ask_regrow() -> void:
	var frac := mountain.moved_fraction() if mountain else 0.0
	show_popup("Regrow it?",
		"You'll restart %s from scratch (crew, trucks, army and cash reset) and get %d Boss Approval for the %d%% you moved." % [
			Game.mountain_name(), Game.bailout_award(frac), int(frac * 100)],
		[["Regrow it", func(): regrow_confirmed.emit()], ["Keep digging", func(): pass]])


func _ask_wipe() -> void:
	show_popup("Wipe save?", "Everything goes. Even the approval. The boss will forget you exist (he already does).",
		[["Wipe it", func(): wipe_confirmed.emit()], ["Cancel", func(): pass]])


# --------------------------------------------------------------- refresh

func refresh() -> void:
	if _money == null:
		return
	_approval.text = "* %d" % Game.approval
	var frac := mountain.moved_fraction() if mountain else 0.0
	_mountain_label.text = "%d/%d  %s   %.1f%%" % [Game.level + 1, Game.MOUNTAIN_COUNT, Game.mountain_name(), frac * 100.0]
	_progress.value = frac * 100.0
	if depot:
		var tr: Variant = depot.loading_truck()
		var away := 0
		for t in depot.trucks:
			if t["state"] in ["leaving", "away"]:
				away += 1
		var road := "  (%d on the road)" % away if away > 0 else ""
		if tr != null:
			_truck_label.text = "Truck %d/%d%s" % [int(tr["n"]), Game.truck_capacity(), road]
		else:
			_truck_label.text = "No truck parked%s" % road
		_send_btn.disabled = tr == null or int(tr["n"]) == 0

	for id in _rows:
		var row: Dictionary = _rows[id]
		var def: Dictionary = row["def"]
		var btn: Button = row["button"]
		var lvl_l: Label = row["level"]
		var price_l: Label = row["price"]
		var price := 0.0
		var can := false
		var maxed := false
		match row["kind"]:
			"run":
				var lvl := Game.run_lvl(id)
				var is_count: bool = id in ["intern", "soldier", "gunner", "technical", "tank", "bulldozer", "truck_count"]
				lvl_l.text = ("x%d" % (lvl + (1 if id == "truck_count" else 0))) if is_count else "LV %d" % lvl
				maxed = Game.is_maxed(def, lvl)
				price = Game.run_cost(id)
				can = Game.money >= price
			"item":
				lvl_l.text = "HAVE %d" % Game.item_count(id)
				price = Game.item_cost(id)
				can = Game.money >= price
			"perm":
				var lvl := Game.perm_lvl(id)
				lvl_l.text = "LV %d" % lvl
				maxed = Game.is_maxed(def, lvl)
				price = Game.perm_cost(id)
				can = Game.approval >= price
		if maxed:
			price_l.text = "MAX"
			price_l.add_theme_color_override("font_color", ThemeBuilder.DIM)
			btn.disabled = true
		else:
			price_l.text = ("* %d" % int(price)) if row["kind"] == "perm" else "$" + Game.fmt(price)
			var col := (ThemeBuilder.APPROVAL if row["kind"] == "perm" else ThemeBuilder.MONEY) if can else ThemeBuilder.BAD
			price_l.add_theme_color_override("font_color", col)
			btn.disabled = not can
		btn.modulate.a = 1.0 if can or maxed else 0.6

	for def in UpgradeDefs.ITEMS:
		var h: Dictionary = _hotbar[def["id"]]
		var count := Game.item_count(def["id"])
		(h["count"] as Label).text = str(count) if count > 0 else ""
		(h["button"] as Button).modulate.a = 1.0 if count > 0 else 0.45

	if _crt_check and _crt_check.button_pressed != Game.crt:
		_crt_check.set_pressed_no_signal(Game.crt)
	_approval_big.text = "Approval: * %d" % Game.approval
	_regrow_btn.text = "Regrow mountain  (+%d)" % Game.bailout_award(frac)
	_stats.text = "Pixels moved: %s\nClicks: %s\nFinds: %d\nTruckloads: %d\nCave-ins: %d\nMountains moved: %d\nTotal earned: $%s" % [
		Game.fmt(float(Game.stats["pixels"])), Game.fmt(float(Game.stats["clicks"])),
		int(Game.stats["finds"]), int(Game.stats.get("trucks", 0)), int(Game.stats.get("caveins", 0)), int(Game.stats["mountains"]), Game.fmt(float(Game.stats["earned"]))]
