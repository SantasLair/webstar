## WebSocket signaling client for WebStar networking
## Handles lobby management, player coordination, and WebRTC signaling
@tool
extends Node
class_name WebStarSignalingClient

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

func _init(p_config: WebStarConfig = null):
	print("[WebStar] init webstar_signaling_client")
	if p_config:
		config = p_config
	else:
		config = WebStarConfig.new()
	websocket = WebSocketPeer.new()
	_setup_message_handlers()

func _ready():
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
	add_child(heartbeat_timer)

func connect_to_signaling_server() -> bool:
	print("[WebStar] Attempting to connect to: ", config.signaling_server_url)
	var error = websocket.connect_to_url(config.signaling_server_url)
	print("[WebStar] connect_to_url returned: ", error)
	if error != OK:
		push_error("Failed to connect to signaling server: " + str(error))
		return false
	
	# Wait for connection
	var timeout = config.connection_timeout
	var elapsed = 0.0
	var last_print_time = 0.0
	print("[WebStar] Waiting for connection, timeout: ", timeout, " seconds")
	
	while websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		# Process the websocket during connection attempt
		websocket.poll()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
		# Only print every second to reduce spam
		if elapsed - last_print_time >= 1.0:
			print("[WebStar] Still connecting... elapsed: ", elapsed, " state: ", websocket.get_ready_state())
			last_print_time = elapsed
			
		if elapsed > timeout:
			print("[WebStar] Connection timeout reached")
			push_error("Connection timeout")
			return false
	
	var final_state = websocket.get_ready_state()
	print("[WebStar] Final connection state: ", final_state)
	
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		print("[WebStar] Connection successful!")
		
		# CRITICAL: Poll immediately after connection to receive welcome message
		websocket.poll()
		
		# Check for and process the welcome message
		if websocket.get_available_packet_count() > 0:
			print("[WebStar] Received welcome message(s)")
			while websocket.get_available_packet_count() > 0:
				var packet = websocket.get_packet()
				var message_text = packet.get_string_from_utf8()
				print("[WebStar] Welcome message: ", message_text)
				# Parse and handle the welcome message if needed
				var message = JSON.parse_string(message_text)
				if message and message.has("type") and message.type == "connected":
					print("[WebStar] Server welcome confirmed, client ID: ", message.get("clientId", "unknown"))
		
		is_connected = true
		heartbeat_timer.start()
		return true
	
	print("[WebStar] Connection failed, final state was not OPEN")
	return false

func disconnect_from_server():
	if websocket:
		websocket.close()
	is_connected = false
	heartbeat_timer.stop()

func join_lobby(p_lobby_id: String, p_username: String) -> bool:
	if not is_connected:
		if not await connect_to_signaling_server():
			return false
	
	lobby_id = p_lobby_id
	username = p_username
	
	var message = {
		"type": "join_lobby",
		"lobby_id": lobby_id,
		"player_info": {
			"username": username
		}
	}
	
	_send_message(message)
	return true

func leave_lobby():
	if is_connected:
		var message = {"type": "leave_lobby"}
		_send_message(message)
	
	lobby_id = ""
	local_player_id = 0

func start_game() -> bool:
	if not is_connected:
		return false
	
	var message = {"type": "start_game"}
	_send_message(message)
	return true

func _process(delta):
	if websocket and is_connected:
		websocket.poll()
		
		var state = websocket.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while websocket.get_available_packet_count() > 0:
				var packet = websocket.get_packet()
				var json = JSON.new()
				var parse_result = json.parse(packet.get_string_from_utf8())
				if parse_result == OK:
					_handle_message(json.data)
		elif state == WebSocketPeer.STATE_CLOSED:
			is_connected = false
			heartbeat_timer.stop()

func _send_message(message: Dictionary):
	if websocket and is_connected:
		var json_string = JSON.stringify(message)
		websocket.send_text(json_string)

func _handle_message(data: Dictionary):
	var message_type = data.get("type", "")
	if message_handlers.has(message_type):
		message_handlers[message_type].call(data)

func _handle_lobby_joined(data: Dictionary):
	lobby_id = data.get("lobby_id", "")
	local_player_id = data.get("player_id", 0)
	var player_list = data.get("player_list", [])
	lobby_joined.emit(lobby_id, local_player_id, player_list)

func _handle_lobby_left(data: Dictionary):
	lobby_left.emit()

func _handle_peer_id(data: Dictionary):
	var player_id = data.get("player_id", 0)
	var peer_id = data.get("peer_id", "")
	peer_id_received.emit(player_id, peer_id)

func _handle_game_started(data: Dictionary):
	game_started.emit()

func _handle_game_ended(data: Dictionary):
	game_ended.emit()

func _handle_player_list_updated(data: Dictionary):
	var player_list = data.get("player_list", [])
	player_list_updated.emit(player_list)

func _handle_host_migration(data: Dictionary):
	var new_host_id = data.get("new_host_id", 0)
	host_migration_requested.emit(new_host_id)

func _handle_error(data: Dictionary):
	var error_message = data.get("message", "Unknown error")
	connection_error.emit(error_message)

func _handle_pong(data: Dictionary):
	# Handle heartbeat response
	pass

func _send_heartbeat():
	if is_connected:
		var message = {"type": "ping", "timestamp": Time.get_ticks_msec()}
		_send_message(message)
