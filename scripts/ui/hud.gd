class_name Hud
extends CanvasLayer
## All UI, built in code so it is easy to read and restyle.
## Top bar: money, approval, mountain progress. Right panel: Upgrades / Loot / Boss tabs.

signal regrow_confirmed
signal wipe_confirmed

const PANEL_X := 940.0

var mountain: Mountain
var dynamite_status := ""

var _money: Label
var _approval: Label
var _mountain_label: Label
var _progress: ProgressBar
var _dyn_label: Label
var _run_rows := {}
var _perm_rows := {}
var _loot_text: RichTextLabel
var _sell_btn: Button
var _approval_big: Label
var _regrow_btn: Button
var _stats: Label
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
	_build_top_bar(root)
	_build_side_panel(root)
	_build_popup(root)
	Game.changed.connect(refresh)
	refresh()


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.2
		refresh()


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
	bar.position = Vector2(0, 0)
	bar.size = Vector2(PANEL_X, 58)
	bar.add_theme_stylebox_override("panel", _panel_style(Color(0.24, 0.16, 0.10, 0.92)))
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	bar.add_child(hb)
	_money = _mk_label(22, Color(0.55, 1.0, 0.55))
	_money.custom_minimum_size = Vector2(150, 0)
	hb.add_child(_money)
	_approval = _mk_label(16, Color(1.0, 0.85, 0.4))
	_approval.custom_minimum_size = Vector2(170, 0)
	hb.add_child(_approval)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	hb.add_child(vb)
	_mountain_label = _mk_label(14, Color.WHITE)
	vb.add_child(_mountain_label)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 14)
	_progress.show_percentage = false
	vb.add_child(_progress)
	_dyn_label = _mk_label(13, Color(1, 0.6, 0.5))
	_dyn_label.custom_minimum_size = Vector2(150, 0)
	hb.add_child(_dyn_label)


func _build_side_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(PANEL_X, 0)
	panel.size = Vector2(1280 - PANEL_X, 720)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.20, 0.14, 0.10)))
	root.add_child(panel)
	var tabs := TabContainer.new()
	panel.add_child(tabs)

	# Upgrades tab.
	var up := _scroll_tab(tabs, "Upgrades")
	for def in UpgradeDefs.RUN:
		_run_rows[def["id"]] = _upgrade_row(up, def, true)

	# Loot tab.
	var loot := _scroll_tab(tabs, "Loot")
	loot.add_child(_mk_label(18, Color(1, 0.9, 0.6), "Loot bag"))
	_loot_text = RichTextLabel.new()
	_loot_text.bbcode_enabled = true
	_loot_text.fit_content = true
	_loot_text.custom_minimum_size = Vector2(290, 0)
	loot.add_child(_loot_text)
	_sell_btn = Button.new()
	_sell_btn.custom_minimum_size = Vector2(0, 40)
	_sell_btn.pressed.connect(func(): Game.sell_all())
	loot.add_child(_sell_btn)

	# Boss tab (prestige).
	var boss := _scroll_tab(tabs, "Boss")
	_approval_big = _mk_label(18, Color(1, 0.85, 0.4))
	boss.add_child(_approval_big)
	boss.add_child(_wrap_label("Permanent perks. Bought with Boss Approval, kept through every mountain."))
	for def in UpgradeDefs.PERM:
		_perm_rows[def["id"]] = _upgrade_row(boss, def, false)
	boss.add_child(HSeparator.new())
	_regrow_btn = Button.new()
	_regrow_btn.custom_minimum_size = Vector2(0, 40)
	_regrow_btn.pressed.connect(_ask_regrow)
	boss.add_child(_regrow_btn)
	boss.add_child(_wrap_label("Regrowing restarts this mountain for a share of the approval. Clearing it pays in full and moves you on."))
	boss.add_child(HSeparator.new())
	_stats = _wrap_label("")
	boss.add_child(_stats)
	var wipe := Button.new()
	wipe.text = "Wipe save"
	wipe.pressed.connect(_ask_wipe)
	boss.add_child(wipe)


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


func _upgrade_row(parent: VBoxContainer, def: Dictionary, is_run: bool) -> Dictionary:
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
	if is_run:
		btn.pressed.connect(func(): Game.buy_run(id))
	else:
		btn.pressed.connect(func(): Game.buy_perm(id))
	vb.add_child(btn)
	return {"title": title, "button": btn, "def": def}


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
	l.custom_minimum_size = Vector2(280, 0)
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
	_popup_body.custom_minimum_size = Vector2(460, 0)
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
		"You'll restart %s from scratch (run upgrades and cash reset) and get %d Boss Approval for the %d%% you moved." % [
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
	_dyn_label.text = dynamite_status

	for id in _run_rows:
		var row: Dictionary = _run_rows[id]
		var def: Dictionary = row["def"]
		var lvl := Game.run_lvl(id)
		row["title"].text = "%s  (Lv %d)" % [def["name"], lvl]
		var btn: Button = row["button"]
		if Game.is_maxed(def, lvl):
			btn.text = "MAXED"
			btn.disabled = true
		else:
			var price := Game.run_cost(id)
			btn.text = "Buy  $" + Game.fmt(price)
			btn.disabled = Game.money < price

	for id in _perm_rows:
		var row: Dictionary = _perm_rows[id]
		var def: Dictionary = row["def"]
		var lvl := Game.perm_lvl(id)
		row["title"].text = "%s  (Lv %d)" % [def["name"], lvl]
		var btn: Button = row["button"]
		if Game.is_maxed(def, lvl):
			btn.text = "MAXED"
			btn.disabled = true
		else:
			var price := Game.perm_cost(id)
			btn.text = "Buy  %d approval" % price
			btn.disabled = Game.approval < price

	var t := ""
	if Game.auto_sell():
		t += "[color=#9f9]Auto-Seller 3000 is on. Loot turns into cash instantly.[/color]\n\n"
	var any := false
	for m in Materials.ORES:
		var n := int(Game.ores.get(m, 0))
		if n > 0:
			any = true
			var col: Color = Materials.DATA[m]["color"]
			t += "[color=#%s]■[/color] %s x%d  [color=#aaa]($%s ea)[/color]\n" % [col.to_html(false), Materials.DATA[m]["name"], n, Game.fmt(Game.ore_value(m))]
	for it in Game.items:
		any = true
		t += "[color=#e9d][b]★ %s[/b][/color]  $%s\n" % [it["name"], Game.fmt(float(it["value"]))]
	if not any:
		t += "[color=#aaa]Empty. Dig up some ore, fossils or artefacts![/color]"
	_loot_text.text = t
	var lv := Game.loot_value()
	_sell_btn.text = "Sell everything  ($%s)" % Game.fmt(lv)
	_sell_btn.disabled = lv <= 0.0

	_approval_big.text = "Boss Approval: %d" % Game.approval
	_regrow_btn.text = "Regrow mountain  (+%d approval)" % Game.bailout_award(frac)
	_stats.text = "Pixels moved: %s\nClicks: %s\nFinds dug up: %d\nMountains moved: %d\nTotal earned: $%s" % [
		Game.fmt(float(Game.stats["pixels"])), Game.fmt(float(Game.stats["clicks"])),
		int(Game.stats["finds"]), int(Game.stats["mountains"]), Game.fmt(float(Game.stats["earned"]))]
