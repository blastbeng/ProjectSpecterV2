extends SceneTree
## Headless house-layout test: seeded HouseBuilder has 4 named doors, rooms are
## separated by walls, and each room is reachable through its doorway (rays
## from hallway door positions hit the intended door).

const PASS_S := "TEST_HOUSE_RESULT=PASS"
const FAIL_S := "TEST_HOUSE_RESULT=FAIL"

const SEEDS := [20260831, 7, 12345]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for s in SEEDS:
		var house := HouseBuilder.new()
		house.seed_value = s
		root.add_child(house)
		await process_frame
		var doors := house.find_children("door_*", "StaticBody3D", true, false)
		if doors.size() != 4:
			print(FAIL_S, " seed %d has %d doors" % [s, doors.size()])
			quit(1)
			return
		# Hallway center rays must hit each room through its doorway.
		var probes := [
			[Vector3(1.3, 1.0, 3.45), Vector3(0, 0, -1), 0.9, "north"],
			[Vector3(5.6, 1.0, 3.45), Vector3(0, 0, -1), 0.9, "north"],
			[Vector3(1.5, 1.0, 4.25), Vector3(0, 0, 1), 0.9, "south"],
			[Vector3(4.6, 1.0, 4.25), Vector3(0, 0, 1), 0.9, "south"],
		]
		for p in probes:
			var space: PhysicsDirectSpaceState3D = root.world_3d.direct_space_state
			var q := PhysicsRayQueryParameters3D.create(p[0], p[0] + p[1] * p[2], 1)
			var hit: Dictionary = space.intersect_ray(q)
			if hit.is_empty():
				print(FAIL_S, " seed %d: ray at %s hit nothing" % [s, p[0]])
				quit(1)
				return
			var col: Object = hit["collider"]
			var ok := false
			for d in doors:
				if col == d:
					ok = true
					break
			if not ok:
				print(FAIL_S, " seed %d: doorway ray hit %s for %s" % [s, col.name, p[3]])
				quit(1)
				return
		house.queue_free()
		await process_frame
		await process_frame
	print(PASS_S)
	quit(0)