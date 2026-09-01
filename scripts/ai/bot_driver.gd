class_name BotDriver
extends Node
## Bot v2 (Vision 6): a scripted investigator that reuses the player systems
## through InvestigatorAvatar.drive() — picks an evidence hotspot, walks to
## it THROUGH the real doorway (threshold point from door.position), opening
## shut doors on the way and skipping padlocked rooms until they unlock.
## No pathfinding library: rooms connect through the hall, so the plan is
## room-center -> own doorway -> hall spine -> destination doorway ->
## room-center, which is exactly how the house is laid out. Reacts to entity
## activity by fleeing to the far hall end from the disturbance. Purely
## visual + journal-driving for now: bots log evidence like players but
## never block the local player.

const WALK_SPEED := 2.6
const FLEE_SPEED := 3.4
const ARRIVE_M := 0.35
const DWELL_S := 3.2        # seconds "investigating" at a hotspot
const DOOR_USE_M := 0.55    # start opening a door this close
const FLEE_HEAR_M := 9.0    # entity activity closer than this scares the bot
const HALL_Z := 3.85
const HALL_X_MIN := 0.6
const HALL_X_MAX := 6.2
## Rooms north of the band wall (their doorway z is the room's south edge).
const NORTH_ROOMS := ["Kitchen", "Bedroom"]

var bot_name := "Bot"
var avatar: InvestigatorAvatar
var house: HouseBuilder
var journal: Journal

var _waypoints: Array = []   # [{pos: Vector3, door: InteractableDoor|null}]
var _wp_index := 0
var _dwell_left := 0.0
var _logged: Array = []      # hotspots already investigated
var _flee_left := 0.0        # > 0 while spooked by entity activity
var _rng := RandomNumberGenerator.new()


func setup(avatar_ref: InvestigatorAvatar, house_ref: HouseBuilder, journal_ref: Journal,
		display_name: String) -> void:
	avatar = avatar_ref
	house = house_ref
	journal = journal_ref
	bot_name = display_name
	avatar.display_name = display_name
	_rng.seed = hash(bot_name) + 77
	_pick_next_hotspot()


func is_investigating() -> bool:
	return avatar != null and is_instance_valid(avatar)


func logged_count() -> int:
	return _logged.size()


func is_fleeing() -> bool:
	return _flee_left > 0.0


## Entity activity reaction (Vision 6 bots): a manifested power close by
## sends the bot hurrying along the hall spine to the far end from the
## event, where it waits out the scare before resuming its route.
func on_entity_activity(at: Vector3) -> void:
	if avatar == null or not is_instance_valid(avatar) or house == null:
		return
	if avatar.global_position.distance_to(at) > FLEE_HEAR_M:
		return
	var mid := (HALL_X_MIN + HALL_X_MAX) * 0.5
	var far_x := HALL_X_MIN + 0.5 if at.x > mid else HALL_X_MAX - 0.5
	_flee_left = 2.6
	_waypoints = [{"pos": _hall_point_for(Vector3(far_x, 0.0, HALL_Z)), "door": null}]
	_wp_index = 0
	_dwell_left = 0.0


## Pick a hotspot the bot has not logged yet; plan waypoints THROUGH the
## doorway of every room on the route (never across room edges). Hotspots
## behind a currently locked (padlocked) door are skipped until unlocked.
func _pick_next_hotspot() -> void:
	if house == null:
		return
	var spots: Array = house.emf_hotspots
	var next: Dictionary = {}
	for s in spots:
		if not _logged.has(s) and not _room_locked(String(s.get("room", ""))):
			next = s
			break
	if next.is_empty():
		_logged.clear()  # cycled everything: start over
		for s in spots:
			if not _logged.has(s) and not _room_locked(String(s.get("room", ""))):
				next = s
				break
	if next.is_empty():
		return  # everything locked: stand by until a door unlocks
	var dest: Vector3 = next["pos"]
	var room: String = next.get("room", "")
	var here := avatar.global_position if avatar != null else Vector3(2.9, 0.0, HALL_Z)
	var cur_room := _room_of(here)
	var dest_hall := _hall_point_for(dest)
	var plan: Array = []
	if room != "" and cur_room == room:
		plan.append({"pos": dest, "door": null})  # same room: walk straight
	else:
		if cur_room != "":
			plan.append(_doorway_wp(cur_room))
		if room != "" and dest_hall.distance_to(dest) > 0.8:
			plan.append({"pos": dest_hall, "door": null})
			plan.append(_doorway_wp(room))
		plan.append({"pos": dest, "door": null})
	_waypoints = plan
	_wp_index = 0
	_dwell_left = 0.0


func _room_locked(room: String) -> bool:
	if room == "" or house == null:
		return false
	var door := house.door_to(room)
	return door != null and door.is_locked()


## Doorway waypoint of a room: the threshold point on its doorway line, on
## the room's side, so the approach leg comes through the actual opening.
func _doorway_wp(room: String) -> Dictionary:
	var door := house.door_to(room)
	if door == null or not door.has_meta("center_x"):
		var center: Vector2 = house._room_bounds(room).get_center()
		return {"pos": _hall_point_for(Vector3(center.x, 0.0, center.y)), "door": null}
	var cx := float(door.get_meta("center_x"))
	var north_side: bool = room in NORTH_ROOMS  # north rooms sit at z < doorway z
	var z := door.position.z - 0.30 if north_side else door.position.z + 0.30
	return {"pos": Vector3(cx, 0.0, z), "door": door}


## Which named room (or "Hall") a point is in, from layout constants.
func _room_of(p: Vector3) -> String:
	if p.z >= house.HALL_N and p.z <= house.HALL_S:
		return "Hall"
	if p.z < house.HALL_N:
		return "Kitchen" if p.x <= 3.6 else "Bedroom"
	return "Bathroom" if p.x <= 3.0 else "Storage"


## Hall spine point nearest to a world position (hall runs along z at HALL_Z).
func _hall_point_for(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, HALL_X_MIN, HALL_X_MAX), 0.0, HALL_Z)


func _process(delta: float) -> void:
	if avatar == null or not is_instance_valid(avatar) or house == null:
		return
	# Dwell phase: stand at the hotspot and "investigate" (or wait out a scare).
	if _wp_index >= _waypoints.size():
		avatar.drive(0.0)
		if _flee_left > 0.0:
			_flee_left -= delta
			if _flee_left <= 0.0:
				_pick_next_hotspot()
			return
		_dwell_left -= delta
		if _dwell_left <= 0.0:
			_log_current()
			_pick_next_hotspot()
		return
	# Walk phase: head to the current waypoint.
	var wp: Dictionary = _waypoints[_wp_index]
	var dest: Vector3 = wp["pos"]
	var to: Vector3 = dest - avatar.global_position
	to.y = 0.0
	var dist: float = to.length()
	if dist < ARRIVE_M:
		_wp_index += 1
		if _wp_index >= _waypoints.size():
			_dwell_left = DWELL_S if _flee_left <= 0.0 else 0.5
		return
	# Door usage: open the doorway door when close (bot "presses E"). Locked
	# doors are never touched — the route planner skips padlocked rooms.
	var door: InteractableDoor = wp.get("door")
	if door != null and is_instance_valid(door) and not door.is_open() \
			and not door.is_locked() and dist < DOOR_USE_M:
		door.interact()
	var speed := FLEE_SPEED if _flee_left > 0.0 else WALK_SPEED
	var step: Vector3 = to.normalized() * speed * delta
	avatar.global_position += step
	# Face the movement direction (avatar forward is -Z).
	avatar.rotation.y = atan2(-to.x, -to.z)
	avatar.drive(speed)


## Log the hotspot we just investigated, like a player pressing F on it.
func _log_current() -> void:
	if journal == null:
		return
	var here := avatar.global_position
	var best: Dictionary = {}
	var best_d := 2.2
	for s in house.emf_hotspots:
		var d: float = (s["pos"] as Vector3).distance_to(here)
		if d < best_d:
			best_d = d
			best = s
	if best.is_empty():
		return
	_logged.append(best)
	journal.bot_captured(String(best["kind"]), String(best["room"]))