## WebSocket relay manager for fallback connections
@tool
extends Node
class_name WebStarRelayManager

signal peer_connected(player_id: int)
signal peer_disconnected(player_id: int)
signal data_received(sender_id: int, data: Dictionary)

var config: WebStarConfig
var websocket: WebSocketPeer
var is_connected: bool = false
var lobby_id: String = ""
var local_player_id: int = 0

func _init(p_config: WebStarConfig = null):
	if p_config:
		config = p_config
	else:
		config = WebStarConfig.new()
	
	websocket = WebSocketPeer.new()

func connect_to_relay() -> bool:
	var error = websocket.connect_to_url(config.relay_server_url)
	if error != OK:
		push_error("Failed to connect to relay server: " + str(error))
		return false
	
	# Wait for connection
	var timeout = config.relay_timeout
	var elapsed = 0.0
	
	while websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > timeout:
			push_error("Relay connection timeout")
			return false
	
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		is_connected = true
		return true
	
	return false

func connect_to_player(player_id: int):
	if not is_connected:
		if not await connect_to_relay():
			return
	
	var message = {
		"type": "relay_join",
		"lobby_id": lobby_id,
		"player_id": local_player_id
	}
	_send_message(message)
	peer_connected.emit(player_id)

func disconnect_all():
	if websocket:
		websocket.close()
	is_connected = false

func send_data(player_id: int, data: Dictionary):
	if is_connected:
		var message = {
			"type": "relay_message",
			"target_player_id": player_id,
			"data": data
		}
		_send_message(message)

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

func _send_message(message: Dictionary):
	if websocket and is_connected:
		var json_string = JSON.stringify(message)
		websocket.send_text(json_string)

func _handle_message(data: Dictionary):
	var message_type = data.get("type", "")
	
	match message_type:
		"relay_message":
			var sender_id = data.get("from_player_id", 0)
			var message_data = data.get("data", {})
			data_received.emit(sender_id, message_data)
		"relay_player_joined":
			var player_id = data.get("player_id", 0)
			peer_connected.emit(player_id)
		"relay_error":
			push_error("Relay error: " + data.get("message", "Unknown error"))
