extends SceneTree
## Headless door-portal + locked-variant test: every door knows its two rooms,
## exactly one hall->room door starts locked with a visible padlock, rattling
## never swings a locked door, and unlocking restores normal swing.

const PASS_S := "TEST_LOCKS_RESULT=PASS"
const FAIL_S := "TEST_LOCKS_RESULT=FAIL"

const SEEDS := [20260831, 7, 12345]
const ROOMS := ["Kitchen", "Bedroom", "Bathroom", "Storage"]


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print(FAIL_S, " ", msg)
	quit(1)


func _run() -> void:
	for s in SEEDS:
		var house := HouseBuilder.new()
		house.seed_value = s
		root.add_child(house)
		await process_frame

		# 1. Portal wiring: each room has exactly one door and it knows both
		# rooms (hall + room) on both sides.
		for room in ROOMS:
			var doors: Array = house.doors_for_room(room)
			if doors.size() != 1:
				_fail("seed %d: room %s has %d doors" % [s, room, doors.size()])
				return
			var d: InteractableDoor = doors[0]
			if d.portal_rooms.size() != 2 or room not in d.portal_rooms \
					or "Hall" not in d.portal_rooms:
				_fail("seed %d: %s portal_rooms=%s" % [s, d.name, str(d.portal_rooms)])
				return

		# 2. Exactly one room is locked by the seed; its door shows a locked
		# padlock and the prompt says so.
		var locked_room: String = house.locked_room()
		if locked_room == "" or locked_room not in ROOMS:
			_fail("seed %d: locked room '%s'" % [s, locked_room])
			return
		var locked_count := 0
		for room in ROOMS:
			if house.door_to(room).is_locked():
				locked_count += 1
		if locked_count != 1:
			_fail("seed %d: %d locked doors" % [s, locked_count])
			return
		var lock_door := house.door_to(locked_room)
		if not lock_door.is_locked() or not lock_door._padlock.visible:
			_fail("seed %d: padlock missing on %s" % [s, locked_room])
			return
		if lock_door.interaction_prompt() != "E — locked":
			_fail("seed %d: locked prompt '%s'" % [s, lock_door.interaction_prompt()])
			return

		# 3. Rattle path: interacting with a locked door must NOT swing it,
		# and must not break the locked state.
		lock_door.interact()
		for i in 40:
			await physics_frame
		if lock_door.is_open():
			_fail("seed %d: locked door swung open" % s)
			return
		if not lock_door.is_locked():
			_fail("seed %d: rattle cleared the lock" % s)
			return

		# 4. Unlock path: after unlock() the same E press swings the door.
		lock_door.unlock()
		if lock_door.is_locked() or lock_door._padlock.visible:
			_fail("seed %d: unlock failed" % s)
			return
		lock_door.interact()
		for i in 60:
			await physics_frame
		if not lock_door.is_open():
			_fail("seed %d: door did not open after unlock" % s)
			return
		lock_door.interact()
		for i in 60:
			await physics_frame
		if lock_door.is_open():
			_fail("seed %d: door did not close" % s)
			return

		# 5. Lock() refuses a swinging leaf but works when closed.
		lock_door.interact()
		lock_door.lock()
		if lock_door.is_locked():
			_fail("seed %d: locked a swinging door" % s)
			return
		lock_door.interact()
		for i in 60:
			await physics_frame
		lock_door.lock()
		if not lock_door.is_locked() or not lock_door._padlock.visible:
			_fail("seed %d: lock() failed on closed door" % s)
			return

		house.queue_free()
		await process_frame
		await process_frame

	print(PASS_S)
	quit(0)