class_name RoomBuilder
extends Node3D
## One dressed kitchen per Vision 5.4/5.5/5.6: shell (floor/walls/ceiling with
## baseboards), counter run with sink, fridge, table + 2 chairs, hanging lamp
## with fixture mesh, window with frame + glass, framed pictures, dust motes.
## Everything rests on the floor with collision; nothing floats.

const CEIL_H := 2.8
const ROOM_W := 6.0
const ROOM_D := 5.0
const WT := 0.10  # wall thickness


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


## Solid, visible, collidable box.
func _solid(size: Vector3, mat: Material, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.add_child(_box(size, mat))
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = Vector3.ZERO
	body.add_child(cs)
	_place(body, pos)
	return body


## Wall with rotation support (collision included).
func _wall(size: Vector3, mat: Material, pos: Vector3, rot_y_deg: float) -> void:
	var body := _solid(size, mat, pos)
	body.rotation.y = deg_to_rad(rot_y_deg)


# ---------- shell ----------

func _build_shell() -> void:
	# Floor: slab top exactly at y = 0.
	_solid(Vector3(ROOM_W, 0.1, ROOM_D), MaterialFactory.floor_wood(), Vector3(ROOM_W / 2.0, -0.05, ROOM_D / 2.0))
	# Ceiling (decor only).
	_place(_box(Vector3(ROOM_W, 0.1, ROOM_D), MaterialFactory.ceiling()), Vector3(ROOM_W / 2.0, CEIL_H + 0.05, ROOM_D / 2.0))
	# Four walls; the south wall is two segments leaving a doorway at x 1.0..2.1.
	_wall(Vector3(ROOM_W + 2 * WT, CEIL_H, WT), MaterialFactory.wall(), Vector3(ROOM_W / 2.0, CEIL_H / 2.0, -WT / 2.0), 0.0)
	_wall(Vector3(1.0 + WT / 2.0, CEIL_H, WT), MaterialFactory.wall(), Vector3(0.5 - WT / 2.0, CEIL_H / 2.0, ROOM_D + WT / 2.0), 0.0)
	_wall(Vector3(ROOM_W - 2.1, CEIL_H, WT), MaterialFactory.wall(), Vector3((2.1 + ROOM_W) / 2.0, CEIL_H / 2.0, ROOM_D + WT / 2.0), 0.0)
	_place(_box(Vector3(1.1 + 0.3, CEIL_H - 2.05, WT), MaterialFactory.wall()), Vector3(1.55, 2.05 + (CEIL_H - 2.05) / 2.0, ROOM_D + WT / 2.0))
	_wall(Vector3(WT, CEIL_H, ROOM_D), MaterialFactory.wall(), Vector3(-WT / 2.0, CEIL_H / 2.0, ROOM_D / 2.0), 0.0)
	_wall(Vector3(WT, CEIL_H, ROOM_D), MaterialFactory.wall_stained(), Vector3(ROOM_W + WT / 2.0, CEIL_H / 2.0, ROOM_D / 2.0), 0.0)
	# Split baseboard around the doorway.
	_place(_box(Vector3(0.86, 0.12, 0.03), MaterialFactory.trim()), Vector3(0.53, 0.06, ROOM_D - 0.08))
	_place(_box(Vector3(ROOM_W - 2.24, 0.12, 0.03), MaterialFactory.trim()), Vector3((2.24 + ROOM_W) / 2.0, 0.06, ROOM_D - 0.08))
	# Baseboards, slightly offset inward from each wall face.
	var inset := 0.08
	_place(_box(Vector3(ROOM_W - 0.2, 0.12, 0.03), MaterialFactory.trim()), Vector3(ROOM_W / 2.0, 0.06, inset))
	_place(_box(Vector3(ROOM_W - 0.2, 0.12, 0.03), MaterialFactory.trim()), Vector3(ROOM_W / 2.0, 0.06, ROOM_D - inset))
	_place(_box(Vector3(ROOM_D - 0.2, 0.12, 0.03), MaterialFactory.trim()), Vector3(inset, 0.06, ROOM_D / 2.0))
	_place(_box(Vector3(ROOM_D - 0.2, 0.12, 0.03), MaterialFactory.trim()), Vector3(ROOM_W - inset, 0.06, ROOM_D / 2.0))


# ---------- kitchen kit (Vision 5.5) ----------

func _build_counter_run() -> void:
	var top_mat := MaterialFactory.grime(Color("6d6a63"), 0.6, 0.06)
	var basin_mat := MaterialFactory.grime(Color("2e3236"), 0.35, 0.1)
	var wood := MaterialFactory.wood_dark()
	# Lower run on the north wall.
	_solid(Vector3(2.9, 0.9, 0.62), wood, Vector3(2.2, 0.45, 0.34))
	_solid(Vector3(3.1, 0.05, 0.68), top_mat, Vector3(2.2, 0.925, 0.34))
	# Sink basin inset + faucet.
	_place(_box(Vector3(0.42, 0.05, 0.34), basin_mat), Vector3(2.5, 0.95, 0.34))
	var faucet := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.012
	fm.bottom_radius = 0.016
	fm.height = 0.26
	faucet.mesh = fm
	faucet.material_override = MaterialFactory.metal()
	_place(faucet, Vector3(2.72, 1.05, 0.34))
	faucet.rotation_degrees = Vector3(0, 0, 10)
	# Upper cabinets.
	_solid(Vector3(2.4, 0.7, 0.34), wood, Vector3(2.4, 1.95, 0.17))
	# Cabinet door panels + knobs.
	for i in range(3):
		var door := _box(Vector3(0.78, 0.76, 0.02), wood)
		_place(door, Vector3(1.0 + 0.9 * i, 0.45, 0.665))
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.02
		km.height = 0.04
		knob.mesh = km
		knob.material_override = MaterialFactory.metal()
		_place(knob, Vector3(1.0 + 0.9 * i + 0.32, 0.45, 0.685))


func _build_fridge() -> void:
	_solid(Vector3(0.75, 1.85, 0.72), MaterialFactory.metal(), Vector3(5.45, 0.925, 0.5))
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.015
	hm.bottom_radius = 0.015
	hm.height = 0.5
	handle.mesh = hm
	handle.material_override = MaterialFactory.metal_dark()
	_place(handle, Vector3(5.1, 1.15, 0.86))
	handle.rotation_degrees = Vector3(0, 0, 90)


func _build_table_and_chairs() -> void:
	var wood := MaterialFactory.wood_dark()
	var seat_mat := MaterialFactory.grime(Color("5a4632"), 0.8, 0.09)
	# Table top (solid) + 4 legs.
	_solid(Vector3(1.5, 0.05, 0.9), wood, Vector3(2.9, 0.725, 3.1))
	for cx in [2.24, 3.56]:
		for cz in [2.72, 3.48]:
			_place(_box(Vector3(0.06, 0.70, 0.06), wood), Vector3(cx, 0.35, cz))
	# Two chairs facing each other across the table (x sides).
	for cx in [1.95, 3.85]:
		_solid(Vector3(0.42, 0.05, 0.42), seat_mat, Vector3(cx, 0.45, 3.1))
		var back := _box(Vector3(0.05, 0.5, 0.42), seat_mat)
		var bx: float = cx - 0.19 if cx < 2.9 else cx + 0.19
		_place(back, Vector3(bx, 0.72, 3.1))
		for cz in [2.94, 3.26]:
			_place(_box(Vector3(0.04, 0.45, 0.04), wood), Vector3(cx - 0.16, 0.225, cz))
			_place(_box(Vector3(0.04, 0.45, 0.04), wood), Vector3(cx + 0.16, 0.225, cz))


# ---------- window / pictures / lamp / dust ----------

func _build_window() -> void:
	var frame_mat := MaterialFactory.trim()
	# North wall interior face at z = 0. Glazed assembly between counter and fridge.
	var cx := 4.3
	var cy := 1.65
	_place(_box(Vector3(0.08, 1.3, 0.07), frame_mat), Vector3(cx - 0.60, cy, 0.035))
	_place(_box(Vector3(0.08, 1.3, 0.07), frame_mat), Vector3(cx + 0.60, cy, 0.035))
	_place(_box(Vector3(1.28, 0.08, 0.07), frame_mat), Vector3(cx, cy + 0.61, 0.035))
	_place(_box(Vector3(1.28, 0.08, 0.07), frame_mat), Vector3(cx, cy - 0.61, 0.035))
	# Center muntin
	_place(_box(Vector3(0.05, 1.2, 0.05), frame_mat), Vector3(cx, cy, 0.03))
	# Glass
	_place(_box(Vector3(1.16, 1.18, 0.015), MaterialFactory.glass()), Vector3(cx, cy, 0.045))
	# Sill
	_place(_box(Vector3(1.36, 0.05, 0.14), frame_mat), Vector3(cx, 0.965, 0.07))


func _picture(pos: Vector3, rot_y_deg: float, seed_value: int, w := 0.50, h := 0.68) -> void:
	var frame := _box(Vector3(w, h, 0.035), MaterialFactory.trim())
	var canvas := _box(Vector3(w - 0.08, h - 0.08, 0.02), StandardMaterial3D.new())
	var cm := canvas.material_override as StandardMaterial3D
	cm.albedo_texture = MaterialFactory.picture_texture(seed_value)
	cm.roughness = 0.9
	frame.add_child(canvas)
	canvas.position = Vector3(0, 0, 0.012)
	_place(frame, pos)
	frame.rotation.y = deg_to_rad(rot_y_deg)


func _build_pictures() -> void:
	_picture(Vector3(1.3, 1.62, ROOM_D - 0.055), 0.0, 11)
	_picture(Vector3(ROOM_W - 0.055, 1.55, 3.6), -90.0, 7)


func _build_lamp() -> void:
	var lx := 2.9
	var lz := 3.1
	# Cord
	_place(_box(Vector3(0.02, 0.38, 0.02), MaterialFactory.metal_dark()), Vector3(lx, 2.61, lz))
	# Shade
	var shade := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.04
	sm.bottom_radius = 0.24
	sm.height = 0.18
	shade.mesh = sm
	shade.material_override = MaterialFactory.metal_dark()
	_place(shade, Vector3(lx, 2.37, lz))
	# Emissive bulb
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.035
	bm.height = 0.07
	bulb.mesh = bm
	bulb.material_override = MaterialFactory.bulb()
	_place(bulb, Vector3(lx, 2.30, lz))
	# Warm lights: main pendant + softer fill over the kitchen run.
	var light := OmniLight3D.new()
	light.light_color = MaterialFactory.LAMP_LIGHT
	light.light_energy = 2.6
	light.omni_range = 12.0
	light.shadow_enabled = true
	light.shadow_blur = 1.4
	_place(light, Vector3(lx, 2.18, lz))
	var fill := OmniLight3D.new()
	fill.light_color = MaterialFactory.LAMP_LIGHT.lerp(Color.WHITE, 0.25)
	fill.light_energy = 1.1
	fill.omni_range = 7.0
	fill.position = Vector3(2.2, 2.35, 1.1)
	add_child(fill)


func _build_dust() -> void:
	var p := GPUParticles3D.new()
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.8, 0.35, 0.8)
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
	p.amount = 24
	p.lifetime = 7.0
	p.randomness = 1.0
	_place(p, Vector3(2.9, 1.95, 3.1))


func _build_door() -> void:
	var door := InteractableDoor.new(0.95, 2.05, 0.0)
	# Hinge against the left jamb at x = 1.0, leaf spans toward x = 1.95.
	door.position = Vector3(1.0, 0.0, ROOM_D - 0.06)
	add_child(door)


func _ready() -> void:
	_build_shell()
	_build_counter_run()
	_build_fridge()
	_build_table_and_chairs()
	_build_window()
	_build_pictures()
	_build_lamp()
	_build_dust()
	_build_door()