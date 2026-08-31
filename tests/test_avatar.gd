extends SceneTree
## Headless investigator-avatar test (Vision 5.7): rig builds from primitives,
## every limb pivot exists with a mesh child, face texture is generated with
## real facial content, and driving it animates pivots without errors.

const PASS_S := "TEST_AVATAR_RESULT=PASS"
const FAIL_S := "TEST_AVATAR_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print(FAIL_S, " ", msg)
	quit(1)


func _run() -> void:
	root.add_child(load("res://scenes/match.tscn").instantiate())
	for i in 6:
		await process_frame

	var avatar := InvestigatorAvatar.new()
	root.add_child(avatar)
	avatar.position = Vector3(3.5, 0, 3.85)  # hallway demo spot
	for i in 4:
		await process_frame

	# 1. Rig completeness: 2 hips/knees/shoulders/elbows and a head with a
	# textured face card, all meshes assigned.
	var pivots := [avatar.get("_hips"), avatar.get("_knees"),
			avatar.get("_shoulders"), avatar.get("_elbows")]
	var names := ["hips", "knees", "shoulders", "elbows"]
	for i in pivots.size():
		var arr: Array = pivots[i]
		if arr == null or arr.size() != 2:
			_fail("%s pivots != 2" % names[i])
			return
		for p in arr:
			if not (p is Node3D) or (p as Node3D).get_child_count() == 0:
				_fail("%s pivot missing/meshless" % names[i])
				return
	var head: Node3D = avatar.get("_head")
	if head == null or head.get_child_count() < 3:
		_fail("head rig incomplete")
		return
	var face_tex: ImageTexture = avatar.face_texture_detailed(Color("c8a284"), 3)
	if face_tex == null:
		_fail("face texture null")
		return
	var fimg: Image = face_tex.get_image()
	var skin_px: Color = fimg.get_pixel(64, 40)   # forehead: should be skin shade
	var eye_px: Color = fimg.get_pixel(36, 58)    # left eye white
	var mouth_px: Color = fimg.get_pixel(64, 88)  # lips
	if not (skin_px.get_luminance() > 0.2 and eye_px.get_luminance() > 0.45
			and mouth_px.r > mouth_px.b + 0.08):
		_fail("face texture lacks facial content (%s %s %s)" % [skin_px, eye_px, mouth_px])
		return

	# 2. Drive API: walking animates pivots (legs swing, phase advances).
	avatar.drive(3.2)
	var hip0: Node3D = (avatar.get("_hips") as Array)[0]
	var knee0: Node3D = (avatar.get("_knees") as Array)[0]
	var r0 := hip0.rotation.x
	var k0 := knee0.rotation.x
	for i in 30:
		await process_frame
	var r1 := hip0.rotation.x
	var k1 := knee0.rotation.x
	if absf(r1 - r0) < 0.05:
		_fail("hip pivot not animating (%.3f -> %.3f)" % [r0, r1])
		return
	if absf(k1 - k0) < 0.02:
		_fail("knee pivot not animating (%.3f -> %.3f)" % [k0, k1])
		return

	# 3. Crouch pose: drive(crouch=true) folds the rig down and closes knees.
	avatar.drive(0.0, false, true)
	for i in 40:
		await process_frame
	var rig_y: float = (avatar.get("_rig") as Node3D).position.y
	if rig_y > -0.08:
		_fail("crouch rig drop too small (y=%.3f)" % rig_y)
		return
	if knee0.rotation.x > -0.6:
		_fail("crouch knees not folded (%.3f)" % knee0.rotation.x)
		return

	# 4. Second variant: different skin/jacket combination, no crash.
	avatar.queue_free()
	var avatar2 := InvestigatorAvatar.new()
	avatar2.player_index = 2
	root.add_child(avatar2)
	for i in 6:
		await process_frame
	if avatar2.get("_rig") == null:
		_fail("variant rig missing")
		return

	print(PASS_S)
	quit(0)