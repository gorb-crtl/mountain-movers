extends Node
## Headless smoke test. Plays through all 7 mountains with cheats and checks the
## core loop works. Run:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exit code 0 = pass. NOTE: wipes your local save.

var _fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		_fails += 1


func _ready() -> void:
	Game.wipe()
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var m: Mountain = main.mountain

	print("Mountain 1 size: %dx%d, %d pixels" % [m.w, m.h, m.solid])
	check(m.solid > 1000, "mountain generated with lots of pixels")

	# Grab a pixel near the peak.
	var target := m.random_surface_cell()
	var before := m.solid
	for i in 20:
		m.damage_circle(target, 0.5, Game.click_damage())
	check(m.solid < before, "clicking removes pixels")
	check(Game.money > 0.0, "rubble pays money (%s)" % Game.fmt(Game.money))

	# Buy upgrades with cheat cash.
	Game.add_money(100000)
	check(Game.buy_run("gloves"), "buy gloves")
	check(Game.buy_run("intern"), "buy intern")
	check(Game.buy_run("dynamite"), "buy dynamite")
	check(Game.buy_run("grip"), "buy grip")
	check(Game.click_radius() > 0.5, "grip widens grab")

	# Interns dig on their own.
	for i in 5:
		Game.buy_run("intern")
	before = m.solid
	await get_tree().create_timer(2.0).timeout
	check(m.solid < before, "interns dig while idle")

	# Dynamite.
	before = m.solid
	main._explode(m.cell_to_world(m.random_surface_cell() + Vector2i(0, 4)))
	check(m.solid < before - 10, "dynamite blows a hole (%d px)" % (before - m.solid))

	# Ores go to loot bag, selling pays.
	Game.ores[Materials.GOLD] = 3
	var cash := Game.money
	Game.sell_all()
	check(Game.money > cash and Game.ores.is_empty(), "selling loot pays out")

	# Save / load round trip of the mountain.
	var blob := m.serialize()
	var solid_before := m.solid
	var m2 := Mountain.new()
	check(m2.deserialize(blob) and m2.solid == solid_before, "mountain save/load round trip")
	m2.free()

	# Play through every mountain.
	for lvl in Game.MOUNTAIN_COUNT:
		var size := Vector2i(m.w, m.h)
		m.force_clear()
		await get_tree().process_frame
		check(main.hud.is_popup_open(), "mountain %d cleared -> popup (%dx%d)" % [lvl + 1, size.x, size.y])
		var approval := Game.approval
		main._advance()
		check(Game.approval > approval, "approval granted (now %d)" % Game.approval)
		await get_tree().process_frame
		if lvl < Game.MOUNTAIN_COUNT - 1:
			check(Game.level == lvl + 1 and m.w > size.x, "next mountain is bigger")
			check(Game.run_lvl("gloves") == 0, "run upgrades reset")
	check(Game.won, "beating mountain 7 wins the game")

	# Permanent upgrades.
	Game.approval = 1000
	check(Game.buy_perm("gym"), "buy permanent upgrade")
	check(Game.perm_lvl("gym") == 1, "perm upgrade kept")

	Game.wipe()
	print("FAILURES: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
