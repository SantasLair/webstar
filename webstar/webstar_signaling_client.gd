## WebSocket signaling client for WebStar networking
## Handles lobby management, player coordination, and WebRTC signaling
class_name WebStarSignalingClient
extends RefCounted

signal lobby_joined(lobby_id: String, player_id: int, player_list: Array)
signal lobby_left()
signal peer_id_received(player_id: int, peer_id: String)
signal game_started()
signal game_ended()
signal player_list_updated(player_list: Array)
signal host_migration_requested(new_host_id: int)
signal connection_error(message: String)

var websocket: WebSocketPeer
var config: WebStarConfig
var lobby_id: String = ""
var local_player_id: int = 0
var username: String = ""
var is_connected: bool = false
var heartbeat_timer: Timer

# Message handlers
var message_handlers: Dictionary = {}

func _init(p_config: WebStarConfig):
	config = p_config
	websocket = WebSocketPeer.new()
	_setup_message_handlers()
	_setup_heartbeat_timer()

func _setup_message_handlers():
	message_handlers = {
		"lobby_joined": _handle_lobby_joined,
		"lobby_left": _handle_lobby_left,
		"peer_id": _handle_peer_id,
		"game_started": _handle_game_started,
		"game_ended": _handle_game_ended,
		"player_list_updated": _handle_player_list_updated,
		"host_migration": _handle_host_migration,
		"error": _handle_error,
		"pong": _handle_pong
	}

func _setup_heartbeat_timer():
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = config.lobby_heartbeat_interval
	heartbeat_timer.autostart = false
	heartbeat_timer.timeout.connect(_send_heartbeat)

func join_lobby(p_lobby_id: String, p_username: String = "Player") -> bool:
	if is_connected:
		push_warning("Already connected to a lobby")
		return false
	
	lobby_id = p_lobby_id
	username = p_username
	
	# Connect to signaling server
	var error = websocket.connect_to_url(config.signaling_server_url)
	if error != OK:
		push_error("Failed to connect to signaling server: " + str(error))
		return false
	
	# Wait for connection
	var timeout_counter = 0.0
	while websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		await Engine.get_main_loop().process_frame
		timeout_counter += Engine.get_main_loop().get_physics_interpolation_fraction()
		if timeout_counter > config.connection_timeout:
			push_error("Connection timeout")
			return false
	
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_error("Failed to establish WebSocket connection")
		return false
	
	# Send join lobby request
	var join_message = {
		"type": "join_lobby",
		"lobby_id": lobby_id,
		"username": username,
		"timestamp": Time.get_ticks_msec()
	}
	
	_send_message(join_message)
	is_connected = true
	heartbeat_timer.start()
	
	# Start processing messages
	_start_message_processing()
	
	return true

func leave_lobby():
	if not is_connected:
		return
	
	var leave_message = {
		"type": "leave_lobby",
		"lobby_id": lobby_id,
		"player_id": local_player_id
	}
	
	_send_message(leave_message)
	_disconnect()

func start_game() -> bool:
	if not is_connected:
		return false
	
	var start_message = {
		"type": "start_game",
		"lobby_id": lobby_id
	}
	
	_send_message(start_message)
	return true

func send_peer_id(peer_id: String):
	"""Send our WebRTC peer ID to other players."""
	var peer_message = {
		"type": "peer_id",
		"lobby_id": lobby_id,
		"player_id": local_player_id,
		"peer_id": peer_id
	}
	
	_send_message(peer_message)

func send_webrtc_signal(target_player_id: int, signal_data: Dictionary):
	"""Send WebRTC signaling data (offer, answer, ICE candidate)."""
	var signal_message = {
		"type": "webrtc_signal",
		"lobby_id": lobby_id,
		"from_player": local_player_id,
		"to_player": target_player_id,
		"signal": signal_data
	}
	
	_send_message(signal_message)

func request_host_migration():
	"""Request host migration (typically called when host disconnects)."""
	var migration_message = {
		"type": "request_host_migration",
		"lobby_id": lobby_id,
		"requesting_player": local_player_id
	}
	
	_send_message(migration_message)

func _send_message(message: Dictionary):
	if not is_connected or websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var json_string = JSON.stringify(message)
	var error = websocket.send_text(json_string)
	
	if error != OK:
		push_error("Failed to send message: " + str(error))

func _send_heartbeat():
	if not is_connected:
		return
	
	var ping_message = {
		"type": "ping",
		"lobby_id": lobby_id,
		"player_id": local_player_id,
		"timestamp": Time.get_ticks_msec()
	}
	
	_send_message(ping_message)

func _start_message_processing():
	# Start processing incoming messages
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60 FPS
	timer.autostart = true
	timer.timeout.connect(_process_messages)
	timer.start()

func _process_messages():
	if not is_connected:
		return
	
	websocket.poll()
	
	if websocket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
		_handle_disconnection()
		return
	
	while websocket.get_available_packet_count() > 0:
		var packet = websocket.get_packet()
		var message_text = packet.get_string_from_utf8()
		
		var json = JSON.new()
		var parse_result = json.parse(message_text)
		
		if parse_result != OK:
			push_warning("Failed to parse message: " + message_text)
			continue
		
		var message = json.data
		_handle_message(message)

func _handle_message(message: Dictionary):
	if not message.has("type"):
		push_warning("Message missing type field")
		return
	
	var message_type = message.type
	if message_handlers.has(message_type):
		message_handlers[message_type].call(message)
	else:
		if config.debug_logging:
			print("Unknown message type: ", message_type)

func _handle_lobby_joined(message: Dictionary):
	local_player_id = message.get("player_id", 0)
	var player_list = message.get("player_list", [])
	lobby_joined.emit(lobby_id, local_player_id, player_list)

func _handle_lobby_left(message: Dictionary):
	_disconnect()

func _handle_peer_id(message: Dictionary):
	var player_id = message.get("player_id", 0)
	var peer_id = message.get("peer_id", "")
	
	if player_id != local_player_id:  # Don't handle our own peer ID
		peer_id_received.emit(player_id, peer_id)

func _handle_game_started(message: Dictionary):
	game_started.emit()

func _handle_game_ended(message: Dictionary):
	game_ended.emit()

func _handle_player_list_updated(message: Dictionary):
	var player_list = message.get("player_list", [])
	player_list_updated.emit(player_list)

func _handle_host_migration(message: Dictionary):
	var new_host_id = message.get("new_host_id", 0)
	host_migration_requested.emit(new_host_id)

func _handle_error(message: Dictionary):
	var error_message = message.get("message", "Unknown error")
	push_error("Server error: " + error_message)
	connection_error.emit(error_message)

func _handle_pong(message: Dictionary):
	# Handle ping/pong for connection monitoring
	pass

func _handle_disconnection():
	_disconnect()

func _disconnect():
	is_connected = false
	heartbeat_timer.stop()
	
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		websocket.close()
	
	lobby_left.emit()

func is_lobby_connected() -> bool:
	return is_connected and websocket.get_ready_state() == WebSocketPeer.STATE_OPEN

func get_connection_state() -> WebSocketPeer.State:
	return websocket.get_ready_state()
