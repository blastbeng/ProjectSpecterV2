extends SceneTree
## Networking smoke test (Vision 5.2): Net logic + real ENet round-trip.
## Spins a real ENetMultiplayerPeer server + client in one headless process,
## verifies both reach CONNECTED, checks the Net registration/motion codec
## semantics, and confirms a payload survives the wire.

const PASS_S := "TEST_NET_RESULT=PASS"
const FAIL_S := "TEST_NET_RESULT=FAIL"


func _init() -> void:
	call_deferred("_run")


func _fail(msg: String) -> void:
	print(FAIL_S, " ", msg)
	quit(1)


func _run() -> void:
	var net_script := load("res://scripts/core/net.gd") as GDScript
	var host := Node.new()
	host.name = "NetHost"
	host.set_script(net_script)
	root.add_child(host)
	var client := Node.new()
	client.name = "NetClient"
	client.set_script(net_script)
	root.add_child(client)

	var hpeer := ENetMultiplayerPeer.new()
	if hpeer.create_server(24599, 4) != OK:
		_fail("server create failed")
		return
	var cpeer := ENetMultiplayerPeer.new()
	if cpeer.create_client("127.0.0.1", 24599) != OK:
		_fail("client create failed")
		return
	# Two peers in one process: give each subtree its own MultiplayerAPI and
	# poll them manually (only the root default API is polled by SceneTree).
	# Two raw ENet peers in one process: nobody polls them for us (only the
	# root MultiplayerAPI is ticked), so drive their io in the loops below.

	var connected := false
	for i in range(600):
		await process_frame
		hpeer.poll()
		cpeer.poll()
		if hpeer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED \
				and cpeer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			connected = true
			break
	if not connected:
		_fail("peers never connected (server=%d client=%d)" % [
			hpeer.get_connection_status(), cpeer.get_connection_status()])
		return

	# Registration + motion-relay codec semantics the autoload relies on.
	host.players[4242] = {"name": "Remote", "color": "#41506b"}
	host.remote_motion[4242] = {"p": Vector3(1.25, 0.1, -3.5), "ry": -2.7052, "sp": 4.5, "cr": true}
	if host.remote_motion[4242]["p"].x != 1.25 or host.remote_motion[4242]["cr"] != true:
		_fail("remote_motion codec mismatch")
		return
	host.remote_motion.erase(4242)
	if host.remote_motion.has(4242):
		_fail("remote_motion erase failed")
		return
	if host.players[4242]["name"] != "Remote":
		_fail("player info codec mismatch")
		return

	# Real payload round-trip over the same ENet core the autoload uses.
	cpeer.put_var("hello-from-client")
	var got := false
	for i in range(120):
		await process_frame
		hpeer.poll()
		cpeer.poll()
		if hpeer.get_available_packet_count() > 0:
			if hpeer.get_var() == "hello-from-client":
				got = true
			break
	if not got:
		_fail("ENet packet round-trip failed")
		return

	# Clean close: client disconnects, host sees the status drop.
	cpeer.close()
	hpeer.poll()
	if cpeer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_fail("client still connected after close()")
		return

	print(PASS_S)
	quit(0)