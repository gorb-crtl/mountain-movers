class_name Hud
extends CanvasLayer
## All UI, built in code so it is easy to read and restyle.
## Top bar: money, approval, progress, truck. Right panel: Crew / Military / Items / Boss.
## Bottom: hotbar of one-use items. Bottom-left: the boss.

signal regrow_confirmed
signal wipe_confirmed
signal send_truck
signal item_selected(id: String)

const PANEL_X := 960.0
const TOP_H := 58.0
## Screen area the world is visible in (for camera framing).
const PLAY_AREA := Rect2(0, TOP_H, PANEL_X, 720 - TOP_H)

var mountain: Mountain
var depot: TruckDepot
var hand: Hand
var boss: Boss

var _money: Label
var _approval: Label
var _mountain_label: Label
var _progress: ProgressBar
var _truck_label: Label
var _send_btn: Button
var _rows := {}       # id -> {"title", "button", "def", "kind"}
var _hotbar := {}     # id -> Button
var _approval_big: Label
var _regrow_btn: Button
var _stats: Label
var _toasts: VBoxContainer
var _flash: ColorRect
var _popup_bg: ColorRect
var _popup_title: Label
var _popup_body: Label
var _popup_buttons: HBoxContainer
var _refresh_timer := 0.0


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)
	_build_top_bar(root)
	_build_side_panel(root)
	_build_hotbar(root)
	_toasts = VBoxContainer.new()
	_toasts.position = Vector2(PANEL_X * 0.5 - 150, TOP_H + 10)
	_toasts.custom_minimum_size = Vector2(300, 0)
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)
	boss = Boss.new()
	boss.position = Vector2(10, 712)
	root.add_child(boss)
	_build_popup(root)
	Game.changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.2
		refresh()
	if _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - delta * 0.8)


func flash(strength: float) -> void:
	_flash.color = Color(1, 1, 0.95, clampf(strength, 0.0, 1.0))


func toast(text: String, color := Color(0.6, 1, 0.6)) -> void:
	var l := _mk_label(18, color, text)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	_toasts.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	if _toasts.get_child_count() > 4:
		_toasts.get_child(0).queue_free()


## True if the mouse is over a UI panel (so clicks shouldn't reach the world).
func mouse_over_ui(p: Vector2) -> bool:
	return p.x >= PANEL_X or p.y < TOP_H or _hotbar_rect().has_point(p) or is_popup_open()


# ---------------------------------------------------------------- layout

func _panel_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.12, 0.08, 0.05)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(8)
	return sb


func _build_top_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.size = Vector2(PANEL_X, TOP_H)
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.24, 0.16, 0.10, 0.94)))
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	bar.add_child(hb)
	_money = _mk_label(22, Color(0.55, 1.0, 0.55))
	_money.custom_minimum_size = Vector2(130, 0)
	hb.add_child(_money)
	_approval = _mk_label(15, Color(1.0, 0.85, 0.4))
	_approval.custom_minimum_size = Vector2(150, 0)
	hb.add_child(_approval)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	_mountain_label = _mk_label(13, Color.WHITE)
	vb.add_child(_mountain_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 14)
	_progress.show_percentage = false
	vb.add_child(_progress)
	_truck_label = _mk_label(13, Color(1, 0.9, 0.5))
	_truck_label.custom_minimum_size = Vector2(150, 0)
	hb.add_child(_truck_label)
	_send_btn = Button.new()
	_send_btn.text = "Send truck"
	_send_btn.tooltip_text = "Send the parked truck off now, even if it isn't full."
	_send_btn.pressed.connect(func(): send_truck.emit())
	hb.add_child(_send_btn)


func _build_side_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(PANEL_X, 0)
	panel.size = Vector2(1280 - PANEL_X, 720)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.20, 0.14, 0.10)))
	root.add_child(panel)
	var tabs := TabContainer.new()
	panel.add_child(tabs)

	var crew := _scroll_tab(tabs, "Crew")
	for def in UpgradeDefs.RUN:
		_rows[def["id"]] = _upgrade_row(crew, def, "run")

	var mil := _scroll_tab(tabs, "Military")
	mil.add_child(_wrap_label("They set up on the far side of the mountain and shoot it. Whatever they knock loose still has to be hauled."))
	for def in UpgradeDefs.MILITARY:
		_rows[def["id"]] = _upgrade_row(mil, def, "run")

	var items := _scroll_tab(tabs, "Items")
	items.add_child(_wrap_label("One-use toys. Buy them here, then pick one on the hotbar (or press its number key) and click where it should go."))
	for def in UpgradeDefs.ITEMS:
		_rows[def["id"]] = _upgrade_row(items, def, "item")

	var boss_tab := _scroll_tab(tabs, "Boss")
	_approval_big = _mk_label(18, Color(1, 0.85, 0.4))
	boss_tab.add_child(_approval_big)
	boss_tab.add_child(_wrap_label("Permanent perks. Bought with Boss Approval, kept through every mountain."))
	for def in UpgradeDefs.PERM:
		_rows[def["id"]] = _upgrade_row(boss_tab, def, "perm")
	boss_tab.add_child(HSeparator.new())
	_regrow_btn = Button.new()
	_regrow_btn.custom_minimum_size = Vector2(0, 40)
	_regrow_btn.pressed.connect(_ask_regrow)
	boss_tab.add_child(_regrow_btn)
	boss_tab.add_child(_wrap_label("Regrowing restarts this mountain for a share of the approval. Clearing it pays in full and moves you on."))
	boss_tab.add_child(HSeparator.new())
	var vol_row := HBoxContainer.new()
	vol_row.add_child(_mk_label(13, Color(0.85, 0.8, 0.72), "Volume"))
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
	boss_tab.add_child(_wrap_label("Controls: left-click the mountain to break off rock, drag it to the truck and let go (or fling it in). Right-click to drop. WASD / arrows / right-drag to move, mouse wheel to zoom, F to re-centre, Esc to cancel an item."))
	_stats = _wrap_label("")
	boss_tab.add_child(_stats)
	var wipe := Button.new()
	wipe.text = "Wipe save"
	wipe.pressed.connect(_ask_wipe)
	boss_tab.add_child(wipe)


func _build_hotbar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "Hotbar"
	bar.add_theme_constant_override("separation", 6)
	root.add_child(bar)
	for def in UpgradeDefs.ITEMS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 54)
		b.toggle_mode = true
		b.icon = load("res://assets/sprites/%s.png" % def["id"])
		b.expand_icon = false
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_font_size_override("font_size", 12)
		var id: String = def["id"]
		b.pressed.connect(func(): item_selected.emit(id))
		bar.add_child(b)
		_hotbar[id] = b
	bar.position = Vector2(PANEL_X * 0.5 - (96 * 5 + 24) * 0.5 + 60, 720 - 60)


func _hotbar_rect() -> Rect2:
	return Rect2(PANEL_X * 0.5 - (96 * 5 + 24) * 0.5 + 60, 720 - 62, 96 * 5 + 24, 62)


func set_armed(id: String) -> void:
	for k in _hotbar:
		(_hotbar[k] as Button).set_pressed_no_signal(k == id)


func _scroll_tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 6)
	sc.add_child(vb)
	return vb


func _upgrade_row(parent: VBoxContainer, def: Dictionary, kind: String) -> Dictionary:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _panel_style(Color(0.30, 0.22, 0.15)))
	parent.add_child(box)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	box.add_child(vb)
	var title := _mk_label(15, Color(1, 0.95, 0.8))
	vb.add_child(title)
	vb.add_child(_wrap_label(def["desc"], 12))
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 28)
	var id: String = def["id"]
	match kind:
		"run":
			btn.pressed.connect(func(): Game.buy_run(id))
		"item":
			btn.pressed.connect(func(): Game.buy_item(id))
		"perm":
			btn.pressed.connect(func(): Game.buy_perm(id))
	vb.add_child(btn)
	return {"title": title, "button": btn, "def": def, "kind": kind}


func _mk_label(size: int, color: Color, text := "") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _wrap_label(text: String, size := 13) -> Label:
	var l := _mk_label(size, Color(0.85, 0.8, 0.72), text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(250, 0)
	return l


# ----------------------------------------------------------------- popup

func _build_popup(root: Control) -> void:
	_popup_bg = ColorRect.new()
	_popup_bg.color = Color(0, 0, 0, 0.55)
	_popup_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_popup_bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_popup_bg.add_child(center)
	var panel := PanelContainer.new()
	var sb := _panel_style(Color(0.28, 0.19, 0.12))
	sb.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	_popup_title = _mk_label(30, Color(1, 0.85, 0.4))
	_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_popup_title)
	_popup_body = _mk_label(17, Color(1, 0.97, 0.9))
	_popup_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_body.custom_minimum_size = Vector2(480, 0)
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
		btn.custom_minimum_size = Vector2(140, 40)
		var cb: Callable = b[1]
		btn.pressed.connect(func():
			_popup_bg.visible = false
			cb.call())
		_popup_buttons.add_child(btn)
	_popup_bg.visible = true


func _ask_regrow() -> void:
	var frac := mountain.moved_fraction() if mountain else 0.0
	show_popup("Regrow this mountain?",
		"You'll restart %s from scratch (crew, trucks, military and cash reset) and get %d Boss Approval for the %d%% you moved." % [
			Game.mountain_name(), Game.bailout_award(frac), int(frac * 100)],
		[["Regrow it", func(): regrow_confirmed.emit()], ["Keep digging", func(): pass]])


func _ask_wipe() -> void:
	show_popup("Wipe your save?", "Everything goes. Even the approval. The boss will forget you exist (he already does).",
		[["Wipe it", func(): wipe_confirmed.emit()], ["Cancel", func(): pass]])


# --------------------------------------------------------------- refresh

func refresh() -> void:
	if _money == null:
		return
	_money.text = "$" + Game.fmt(Game.money)
	_approval.text = "Boss Approval: %d" % Game.approval
	var frac := mountain.moved_fraction() if mountain else 0.0
	_mountain_label.text = "Mountain %d/%d: %s  -  %.1f%% moved" % [Game.level + 1, Game.MOUNTAIN_COUNT, Game.mountain_name(), frac * 100.0]
	_progress.value = frac * 100.0
	if depot:
		var tr: Variant = depot.loading_truck()
		var away := 0
		for t in depot.trucks:
			if t["state"] in ["leaving", "away"]:
				away += 1
		if tr != null:
			_truck_label.text = "Truck: %d/%d\n%d of %d on the road" % [int(tr["n"]), Game.truck_capacity(), away, depot.trucks.size()]
		else:
			_truck_label.text = "No truck parked!\n%d of %d on the road" % [away, depot.trucks.size()]
		_send_btn.disabled = tr == null or int(tr["n"]) == 0

	for id in _rows:
		var row: Dictionary = _rows[id]
		var def: Dictionary = row["def"]
		var btn: Button = row["button"]
		match row["kind"]:
			"run":
				var lvl := Game.run_lvl(id)
				row["title"].text = "%s  (%s %d)" % [def["name"], "x" if def.get("max", -1) != 1 else "Lv", lvl]
				if Game.is_maxed(def, lvl):
					btn.text = "MAXED"
					btn.disabled = true
				else:
					var price := Game.run_cost(id)
					btn.text = "Buy  $" + Game.fmt(price)
					btn.disabled = Game.money < price
			"item":
				row["title"].text = "%s  [%s]  (have %d)" % [def["name"], def["key"], Game.item_count(id)]
				var price := Game.item_cost(id)
				btn.text = "Buy  $" + Game.fmt(price)
				btn.disabled = Game.money < price
			"perm":
				var lvl := Game.perm_lvl(id)
				row["title"].text = "%s  (Lv %d)" % [def["name"], lvl]
				if Game.is_maxed(def, lvl):
					btn.text = "MAXED"
					btn.disabled = true
				else:
					var price := Game.perm_cost(id)
					btn.text = "Buy  %d approval" % price
					btn.disabled = Game.approval < price

	for def in UpgradeDefs.ITEMS:
		var b: Button = _hotbar[def["id"]]
		var count := Game.item_count(def["id"])
		b.text = "%s  %s x%d" % [def["key"], def["name"], count] if count > 0 else "%s  %s" % [def["key"], def["name"]]
		b.modulate = Color(1, 1, 1, 1.0 if count > 0 else 0.5)

	_approval_big.text = "Boss Approval: %d" % Game.approval
	_regrow_btn.text = "Regrow mountain  (+%d approval)" % Game.bailout_award(frac)
	_stats.text = "Pixels moved: %s\nClicks: %s\nFinds dug up: %d\nTruckloads sold: %d\nMountains moved: %d\nTotal earned: $%s" % [
		Game.fmt(float(Game.stats["pixels"])), Game.fmt(float(Game.stats["clicks"])),
		int(Game.stats["finds"]), int(Game.stats.get("trucks", 0)), int(Game.stats["mountains"]), Game.fmt(float(Game.stats["earned"]))]
