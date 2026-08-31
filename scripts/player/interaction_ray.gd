class_name InteractionRay
extends RayCast3D
## Player-centered interaction ray (Vision 5.8/6 groundwork): aims forward from
## the camera, finds the first InteractableDoor-style node, exposes a prompt.

func _ready() -> void:
	target_position = Vector3(0, 0, -2.4)
	collide_with_areas = false
	collide_with_bodies = true
	collision_mask = 1

func current_prompt() -> String:
	if is_colliding():
		var hit := get_collider()
		if hit and hit.has_method("interaction_prompt"):
			return hit.interaction_prompt()
	return ""

func try_interact() -> void:
	if is_colliding():
		var hit := get_collider()
		if hit and hit.has_method("toggle"):
			hit.toggle()