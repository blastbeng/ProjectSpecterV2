extends Node
## Net autoload (Vision 5.2): ENet high-level multiplayer plumbing.
## Host creates an ENetMultiplayerPeer on PORT and becomes peer 1; joiner
## connects to the same port. Both sides register each other via
## register_player() after a peer_connected handshake, then relay movement to
## remote teammates each physics tick:
##  - local PeerController broadcasts `update_motion` every tick;
##  - match.gd spawns a remote InvestigatorAvatar per registered peer and
##    calls its drive() from the received update_motion.
## Solo play is the default; all signals fire before the Match scene loads.

signal player_registered(id: int, info: Dictionary)
signal player_left(id: int)
signal connected_to_host_ok
signal host_started_ok

const PORT := 24555
const MAX_PEERS := 4

# peer id -> {name: String, color: String (hex)}
var players := {}

# peer id -> latest relayed motion (used by match.gd to drive remote avatars)
var remote_motion := {}  # id -> {p: Vector3, ry: float, sp: float, cr: bool}


func is_online() -> bool:
	return multiplayer.multiplayer_peer != null \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Headless smoke-test hook: a second instance launched with
	# `-- --net-join` auto-joins 127.0.0.1 and routes straight to Match.
	if "--net-join" in OS.get_cmdline_user_args():
		join_game("127.0.0.1", "RemotePeer", "#41506b")
		SceneRouter.goto("res://scenes/match.tscn")


func _on_peer_connected(id: int) -> void:
	# Handshake: everyone tells the newcomer who they are; newcomer tells us.
	_register_player.rpc_id(id, my_info())


func _on_peer_disconnected(id: int) -> void:
	players.erase(id)
	remote_motion.erase(id)
	player_left.emit(id)


func _on_connected_to_server() -> void:
	connected_to_host_ok.emit()


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null


func _on_server_disconnected() -> void:
	players.clear()
	remote_motion.clear()
	multiplayer.multiplayer_peer = null


func my_info() -> Dictionary:
	return {"name": player_name, "color": player_color}


var player_name := "Investigator"
var player_color := "#c8a284"


func set_local_player(p_name: String, p_color: String) -> void:
	player_name = p_name
	player_color = p_color
	if not players.is_empty() or is_online():
		_register_player.rpc(my_info())


func host_game(p_name: String, p_color: String) -> bool:
	set_local_player(p_name, p_color)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PEERS)
	if err != OK:
		push_error("Net: host failed (%s)" % error_string(err))
		return false
	multiplayer.multiplayer_peer = peer
	players[1] = my_info()
	player_registered.emit(1, my_info())
	host_started_ok.emit()
	print("NET: hosting on port %d" % PORT)
	return true


func join_game(ip: String, p_name: String, p_color: String) -> bool:
	set_local_player(p_name, p_color)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("Net: join failed (%s)" % error_string(err))
		return false
	multiplayer.multiplayer_peer = peer
	print("NET: joining %s:%d" % [ip, PORT])
	return true


func leave() -> void:
	players.clear()
	remote_motion.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null


# ---------- name/color handshake ----------

@rpc("any_peer", "call_remote", "reliable")
func _register_player(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	players[id] = info
	player_registered.emit(id, info)
	# So the newcomer learns about existing peers, host rebroadcasts; each
	# side also confirms itself once it knows the sender exists.
	_ack_player.rpc_id(id, my_info())


@rpc("any_peer", "call_remote", "reliable")
func _ack_player(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id):
		players[id] = info
		player_registered.emit(id, info)


# ---------- per-tick motion relay (local PeerController -> remotes) ----------

@rpc("any_peer", "call_local", "unreliable_ordered")
func relay_motion(pos: Vector3, yaw: float, speed: float, crouching: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	remote_motion[id] = {"p": pos, "ry": yaw, "sp": speed, "cr": crouching}


func broadcast_motion(pos: Vector3, yaw: float, speed: float, crouching: bool) -> void:
	if is_online():
		relay_motion.rpc(pos, yaw, speed, crouching)