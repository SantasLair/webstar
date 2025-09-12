##  Handle websocket communication with the signaling server
extends RefCounted
class_name WebstarSignalingClient

signal peer_connected(player_id: int)
signal data_received(sender_id: int, data: Dictionary)
signal lobby_created(lobby_id, peer_id)
signal lobby_joined(lobby_id, peer_id, player_list)

var lobby_id: String = ""
var peer_id: int = 0


var _websocket: WebSocketPeer = null
var _message_handlers: Dictionary = {}


func _init() -> void:
	# register message handlers
	_message_handlers = {
		"lobby_joined": _handle_lobby_joined,
		"lobby_created": _handle_lobby_created,
		# "lobby_left": _handle_lobby_left,
		# "peer_id": _handle_peer_id,
		# "game_started": _handle_game_started,
		# "game_ended": _handle_game_ended,
		# "player_list_updated": _handle_player_list_updated,
		# "host_migration": _handle_host_migration,
		# "error": _handle_error,
		# "pong": _handle_pong
	}

# =============================================================================
# Public Methods
# =============================================================================

## Sets the websocket.  The websocket should be open and ready for communication at this point
func set_websocket(websocket: WebSocketPeer) -> void:
	_websocket = websocket
	

## calls websocket.poll and handles messages
func poll() -> void:
	if !_websocket:
		print("[Webstar] websocket not connected")
		return 
	_websocket.poll()
	_read_packets()
		

## Sends a message to the signaling server
func send_message(message: Dictionary) -> void:
	if _websocket:
		var json_string = JSON.stringify(message)
		_websocket.send_text(json_string)
		print("[WebstarManager] Sending message: ", json_string)
	

## Disconnects from the signaling server
func disconnect_from_sever() -> void:
	_websocket = null	
	

## Reads incoming packets and process them using registered message handers
func _read_packets() -> void:
	while _websocket.get_available_packet_count() > 0:
		var packet = _websocket.get_packet()
		var json = JSON.new()
		var parse_result = json.parse(packet.get_string_from_utf8())
		if parse_result == OK:
			_handle_message(json.data)

# =============================================================================
# Message Handlers
# =============================================================================

## Handles a JSON-formatted message
func _handle_message(data: Dictionary):
	print("[Webstar] received packet", data)
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
		_:
			if _message_handlers.has(message_type):
				_message_handlers[message_type].call(data)


## Handle lobby joined message			
func _handle_lobby_joined(data: Dictionary):
	var lobby: Dictionary = data.get("lobby")
	lobby_id = lobby.get("lobbyId", "")
	# json parser always treats numbers as flots, we must cast
	peer_id = int(lobby.get("peerId", 0)) 
	var player_list = lobby.get("playerList", [])
	lobby_joined.emit(lobby_id, peer_id, player_list)


## Handle lobby created message
func _handle_lobby_created(data: Dictionary):
	var lobby: Dictionary = data.get("lobby")
	lobby_id = lobby.get("id", "uknown")
	peer_id = int(lobby.get("peerId", 0))
	lobby_created.emit(lobby_id, peer_id)
