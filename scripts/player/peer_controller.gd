class_name PeerController
extends Node
## Sits under the local Player and relays its motion to remote peers via Net
## every physics tick (Vision 5.2 remote avatar drive).

var _player: CharacterBody3D


func _ready() -> void:
	_player = get_parent() as CharacterBody3D


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	var crouch_v = _player.get("_crouching")
	var crouching := crouch_v != null and bool(crouch_v)
	Net.broadcast_motion(_player.global_position, _player.rotation.y, speed, crouching)