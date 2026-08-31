class_name HouseBuilder
extends Node3D
## Seeded procedural building (Vision 5.4/5.5/5.6): hallway spine with four
## rooms branching off it — kitchen (north-west), bedroom (north-east),
## bathroom (south-west), storage (south-east). Deterministic from seed.
## Real-world scale, every surface materialized, everything on the floor.

const CEIL_H := 2.8
const WT := 0.10  # wall thickness
const DOOR_W := 0.95
const DOOR_H := 2.05

# Building bounds (interior).
const B_W := 7.2    # x 0 .. 7.2
const B_D := 8.0    # z 0 .. 8.0
# Band walls: kitchen/bedroom live z 0..3.0, hall z 3.0..4.7, south rooms z 4.7..B_D.
const HALL_N := 3.0
const HALL_S := 4.7
# Interior partition x positions: north rooms split at 3.6, south at 3.0.

var seed_value := 12345
var _rng: RandomNumberGenerator
var _flicker_lamp: OmniLight3D
var _flicker_t := 0.0
var _flicker_noise: FastNoiseLite


func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	return mi


func _place(node: Node3D, pos: Vector3) -> void:
	add_child(node)
	node.position = pos


func _solid(size: Vector3, mat: Material, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_child(_box(size, mat))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	_place(body, pos)
	return body


# ---------- helpers: runs along X with doorway gaps ----------

## Returns [[start, end], ...] free segments (no doorway) of x0..x1.
func _free_runs(x0: float, x1: float, doors: Array) -> Array:
	var cuts: Array = []
	for d in doors:
		cuts.append(Vector2(d - DOOR_W / 2.0, d + DOOR_W / 2.0))
	cuts.sort_custom(func(a, b): return a.x < b.x)
	var runs: Array = []
	var cur := x0
	for c in cuts:
		if c.x > cur + 0.01:
			runs.append(Vector2(cur, c.x))
		cur = maxf(cur, c.y)
	if x1 > cur + 0.01:
		runs.append(Vector2(cur, x1))
	return runs


## Wall along X at z, full height, with doorways cut and lintels above doors.
func _wall_x_run(z: float, x0: float, x1: float, doors: Array, mat: Material) -> void:
	for r in _free_runs(x0, x1, doors):
		var w: float = r.y - r.x
		_solid(Vector3(w, CEIL_H, WT), mat, Vector3(r.x + w / 2.0, CEIL_H / 2.0, z))
	for d in doors:
		_solid(Vector3(DOOR_W + 0.02, CEIL_H - DOOR_H, WT), mat, Vector3(d, DOOR_H + (CEIL_H - DOOR_H) / 2.0, z))


## Wall along Z at x between z0..z1 (solid, no doors).
func _wall_z_run(x: float, z0: float, z1: float, mat: Material) -> void:
	var d := z1 - z0
	_solid(Vector3(WT, CEIL_H, d), mat, Vector3(x, CEIL_H / 2.0, z0 + d / 2.0))


## Baseboard along X at z, split around doorways, thin trim box.
func _baseboard_x_run(z: float, x0: float, x1: float, doors: Array) -> void:
	for r in _free_runs(x0, x1, doors):
		var w: float = r.y - r.x
		_place(_box(Vector3(w - 0.02, 0.12, 0.03), MaterialFactory.trim()), Vector3(r.x + w / 2.0, 0.06, z))


## Door assembly in an X-run doorway. face 0: hinge at west jamb, swings -z.
func _door_x(door_center_x: float, z: float, face_deg: float, door_name: String) -> void:
	var door := InteractableDoor.new(DOOR_W, DOOR_H, face_deg)
	door.name = door_name
	# face 0 -> leaf spans +x from hinge; place hinge at opening's left edge.
	# face 180 -> local +x maps to world -x; hinge at opening's right edge.
	var hx := door_center_x - DOOR_W / 2.0 if absf(face_deg) < 90.0 else door_center_x + DOOR_W / 2.0
	door.position = Vector3(hx, 0.0, z)
	add_child(door)


# ---------- shell ----------

func _build_shell() -> void:
	var wall := MaterialFactory.wall()
	var stained := MaterialFactory.wall_stained()
	# Floors per region (slab tops at y=0). Kitchen/bedroom/hall wood, south rooms split.
	_solid(Vector3(B_W, 0.1, HALL_N), MaterialFactory.floor_wood(), Vector3(B_W / 2.0, -0.05, HALL_N / 2.0))
	_solid(Vector3(B_W, 0.1, HALL_S - HALL_N), MaterialFactory.floor_wood(), Vector3(B_W / 2.0, -0.05, (HALL_N + HALL_S) / 2.0))
	_solid(Vector3(3.0, 0.1, B_D - HALL_S), MaterialFactory.grime(Color("8f8f8a"), 0.5, 0.09), Vector3(1.5, -0.05, (HALL_S + B_D) / 2.0))  # bathroom floor, pale
	_solid(Vector3(B_W - 3.0, 0.1, B_D - HALL_S), MaterialFactory.concrete_floor(), Vector3((3.0 + B_W) / 2.0, -0.05, (HALL_S + B_D) / 2.0))  # storage floor
	# One ceiling slab over everything (decor).
	_place(_box(Vector3(B_W, 0.1, B_D), MaterialFactory.ceiling()), Vector3(B_W / 2.0, CEIL_H + 0.05, B_D / 2.0))
	# Exterior walls (interior faces at x=0/7.2, z=0/8.0).
	_wall_z_run(-WT / 2.0, 0.0, B_D, wall)                                  # west
	_wall_z_run(B_W + WT / 2.0, 0.0, B_D, stained)                          # east
	_solid(Vector3(B_W + 2 * WT, CEIL_H, WT), wall, Vector3(B_W / 2.0, CEIL_H / 2.0, -WT / 2.0))   # north
	_solid(Vector3(B_W + 2 * WT, CEIL_H, WT), wall, Vector3(B_W / 2.0, CEIL_H / 2.0, B_D + WT / 2.0))  # south
	# Interior band walls with doorways.
	var north_doors := [1.3, 5.6]            # kitchen / bedroom doorways in z=HALL_N wall
	var south_doors := [1.5, 4.6]            # bathroom / storage doorways in z=HALL_S wall
	_wall_x_run(HALL_N, WT, B_W - WT, north_doors, wall)
	_wall_x_run(HALL_S, WT, B_W - WT, south_doors, wall)
	# Partitions between room pairs.
	_wall_z_run(3.6, 0.0, HALL_N, wall)      # kitchen | bedroom
	_wall_z_run(3.0, HALL_S, B_D, wall)      # bathroom | storage
	# Doors (kitchen/bedroom swing north into rooms; south pair swings south).
	_door_x(1.3, HALL_N, 0.0, "door_kitchen")
	_door_x(5.6, HALL_N, 0.0, "door_bedroom")
	_door_x(1.5, HALL_S, 180.0, "door_bathroom")
	_door_x(4.6, HALL_S, 180.0, "door_storage")
	# Baseboards: hall faces of both band walls + exterior faces of each room.
	_baseboard_x_run(HALL_N + 0.08, WT, B_W - WT, north_doors)
	_baseboard_x_run(HALL_S - 0.08, WT, B_W - WT, south_doors)
	_baseboard_x_run(-0.08, WT, B_W - WT, [])          # inside north rooms, north wall
	_baseboard_x_run(B_D + 0.08, WT, B_W - WT, [])     # inside south rooms, south wall
	_baseboard_x_run(HALL_N - 0.08, WT, B_W - WT, north_doors)  # room side of band wall
	_baseboard_x_run(HALL_S + 0.08, WT, B_W - WT, south_doors)
	# Vertical-ish baseboards on side walls (thin strips along Z).
	for zz in [1.2, 6.2]:
		var inset := 0.08
		_place(_box(Vector3(0.03, 0.12, 1.0), MaterialFactory.trim()), Vector3(inset, 0.06, zz))
		_place(_box(Vector3(0.03, 0.12, 1.0), MaterialFactory.trim()), Vector3(B_W - inset, 0.06, zz))


# ---------- kitchen (NW: x 0..3.6, z 0..3.0) ----------

func _build_kitchen() -> void:
	var top_mat := MaterialFactory.grime(Color("6d6a63"), 0.6, 0.06)
	var basin_mat := MaterialFactory.grime(Color("2e3236"), 0.35, 0.1)
	var wood := MaterialFactory.wood_dark()
	# Lower run + top on the north wall, left of fridge.
	_solid(Vector3(2.4, 0.9, 0.62), wood, Vector3(1.6, 0.45, 0.34))
	_solid(Vector3(2.6, 0.05, 0.68), top_mat, Vector3(1.6, 0.925, 0.34))
	# Sink basin + faucet.
	_place(_box(Vector3(0.42, 0.05, 0.34), basin_mat), Vector3(1.9, 0.95, 0.34))
	var faucet := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.012
	fm.bottom_radius = 0.016
	fm.height = 0.26
	faucet.mesh = fm
	faucet.material_override = MaterialFactory.metal()
	_place(faucet, Vector3(2.12, 1.05, 0.34))
	faucet.rotation_degrees = Vector3(0, 0, 10)
	# Upper cabinets + panels + knobs.
	_solid(Vector3(2.0, 0.7, 0.34), wood, Vector3(1.7, 1.95, 0.17))
	for i in range(2):
		var panel := _box(Vector3(0.78, 0.66, 0.02), wood)
		_place(panel, Vector3(1.0 + 0.9 * i, 0.45, 0.665))
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.02
		km.height = 0.04
		knob.mesh = km
		knob.material_override = MaterialFactory.metal()
		_place(knob, Vector3(1.0 + 0.9 * i + 0.32, 0.45, 0.685))
	# Fridge at the north-east corner of the room (against z=0 wall).
	_solid(Vector3(0.75, 1.85, 0.72), MaterialFactory.metal(), Vector3(3.1, 0.925, 0.45))
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.015
	hm.bottom_radius = 0.015
	hm.height = 0.5
	handle.mesh = hm
	handle.material_override = MaterialFactory.metal_dark()
	_place(handle, Vector3(2.75, 1.15, 0.81))
	handle.rotation_degrees = Vector3(0, 0, 90)
	# Table + two chairs (door swing tip stays clear).
	_solid(Vector3(1.1, 0.05, 0.8), wood, Vector3(1.9, 0.725, 2.1))
	for cx in [1.42, 2.38]:
		for cz in [1.77, 2.43]:
			_place(_box(Vector3(0.06, 0.70, 0.06), wood), Vector3(cx, 0.35, cz))
	for cx in [1.15, 2.65]:
		var seat := MaterialFactory.grime(Color("5a4632"), 0.8, 0.09)
		_solid(Vector3(0.42, 0.05, 0.42), seat, Vector3(cx, 0.45, 2.1))
		var back := _box(Vector3(0.05, 0.5, 0.42), seat)
		_place(back, Vector3(cx - 0.19 if cx < 1.9 else cx + 0.19, 0.72, 2.1))
	# Pendant lamp over the table + softer fill near the run.
	_pendant(Vector3(1.9, 0, 2.1), 2.6, 12.0, true)
	var fill := OmniLight3D.new()
	fill.light_color = MaterialFactory.LAMP_LIGHT.lerp(Color.WHITE, 0.25)
	fill.light_energy = 1.0
	fill.omni_range = 6.0
	place_light(fill, Vector3(1.6, 2.35, 0.6))
	# Window on the west wall, over the counter end.
	_window_x(0.0, 1.5, MaterialFactory.trim())
	# Dust motes near the lamp.
	_dust(Vector3(1.9, 1.6, 2.1))


# ---------- bedroom (NE: x 3.6..7.2, z 0..3.0) ----------

func _build_bedroom() -> void:
	var wood := MaterialFactory.wood_dark()
	# Bed (2.0 long along z) + frame + headboard against north wall.
	_solid(Vector3(1.5, 0.25, 2.05), wood, Vector3(5.65, 0.125, 1.2))
	_solid(Vector3(1.4, 0.30, 1.95), MaterialFactory.grime(Color("75726c"), 0.85, 0.1), Vector3(5.65, 0.40, 1.22))  # mattress
	_solid(Vector3(1.5, 0.9, 0.08), wood, Vector3(5.65, 0.5, 0.14))  # headboard
	_place(_box(Vector3(0.5, 0.12, 0.35), MaterialFactory.grime(Color("a8a49a"), 0.9, 0.12)), Vector3(5.65, 0.61, 0.45))  # pillow
	# Blanket strip over the foot of the bed.
	_place(_box(Vector3(1.44, 0.06, 0.9), MaterialFactory.grime(Color("54503f"), 0.95, 0.1)), Vector3(5.65, 0.58, 1.85))
	# Wardrobe against the east wall.
	_solid(Vector3(0.6, 2.0, 1.2), wood, Vector3(6.9, 1.0, 1.0))
	# Wardrobe door seams + knobs.
	for zz in [0.7, 1.3]:
		_place(_box(Vector3(0.02, 1.8, 0.02), MaterialFactory.trim()), Vector3(6.59, 1.0, zz))
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.02
		km.height = 0.04
		knob.mesh = km
		knob.material_override = MaterialFactory.metal()
		_place(knob, Vector3(6.56, 1.0, zz))
	# Nightstand + lamp (emissive shade, no extra light).
	_solid(Vector3(0.45, 0.55, 0.45), wood, Vector3(4.6, 0.275, 0.6))
	var shade := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = 0.11
	sm.height = 0.14
	shade.mesh = sm
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color("e8d9b0")
	lamp_mat.emission_enabled = true
	lamp_mat.emission = MaterialFactory.LAMP_LIGHT
	lamp_mat.emission_energy_multiplier = 2.2
	shade.material_override = lamp_mat
	_place(shade, Vector3(4.6, 0.66, 0.6))
	# Rug on the floor south of the bed, decor only.
	var rug := _box(Vector3(1.7, 0.015, 1.1), MaterialFactory.grime(Color("5c3030"), 0.98, 0.14))
	_place(rug, Vector3(5.3, 0.008, 2.5))
	# Window on the east wall and a picture on the partition.
	_window_z(B_W, 2.3, MaterialFactory.trim())
	_picture(Vector3(3.655, 1.6, 1.8), 90.0, seed_value * 13 + 3)
	# Ceiling flush light.
	_flush_light(Vector3(5.4, CEIL_H, 1.6), 2.2, 9.0, true)


# ---------- bathroom (SW: x 0..3.0, z 4.7..8.0) ----------

func _build_bathroom() -> void:
	var tile := MaterialFactory.grime(Color("9aa8a2"), 0.45, 0.16)
	var porcelain := MaterialFactory.grime(Color("c9ccc8"), 0.25, 0.03)
	var metal := MaterialFactory.metal()
	# Tub along the west wall (door swing tip clears it).
	_solid(Vector3(0.75, 0.55, 1.6), porcelain, Vector3(0.45, 0.275, 6.85))
	_place(_box(Vector3(0.55, 0.06, 1.4), MaterialFactory.grime(Color("1d2b30"), 0.2, 0.05)), Vector3(0.45, 0.50, 6.85))  # dark water inset
	var faucet := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.012
	fm.bottom_radius = 0.016
	fm.height = 0.22
	faucet.mesh = fm
	faucet.material_override = metal
	_place(faucet, Vector3(0.9, 0.6, 7.55))
	# Toilet against the south wall.
	_solid(Vector3(0.42, 0.42, 0.2), porcelain, Vector3(1.0, 0.21, 7.75))  # tank
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.19
	bm.bottom_radius = 0.14
	bm.height = 0.4
	bowl.mesh = bm
	bowl.material_override = porcelain
	_place(bowl, Vector3(1.0, 0.2, 7.35))
	# Pedestal sink + mirror on the east partition.
	var ped := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.14
	pm.bottom_radius = 0.09
	pm.height = 0.8
	ped.mesh = pm
	ped.material_override = porcelain
	_place(ped, Vector3(2.72, 0.4, 5.5))
	_place(_box(Vector3(0.5, 0.12, 0.4), porcelain), Vector3(2.72, 0.86, 5.5))
	var mirror := MeshInstance3D.new()
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color("aeb8ba")
	mm.metallic = 0.9
	mm.roughness = 0.1
	mirror.mesh = BoxMesh.new()
	(mirror.mesh as BoxMesh).size = Vector3(0.02, 0.6, 0.44)
	mirror.material_override = mm
	_place(mirror, Vector3(2.98, 1.7, 5.5))
	# Towel bar + towel on the north wall.
	_place(_box(Vector3(0.5, 0.03, 0.03), metal), Vector3(2.4, 1.2, 4.78))
	_place(_box(Vector3(0.4, 0.5, 0.03), MaterialFactory.grime(Color("7a8280"), 0.95, 0.12)), Vector3(2.4, 0.92, 4.82))
	# Dim cool light; bathroom reads colder than the rest.
	var light := OmniLight3D.new()
	light.light_color = Color("cfe0dd")
	light.light_energy = 1.2
	light.omni_range = 6.5
	place_light(light, Vector3(1.5, 2.4, 6.3))
	# Tiled picture frame on the west wall for a bit of wear.
	_picture(Vector3(0.06, 1.7, 5.3), 90.0, seed_value * 7 + 41)
	# Flush light fixture mesh above the bulb.
	_place(_box(Vector3(0.3, 0.05, 0.3), metal), Vector3(1.5, CEIL_H - 0.035, 6.3))


# ---------- storage (SE: x 3.0..7.2, z 4.7..8.0) ----------

func _build_storage() -> void:
	var steel := MaterialFactory.metal()
	var steel_dark := MaterialFactory.metal_dark()
	var wood := MaterialFactory.wood_dark()
	# Two shelf units along the south wall.
	for ux in [4.2, 6.2]:
		for sz in [7.2, 7.9]:
			_place(_box(Vector3(0.05, 2.0, 0.05), steel_dark), Vector3(ux, 1.0, sz))
		for by in [0.5, 1.0, 1.5]:
			_solid(Vector3(1.6, 0.04, 0.55), steel, Vector3(ux, by, 7.55))
		# Crates on the shelves and floor (seeded jitter).
		_crate(Vector3(ux - 0.4, 0.27, 7.55), 0.42, 0.5)
		_crate(Vector3(ux + 0.4, 1.27, 7.55), 0.36, 0.42, seed_value + int(ux))
	_crate(Vector3(3.6, 0.31, 7.6), 0.5, 0.58)
	_crate(Vector3(4.4, 0.26, 6.6), 0.42, 0.48, seed_value + 9)
	_crate(Vector3(5.9, 0.31, 6.2), 0.34, 0.58, seed_value + 3)
	_crate(Vector3(6.6, 0.28, 5.6), 0.38, 0.52, seed_value + 55, 35.0)
	# Barrel.
	var barrel := MeshInstance3D.new()
	var bcm := CylinderMesh.new()
	bcm.top_radius = 0.3
	bcm.bottom_radius = 0.3
	bcm.height = 0.9
	barrel.mesh = bcm
	barrel.material_override = MaterialFactory.grime(Color("54604f"), 0.7, 0.08)
	var bbody := StaticBody3D.new()
	bbody.add_child(barrel)
	var cs := CollisionShape3D.new()
	var bshape := CylinderShape3D.new()
	bshape.radius = 0.3
	bshape.height = 0.9
	cs.shape = bshape
	bbody.add_child(cs)
	_place(bbody, Vector3(3.7, 0.45, 5.4))
	# Bare hanging bulb — dimmer, moodier.
	var cord := _box(Vector3(0.02, 0.5, 0.02), steel_dark)
	_place(cord, Vector3(5.4, CEIL_H - 0.25, 6.2))
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.05
	bulb_mesh.height = 0.1
	bulb.mesh = bulb_mesh
	bulb.material_override = MaterialFactory.bulb()
	_place(bulb, Vector3(5.4, CEIL_H - 0.3, 6.2))
	var light := OmniLight3D.new()
	light.light_color = MaterialFactory.LAMP_LIGHT
	light.light_energy = 1.4
	light.omni_range = 7.0
	place_light(light, Vector3(5.4, CEIL_H - 0.42, 6.2))
	# Picture leaning against the west partition, plus wall stain patch.
	_picture(Vector3(3.06, 1.0, 6.8), 90.0, seed_value * 23 + 5, 0.4, 0.5)


# ---------- hallway (z 3.0..4.7) ----------

func _build_hall() -> void:
	# Three pendant lamps, one flickers (seed-gated, deterministic).
	for lx in [1.5, 3.6, 5.7]:
		_pendant(Vector3(lx, 0, 3.85), 1.8, 7.0, lx == 3.6)
	if (seed_value % 3) == 0:
		_flicker_lamp = get_node_or_null("HallFlickerLight") as OmniLight3D
	# Pictures on hall-facing sides of the band walls and west wall.
	_picture(Vector3(2.6, 1.62, HALL_N + 0.055), 0.0, seed_value * 5 + 1)
	_picture(Vector3(3.4, 1.62, HALL_S - 0.055), 180.0, seed_value * 11 + 2)
	_picture(Vector3(0.06, 1.55, 4.2), 90.0, seed_value * 17 + 4)


# ---------- shared fixture builders ----------

func _pendant(pos: Vector3, energy: float, range_m: float, shadow: bool) -> void:
	_place(_box(Vector3(0.02, 0.38, 0.02), MaterialFactory.metal_dark()), Vector3(pos.x, CEIL_H - 0.19, pos.z))
	var shade := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.04
	sm.bottom_radius = 0.24
	sm.height = 0.18
	shade.mesh = sm
	shade.material_override = MaterialFactory.metal_dark()
	_place(shade, Vector3(pos.x, CEIL_H - 0.43, pos.z))
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.035
	bm.height = 0.07
	bulb.mesh = bm
	bulb.material_override = MaterialFactory.bulb()
	_place(bulb, Vector3(pos.x, CEIL_H - 0.5, pos.z))
	var light := OmniLight3D.new()
	light.light_color = MaterialFactory.LAMP_LIGHT
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadow
	light.shadow_blur = 1.4
	var light_name := "HallFlickerLight" if pos.x == 3.6 and pos.z == 3.85 else ""
	if light_name != "":
		light.name = light_name
	place_light(light, Vector3(pos.x, CEIL_H - 0.62, pos.z))


func _flush_light(pos: Vector3, energy: float, range_m: float, shadow: bool) -> void:
	_place(_box(Vector3(0.26, 0.05, 0.26), MaterialFactory.metal()), Vector3(pos.x, CEIL_H - 0.035, pos.z))
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.04
	bm.height = 0.06
	bulb.mesh = bm
	bulb.material_override = MaterialFactory.bulb()
	_place(bulb, Vector3(pos.x, CEIL_H - 0.09, pos.z))
	var light := OmniLight3D.new()
	light.light_color = MaterialFactory.LAMP_LIGHT
	light.light_energy = energy
	light.omni_range = range_m
	light.shadow_enabled = shadow
	light.shadow_blur = 1.4
	place_light(light, Vector3(pos.x, CEIL_H - 0.2, pos.z))


func place_light(light: Light3D, pos: Vector3) -> void:
	add_child(light)
	light.position = pos


func _dust(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.7, 0.3, 0.7)
	pm.gravity = Vector3(0, 0.01, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	var dm := SphereMesh.new()
	dm.radius = 0.006
	dm.height = 0.012
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.75, 0.72, 0.62)
	dmat.roughness = 1.0
	dm.material = dmat
	p.draw_pass_1 = dm
	p.amount = 20
	p.lifetime = 7.0
	p.randomness = 1.0
	_place(p, pos)


## Parameterized window: wall face along X at z (x_wall == 0.0) or along Z at
## x (z_wall == B_W). window_center is (x_or_z_center, y_center).
func _window_x(z_face: float, center_x: float, frame_mat: Material) -> void:
	var cy := 1.65
	for o in [-0.60, 0.60]:
		_place(_box(Vector3(0.08, 1.3, 0.07), frame_mat), Vector3(center_x + o, cy, z_face + 0.035))
	for o in [-0.61, 0.61]:
		_place(_box(Vector3(1.28, 0.08, 0.07), frame_mat), Vector3(center_x + o, cy, z_face + 0.035))
	_place(_box(Vector3(0.05, 1.2, 0.05), frame_mat), Vector3(center_x, cy, z_face + 0.03))
	_place(_box(Vector3(1.16, 1.18, 0.015), MaterialFactory.glass()), Vector3(center_x, cy, z_face + 0.045))
	_place(_box(Vector3(1.36, 0.05, 0.14), frame_mat), Vector3(center_x, 0.965, z_face + 0.07))


func _window_z(x_face: float, center_z: float, frame_mat: Material) -> void:
	var cy := 1.65
	for o in [-0.60, 0.60]:
		_place(_box(Vector3(0.07, 1.3, 0.08), frame_mat), Vector3(x_face + inward_x(x_face, 0.035), cy, center_z + o))
	for o in [-0.61, 0.61]:
		_place(_box(Vector3(0.07, 0.08, 1.28), frame_mat), Vector3(x_face + inward_x(x_face, 0.035), cy + o, center_z))
	_place(_box(Vector3(0.05, 1.2, 0.05), frame_mat), Vector3(x_face + inward_x(x_face, 0.03), cy, center_z))
	_place(_box(Vector3(0.015, 1.18, 1.16), MaterialFactory.glass()), Vector3(x_face + inward_x(x_face, 0.045), cy, center_z))
	_place(_box(Vector3(0.14, 0.05, 1.36), frame_mat), Vector3(x_face + inward_x(x_face, 0.07), 0.965, center_z))


func inward_x(x_face: float, offset: float) -> float:
	return -offset if x_face > 3.0 else offset


func _picture(pos: Vector3, rot_y_deg: float, seed_value_pic: int, w := 0.50, h := 0.68) -> void:
	var frame := _box(Vector3(w, h, 0.035), MaterialFactory.trim())
	var canvas := _box(Vector3(w - 0.08, h - 0.08, 0.02), StandardMaterial3D.new())
	var cm := canvas.material_override as StandardMaterial3D
	cm.albedo_texture = MaterialFactory.picture_texture(seed_value_pic)
	cm.roughness = 0.9
	frame.add_child(canvas)
	canvas.position = Vector3(0, 0, 0.012)
	_place(frame, pos)
	frame.rotation.y = deg_to_rad(rot_y_deg)


func _crate(pos: Vector3, size: float, height: float, seed_offset := 0, rot_deg := 0.0) -> void:
	var body := _solid(Vector3(size, height, size), MaterialFactory.grime(Color("6a5a3c"), 0.9, 0.12), Vector3(pos.x, height / 2.0, pos.z))
	body.rotation.y = deg_to_rad(rot_deg + float((seed_offset % 20) - 10))


func _process(delta: float) -> void:
	if _flicker_lamp != null and is_instance_valid(_flicker_lamp):
		_flicker_t += delta * 9.0
		_flicker_lamp.light_energy = 1.8 + 1.4 * _flicker_noise.get_noise_1d(_flicker_t)


func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed_value
	_flicker_noise = FastNoiseLite.new()
	_flicker_noise.seed = seed_value
	_flicker_noise.frequency = 0.9
	_build_shell()
	_build_kitchen()
	_build_bedroom()
	_build_bathroom()
	_build_storage()
	_build_hall()