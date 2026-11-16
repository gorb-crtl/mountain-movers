extends Node
## Headless smoke test. Exercises the hand, trucks, interns, military, items,
## saving, and plays through all 7 mountains with cheats. Run:
##   godot --headless --path . res://tests/smoke_test.tscn
## Exit code 0 = pass. NOTE: wipes your local save.

var _fails := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		print("  FAIL ", what)
		_fails += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _ready() -> void:
	Game.wipe()
	Game.intro_done = true
	var main: Node2D = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var m: Mountain = main.mountain
	var depot: TruckDepot = main.depot
	print("Mountain 1: %dx%d, %d pixels" % [m.w, m.h, m.solid])
	check(m.solid > 1000, "mountain generated with lots of pixels")
	await get_tree().process_frame
	check(depot.loading_truck() != null, "a dump truck is parked at the loading spot")

	# Dig into the hand.
	var c := m.random_surface_cell()
	for i in 10:
		main._dig(m.cell_to_world(c))
		c = m.surface_cell_near(m.cell_to_world(c).x, 5)
	check(main.hand.n > 0, "clicking the mountain puts rock in your hand (%d px)" % main.hand.n)
	check(Game.money == 0.0, "digging alone pays nothing")

	# Deposit into the truck.
	main._deposit_hand()
	var tr: Dictionary = depot.loading_truck()
	check(int(tr["n"]) > 0 and main.hand.n == 0, "dropping the hand on the truck loads it")

	# Throw a rock into the bed.
	var before_n := int(tr["n"])
	var bed := depot.bed_rect()
	main.rocks.spawn(3, 3.0, PackedColorArray([Color.GRAY]), bed.get_center() + Vector2(0, -30))
	await wait(0.6)
	check(int(tr["n"]) > before_n, "a rock thrown into the bed gets loaded")

	# Letting go of the mouse never drops what you're holding.
	var c2 := m.random_surface_cell()
	main._dig(m.cell_to_world(c2))
	main._dig(m.cell_to_world(m.surface_cell_near(m.cell_to_world(c2).x, 5)))
	var held: int = main.hand.n
	main._holding = true
	main._drag_px = 500.0
	main._on_left_release()
	check(held > 0 and main.hand.n == held, "left release keeps the load in hand (%d px)" % main.hand.n)
	main._drop_hand(Vector2.ZERO)
	check(main.hand.n == 0, "right-click drop empties the hand")

	# Cave-in: carve a wide tunnel along the ground and the roof should fall.
	var caves := [0]
	m.caved_in.connect(func(hv: Dictionary, _c: Vector2) -> void: caves[0] += int(hv["n"]))
	var mid := m.w / 2
	m.damage_rect(Rect2i(mid - 18, m.h - 6, 36, 6), INF)
	var solid_mid := m.solid
	await wait(0.8)
	check(caves[0] > 50 and m.solid < solid_mid, "undermining the mountain causes a cave-in (%d px fell)" % caves[0])
	check(int(Game.stats.get("caveins", 0)) >= 1, "cave-ins are counted")
	main.rocks.clear_all()

	# Full truck drives off and pays.
	Engine.time_scale = 6.0
	depot.deposit(Game.truck_capacity(), 500.0)
	await wait(1.0)
	check(tr["state"] in ["leaving", "away"], "full truck drives off")
	await wait(Game.truck_trip_time() + 4.0)
	check(Game.money > 0.0, "truck sold its load ($%s)" % Game.fmt(Game.money))
	check(depot.loading_truck() != null, "truck came back to the loading spot")

	# Buy crew, trucks and military.
	Game.add_money(5e6)
	for id in ["intern", "intern", "intern", "intern", "intern", "truck_count", "truck_cap", "soldier", "gunner", "technical", "tank", "bulldozer", "guns"]:
		check(Game.buy_run(id), "buy " + id)
	var solid_before := m.solid
	await wait(3.0)
	check(m.solid < solid_before, "interns and military dig on their own (%d px)" % (solid_before - m.solid))
	check(main.rocks.rocks.size() > 0, "military knocks loose rocks (%d)" % main.rocks.rocks.size())
	check(depot.trucks.size() == 2, "second truck joined the fleet")

	# Fresh mountain for the items (the army may have flattened this one).
	main._on_regrow()
	await get_tree().process_frame
	check(Game.run_lvl("soldier") == 0 and Game.approval >= 0, "regrow resets the army")
	Game.add_money(5e6)

	# Items.
	for id in ["grenade", "bird", "quake", "airstrike", "nuke"]:
		check(Game.buy_item(id), "buy item " + id)
		solid_before = m.solid
		check(Game.use_item(id) and main.abilities.use(id, m.cell_to_world(m.random_surface_cell() + Vector2i(0, 3))), "use " + id)
		await wait(4.0)
		check(m.solid < solid_before, "%s moved some mountain (%d px)" % [id, solid_before - m.solid])
	Engine.time_scale = 1.0

	# Save / load round trip.
	var blob := {"mountain": m.serialize(), "rocks": main.rocks.serialize(), "trucks": depot.serialize()}
	var m2 := Mountain.new()
	check(m2.deserialize(blob["mountain"]) and m2.solid == m.solid, "mountain save/load round trip")
	m2.free()
	var json_ok := JSON.parse_string(JSON.stringify(blob)) != null
	check(json_ok, "world saves as JSON (%d rocks)" % (blob["rocks"] as Array).size())

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
			check(Game.run_lvl("intern") == 0 and main.rocks.rocks.is_empty(), "crew and rocks reset")
	check(Game.won, "beating mountain 7 wins the game")

	Game.approval = 1000
	check(Game.buy_perm("gym"), "buy permanent upgrade")
	check(Game.perm_lvl("gym") == 1, "perm upgrade kept")

	Game.wipe()
	print("FAILURES: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
