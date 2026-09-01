class_name BotDriver
extends Node
## Bot v1 (Vision 6): a scripted investigator that reuses the player systems
## through InvestigatorAvatar.drive() — picks an evidence hotspot, walks to
## it (stopping at doorways), "logs" the reading, moves on. No pathfinding:
## rooms connect through the hall, so the bot walks room-center -> hall ->
## door -> room-center, which is exactly how the house is laid out.
## Purely visual + journal-driving for now: bots log evidence like players
## (Vision 6 bots requirement) but never block the local player.

const WALK_SPEED := 2.6
const ARRIVE_M := 0.35
const DWELL_S := 3.2        # seconds "investigating" at a hotspot

var bot_name := "Bot"
var avatar: InvestigatorAvatar
var house: HouseBuilder
var journal: Journal

var _waypoints: Array = []   # Vector3 list to the current hotspot
var _wp_index := 0
var _dwell_left := 0.0
var _logged: Array = []      # hotspots already investigated
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


## Pick a hotspot the bot has not logged yet; plan waypoints through the
## hall spine (z = 3.85) so it never walks through walls.
func _pick_next_hotspot() -> void:
	if house == null:
		return
	var spots: Array = house.emf_hotspots
	var next: Dictionary = {}
	for s in spots:
		if not _logged.has(s):
			next = s
			break
	if next.is_empty():
		_logged.clear()  # cycled everything: start over
		for s in spots:
			if not _logged.has(s):
				next = s
				break
	if next.is_empty():
		return
	var dest: Vector3 = next["pos"]
	# Room of the destination (hotspots carry their room tag).
	var room: String = next.get("room", "")
	var plan: Array = []
	var here := avatar.global_position if avatar != null else Vector3(2.9, 0.0, 3.85)
	var in_hall: bool = here.z > 2.9 and here.z < 4.7
	var dest_hall := _hall_point_for(dest)
	if not in_hall:
		# Step out to the hall first (through our own room, then hall spine).
		plan.append(_hall_point_for(here))
	plan.append(dest_hall)
	if room != "" and dest_hall.distance_to(dest) > 0.8:
		plan.append(dest)  # into the room interior
	_waypoints = plan
	_wp_index = 0
	_dwell_left = 0.0


## Hall spine point nearest to a world position (hall runs along z at 3.85).
func _hall_point_for(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, 0.6, 6.2), 0.0, 3.85)


func _process(delta: float) -> void:
	if avatar == null or not is_instance_valid(avatar) or house == null:
		return
	# Dwell phase: stand at the hotspot and "investigate".
	if _wp_index >= _waypoints.size():
		avatar.drive(0.0)
		_dwell_left -= delta
		if _dwell_left <= 0.0:
			_log_current()
			_pick_next_hotspot()
		return
	# Walk phase: head to the current waypoint.
	var dest: Vector3 = _waypoints[_wp_index]
	var to: Vector3 = dest - avatar.global_position
	to.y = 0.0
	var dist: float = to.length()
	if dist < ARRIVE_M:
		_wp_index += 1
		if _wp_index >= _waypoints.size():
			_dwell_left = DWELL_S
		return
	var step: Vector3 = to.normalized() * WALK_SPEED * delta
	avatar.global_position += step
	# Face the movement direction (avatar forward is -Z).
	avatar.rotation.y = atan2(-to.x, -to.z)
	avatar.drive(WALK_SPEED)


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