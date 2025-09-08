## WebSocket relay manager for WebStar networking fallback
## Provides WebSocket-based communication when WebRTC fails
class_name WebStarRelayManager
extends RefCounted

signal peer_connected(player_id: int)
signal peer_disconnected(player_id: int)
signal data_received(sender_id: int, data: Dictionary)
signal connection_error(player_id: int, message: String)

var config: WebStarConfig
var websocket: WebSocketPeer
var is_connected: bool = false
var local_player_id: int = 0
var lobby_id: String = ""

# Connection monitoring
var heartbeat_timer: Timer
var last_heartbeat_time: int = 0

func _init(p_config: WebStarConfig):
	config = p_config
	websocket = WebSocketPeer.new()
	_setup_heartbeat_timer()

func connect_to_relay(p_lobby_id: String, player_id: int) -> bool:
	"""Connect to the WebSocket relay server."""
	if is_connected:
		push_warning("Already connected to relay server")
		return false
	
	lobby_id = p_lobby_id
	local_player_id = player_id
	
	# Connect to relay server
	var error = websocket.connect_to_url(config.relay_server_url)
	if error != OK:
		push_error("Failed to connect to relay server: " + str(error))
		return false
	
	# Wait for connection
	var timeout_counter = 0.0
	while websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		await Engine.get_main_loop().process_frame
		timeout_counter += Engine.get_main_loop().get_physics_interpolation_fraction()
		if timeout_counter > config.relay_timeout:
			push_error("Relay connection timeout")
			return false
	
	if websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_error("Failed to establish relay connection")
		return false
	
	# Send join message
	var join_message = {
		"type": "join_relay",
		"lobby_id": lobby_id,
		"player_id": local_player_id
	}
	
	_send_message(join_message)
	is_connected = true
	heartbeat_timer.start()
	
	# Start processing messages
	_start_message_processing()
	
	return true

func connect_to_player(player_id: int):
	"""Initiate relay connection to a specific player."""
	if not is_connected:
		# Connect to relay first
		if not await connect_to_relay(lobby_id, local_player_id):
			return
	
	var connect_message = {
		"type": "connect_to_player",
		"lobby_id": lobby_id,
		"from_player": local_player_id,
		"to_player": player_id
	}
	
	_send_message(connect_message)

func send_data(target_player_id: int, data: Dictionary):
	"""Send data to a specific player via relay."""
	if not is_connected:
		push_warning("Not connected to relay server")
		return
	
	var relay_message = {
		"type": "relay_data",
		"lobby_id": lobby_id,
		"from_player": local_player_id,
		"to_player": target_player_id,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	
	# Apply compression if enabled
	if config.enable_compression:
		relay_message = _compress_message(relay_message)
	
	# Simulate packet loss for testing
	if config.simulate_packet_loss > 0.0 and randf() < config.simulate_packet_loss:
		if config.debug_logging:
			print("Simulated packet loss for relay message to player: ", target_player_id)
		return
	
	# Simulate latency for testing
	if config.simulate_latency > 0.0:
		await Engine.get_main_loop().create_timer(config.simulate_latency / 1000.0).timeout
	
	_send_message(relay_message)

func broadcast_data(data: Dictionary):
	"""Broadcast data to all players via relay."""
	var broadcast_message = {
		"type": "broadcast_data",
		"lobby_id": lobby_id,
		"from_player": local_player_id,
		"data": data,
		"timestamp": Time.get_ticks_msec()
	}
	
	_send_message(broadcast_message)

func disconnect_all():
	"""Disconnect from relay server."""
	if not is_connected:
		return
	
	var leave_message = {
		"type": "leave_relay",
		"lobby_id": lobby_id,
		"player_id": local_player_id
	}
	
	_send_message(leave_message)
	_disconnect()

func is_relay_connected() -> bool:
	return is_connected and websocket.get_ready_state() == WebSocketPeer.STATE_OPEN

# Internal methods
func _setup_heartbeat_timer():
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = config.heartbeat_interval
	heartbeat_timer.autostart = false
	heartbeat_timer.timeout.connect(_send_heartbeat)

func _send_message(message: Dictionary):
	if not is_connected or websocket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	
	var json_string = JSON.stringify(message)
	var error = websocket.send_text(json_string)
	
	if error != OK:
		push_error("Failed to send relay message: " + str(error))

func _send_heartbeat():
	if not is_connected:
		return
	
	var heartbeat_message = {
		"type": "relay_heartbeat",
		"lobby_id": lobby_id,
		"player_id": local_player_id,
		"timestamp": Time.get_ticks_msec()
	}
	
	_send_message(heartbeat_message)
	last_heartbeat_time = Time.get_ticks_msec()

func _start_message_processing():
	# Start processing incoming messages
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60 FPS
	timer.autostart = true
	timer.timeout.connect(_process_messages)

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
			push_warning("Failed to parse relay message: " + message_text)
			continue
		
		var message = json.data
		_handle_message(message)

func _handle_message(message: Dictionary):
	if not message.has("type"):
		return
	
	match message.type:
		"player_connected":
			_handle_player_connected(message)
		"player_disconnected":
			_handle_player_disconnected(message)
		"relay_data":
			_handle_relay_data(message)
		"broadcast_data":
			_handle_broadcast_data(message)
		"relay_error":
			_handle_relay_error(message)
		"relay_pong":
			_handle_relay_pong(message)

func _handle_player_connected(message: Dictionary):
	var player_id = message.get("player_id", 0)
	if player_id != local_player_id:
		peer_connected.emit(player_id)

func _handle_player_disconnected(message: Dictionary):
	var player_id = message.get("player_id", 0)
	if player_id != local_player_id:
		peer_disconnected.emit(player_id)

func _handle_relay_data(message: Dictionary):
	var from_player = message.get("from_player", 0)
	var data = message.get("data", {})
	
	# Decompress if needed
	if message.has("compressed") and message.compressed:
		data = _decompress_message_data(data)
	
	if from_player != local_player_id:
		data_received.emit(from_player, data)

func _handle_broadcast_data(message: Dictionary):
	var from_player = message.get("from_player", 0)
	var data = message.get("data", {})
	
	if from_player != local_player_id:
		data_received.emit(from_player, data)

func _handle_relay_error(message: Dictionary):
	var error_message = message.get("message", "Unknown relay error")
	var player_id = message.get("player_id", 0)
	push_error("Relay error: " + error_message)
	connection_error.emit(player_id, error_message)

func _handle_relay_pong(message: Dictionary):
	# Handle ping/pong for connection monitoring
	pass

func _handle_disconnection():
	_disconnect()

func _disconnect():
	is_connected = false
	heartbeat_timer.stop()
	
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		websocket.close()

func _compress_message(message: Dictionary) -> Dictionary:
	"""Compress message data if it's large enough."""
	var json_string = JSON.stringify(message)
	var data_size = json_string.to_utf8_buffer().size()
	
	if data_size > config.compression_threshold:
		var compressed_data = json_string.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
		return {
			"compressed": true,
			"data": Marshalls.raw_to_base64(compressed_data)
		}
	
	return message

func _decompress_message_data(data: String) -> Dictionary:
	"""Decompress message data."""
	var compressed_bytes = Marshalls.base64_to_raw(data)
	var decompressed_bytes = compressed_bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	var json_string = decompressed_bytes.get_string_from_utf8()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		return json.data
	else:
		push_error("Failed to decompress message data")
		return {}

func get_connection_state() -> WebSocketPeer.State:
	return websocket.get_ready_state()
