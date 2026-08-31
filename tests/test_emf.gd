extends SceneTree
## test_emf.gd — EMF evidence layer test (Vision 6).
## Checks: hotspot strength falloff + level bands, battery drain, HUD meter
## wiring, screen texture updates, seeded deterministic placement in bounds.

func _ready() -> void:
	var failures := 0

	# --- hotspot math: strong near, weak far; level clamps to 1..5
	var emf := EmfReader.new()
	root.add_child(emf)
	emf.set_hotspots([{"pos": Vector3(5, 1, 5), "kind": "cold spot", "room": "Kitchen"}])
	emf.sample(Vector3(5.1, 1, 5.1), 0.016)
	var near := emf.strength
	emf.sample(Vector3(5.1, 1, 4.1), 0.016)
	var near2 := emf.strength
	emf.sample(Vector3(2.0, 1, 2.0), 0.016)
	var far := emf.strength
	if not (near > 0.8 and near2 > 0.5 and far < 0.05):
		print("EMF_TEST_FAIL strength near=%.2f near2=%.2f far=%.2f" % [near, near2, far])
		failures += 1
	for d in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]:
		emf.sample(Vector3(5.0 + d, 1, 5.0), 0.016)
		if emf.level < 1 or emf.level > 5:
			print("EMF_TEST_FAIL level %d out of range at %.1f m" % [emf.level, d])
			failures += 1

	# --- battery drains while on (large fixed dt, far from hotspots)
	var emf2 := EmfReader.new()
	root.add_child(emf2)
	emf2.toggle(true)
	emf2.set_hotspots([])
	var b0 := emf2.battery
	for i in range(30):
		emf2.sample(Vector3(50, 1, 50), 2.0)
	if emf2.battery >= b0:
		print("EMF_TEST_FAIL battery did not drain while on")
		failures += 1

	# --- HUD wiring
	var hud := MatchHUD.new()
	root.add_child(hud)
	await process_frame
	hud.show_emf(true)
	hud.set_emf(0.7, 3)
	if hud.emf_bar.value < 0.69 or hud.emf_bar.value > 0.71:
		print("EMF_TEST_FAIL hud bar value %s" % hud.emf_bar.value)
		failures += 1
	if hud.emf_label.text != "LV 3":
		print("EMF_TEST_FAIL hud label '%s'" % hud.emf_label.text)
		failures += 1

	# --- seeded placement: deterministic, in bounds, away from doorways
	var h1 := HouseBuilder.new()
	h1.seed_value = HOUSE_TEST_SEED
	root.add_child(h1)
	await process_frame
	var h2 := HouseBuilder.new()
	h2.seed_value = HOUSE_TEST_SEED
	root.add_child(h2)
	await process_frame
	var spot1: Array = h1.emf_hotspots
	var spot2: Array = h2.emf_hotspots
	if spot1 != spot2:
		print("EMF_TEST_FAIL hotspot layout not deterministic across builds")
		failures += 1
	if spot1.size() != 5:
		print("EMF_TEST_FAIL expected 5 hotspots (2 locked + 1 rest), got %d" % spot1.size())
		failures += 1
	var bounds_map := {
		"Kitchen": Rect2(0, 0, 3.6, 3.0), "Bedroom": Rect2(3.6, 0, 3.6, 3.0),
		"Bathroom": Rect2(0, 4.7, 3.0, 3.3), "Storage": Rect2(3.0, 4.7, 4.2, 3.3),
	}
	for hs in spot1:
		var b: Rect2 = bounds_map[hs["room"]]
		var p: Vector3 = hs["pos"]
		if not b.has_point(Vector2(p.x, p.z)):
			print("EMF_TEST_FAIL hotspot %s outside %s" % [p, hs["room"]])
			failures += 1
		if hs["room"] == h1.locked_room():
			var door: Node3D = h1.door_to(hs["room"])
			if door != null and Vector2(p.x, p.z).distance_to(Vector2(door.position.x, door.position.z)) < 1.3:
				print("EMF_TEST_FAIL hotspot too close to door in %s" % hs["room"])
				failures += 1

	if failures == 0:
		print("TEST_EMF_RESULT=PASS")
	else:
		print("TEST_EMF_RESULT=FAIL")
	quit(1 if failures > 0 else 0)


const HOUSE_TEST_SEED := 20260831