## WebStar MultiplayerPeer Extension
## Integrates WebStar networking with Godot's high-level multiplayer API
## Enables RPCs, MultiplayerSpawners, and MultiplayerSynchronizers
@tool
extends MultiplayerPeerExtension
class_name WebStarMultiplayerPeer

signal peer_connected_signal(id: int)
signal peer_disconnected_signal(id: int)

var webstar_manager: Node
var local_peer_id: int = 1
var target_peer_id: int = 0
var connection_status: ConnectionStatus = CONNECTION_DISCONNECTED
var packet_queue: Array[Dictionary] = []
var is_host_peer: bool = false

# Store reference to WebStar manager
func initialize_with_webstar(manager: Node):
	webstar_manager = manager
	if webstar_manager:
		# Connect to WebStar signals
		if webstar_manager.has_signal("player_joined"):
			webstar_manager.player_joined.connect(_on_webstar_player_joined)
		if webstar_manager.has_signal("player_left"):
			webstar_manager.player_left.connect(_on_webstar_player_left)
		if webstar_manager.has_signal("message_received"):
			webstar_manager.message_received.connect(_on_webstar_message_received)
		if webstar_manager.has_signal("lobby_joined"):
			webstar_manager.lobby_joined.connect(_on_webstar_lobby_joined)
		if webstar_manager.has_signal("host_changed"):
			webstar_manager.host_changed.connect(_on_webstar_host_changed)
		
		print("[WebStarMultiplayerPeer] Initialized with WebStar manager")

# Required MultiplayerPeerExtension methods
func _get_connection_status() -> ConnectionStatus:
	return connection_status

func _get_unique_id() -> int:
	return local_peer_id

func _set_target_peer(id: int):
	target_peer_id = id

func _is_server() -> bool:
	return is_host_peer

func _is_server_relay_supported() -> bool:
	return true  # WebStar supports relaying through host

func _get_packet() -> PackedByteArray:
	if packet_queue.is_empty():
		return PackedByteArray()
	
	var packet_data = packet_queue.pop_front()
	var json_string = JSON.stringify(packet_data)
	return json_string.to_utf8_buffer()

func _put_packet(buffer: PackedByteArray) -> Error:
	if not webstar_manager or connection_status != CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	
	var json_string = buffer.get_string_from_utf8()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return ERR_INVALID_DATA
	
	var packet_data = json.data
	
	# Add packet metadata
	packet_data["_webstar_sender"] = local_peer_id
	packet_data["_webstar_target"] = target_peer_id
	packet_data["_webstar_timestamp"] = Time.get_ticks_msec()
	
	# Send through WebStar
	if target_peer_id == 0:
		# Broadcast to all
		if webstar_manager.has_method("send_message_to_all"):
			webstar_manager.send_message_to_all("multiplayer_packet", packet_data)
	else:
		# Send to specific peer
		if webstar_manager.has_method("send_message_to_player"):
			webstar_manager.send_message_to_player(target_peer_id, "multiplayer_packet", packet_data)
	
	return OK

func _get_available_packet_count() -> int:
	return packet_queue.size()

func _get_max_packet_size() -> int:
	return 65536  # 64KB max packet size for WebRTC

func _close():
	if webstar_manager and webstar_manager.has_method("leave_lobby"):
		webstar_manager.leave_lobby()
	
	connection_status = CONNECTION_DISCONNECTED
	packet_queue.clear()
	local_peer_id = 1
	target_peer_id = 0
	is_host_peer = false
	
	print("[WebStarMultiplayerPeer] Connection closed")

func _disconnect_peer(id: int, force: bool = false):
	if webstar_manager and webstar_manager.has_method("disconnect_player"):
		webstar_manager.disconnect_player(id)
	
	# Emit disconnection signal
	peer_disconnected_signal.emit(id)
	peer_disconnected.emit(id)

# WebStar signal handlers
func _on_webstar_lobby_joined(lobby_id: String, player_number: int):
	local_peer_id = player_number
	connection_status = CONNECTION_CONNECTED
	
	print("[WebStarMultiplayerPeer] Joined lobby as peer %d" % local_peer_id)

func _on_webstar_player_joined(player_id: int, player_info: Dictionary):
	if player_id != local_peer_id:
		print("[WebStarMultiplayerPeer] Peer %d connected" % player_id)
		peer_connected_signal.emit(player_id)
		peer_connected.emit(player_id)

func _on_webstar_player_left(player_id: int):
	if player_id != local_peer_id:
		print("[WebStarMultiplayerPeer] Peer %d disconnected" % player_id)
		peer_disconnected_signal.emit(player_id)
		peer_disconnected.emit(player_id)

func _on_webstar_host_changed(new_host_id: int):
	is_host_peer = (new_host_id == local_peer_id)
	print("[WebStarMultiplayerPeer] Host changed. I am host: %s" % is_host_peer)

func _on_webstar_message_received(sender_id: int, message_name: String, data: Dictionary):
	if message_name == "multiplayer_packet":
		# Add packet to queue for Godot's multiplayer system
		var packet_data = data.duplicate()
		packet_data["_sender_id"] = sender_id
		packet_queue.push_back(packet_data)
		
		# Notify that packet is available
		packet_received()

# Public API for easier integration
func join_lobby(lobby_id: String, username: String = "Player") -> bool:
	if not webstar_manager:
		push_error("WebStar manager not initialized")
		return false
	
	if webstar_manager.has_method("join_lobby"):
		connection_status = CONNECTION_CONNECTING
		return await webstar_manager.join_lobby(lobby_id, username)
	
	return false

func create_lobby(lobby_id: String, username: String = "Host") -> bool:
	if not webstar_manager:
		push_error("WebStar manager not initialized")
		return false
	
	if webstar_manager.has_method("join_lobby"):
		connection_status = CONNECTION_CONNECTING
		is_host_peer = true
		return await webstar_manager.join_lobby(lobby_id, username)
	
	return false

func get_peer_list() -> Array[int]:
	var peer_list: Array[int] = []
	if webstar_manager and webstar_manager.has_method("get_player_list"):
		var players = webstar_manager.get_player_list()
		for player_id in players:
			if player_id != local_peer_id:
				peer_list.append(player_id)
	return peer_list

func is_connected_to_peer(peer_id: int) -> bool:
	var peers = get_peer_list()
	return peer_id in peers

# Utility methods
func get_webstar_manager():
	return webstar_manager

func set_webstar_manager(manager: Node):
	initialize_with_webstar(manager)
