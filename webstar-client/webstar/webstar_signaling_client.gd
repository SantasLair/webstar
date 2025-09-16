##  Handle websocket communication with the signaling server
extends RefCounted
class_name WebstarSignalingClient

signal lobby_joined(lobby: String, peer_id)
#signal peer_disconnected(peer_id: int)
signal lobby_created(lobby_id, peer_id)
signal peer_joined(peer_id)

signal offer_received(peer_id: int, data: String)
signal answer_received(peer_id: int, data: String)
signal candidate_received(peer_id: int, mid: String, index: int, sdp: String)

signal data_received(sender_id: int, data: Dictionary)

var _lobby_id: String = ""
var _peer_id: int = 0

var _websocket: WebSocketPeer = null
var _message_handlers: Dictionary = {}


func _init(websocket: WebSocketPeer) -> void:
	_websocket = websocket
	
	# register message handlers
	_message_handlers = {
		"lobby_joined": _handle_lobby_joined,
		"lobby_created": _handle_lobby_created,
		"peer_joined": _handle_peer_joined,
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

## calls websocket.poll and handles messages
func poll() -> void:
	if !_websocket:
		print("[Webstar] websocket not connected")
		return 
	_websocket.poll()
	_read_packets()

		
## Sends create_lobby message to signaling server
func create_lobby(lobby_id: String, max_players: int, is_public: bool) -> void:
	send_message({
		"type": "create_lobby",
		"lobbyId": lobby_id,
		"max_players": max_players,
		"is_public": is_public
	})


func join_lobby(lobby_id: String) -> void:
	send_message({
		"type": "join_lobby",
		"lobbyId": lobby_id      
	})
	

## Sends a message to the signaling server
func send_message(message: Dictionary) -> void:
	if _websocket:
		var json_string = JSON.stringify(message)
		_websocket.send_text(json_string)
		print("[WebstarManager] Sending message: ", json_string)
	

## Disconnects from the signaling server
func disconnect_from_sever() -> void:
	_websocket.close()
	

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
		"offer":
			var fromPeerId = data.get("fromPeerId")
			var rtcData = data.get("data")
			offer_received.emit(fromPeerId, rtcData)
		"answer":
			var fromPeerId = data.get("fromPeerId")
			var rtcData = data.get("data")
			answer_received.emit(fromPeerId, rtcData)
		"candidate":
			var fromPeerId = int(data.get("fromPeerId"))
			var mid = data.get("mid")
			var index = int(data.get("index"))
			var sdp = data.get("sdp")
			candidate_received.emit(fromPeerId, mid, index, sdp)
		_:
			if _message_handlers.has(message_type):
				_message_handlers[message_type].call(data)


## Handle lobby joined message			
func _handle_lobby_joined(data: Dictionary):
	_lobby_id = data.get("lobbyId", "")
	_peer_id = int(data.get("peerId", 0)) 	# json parser always treats numbers as flots, we must cast
	lobby_joined.emit(_lobby_id, _peer_id)


## Handle lobby created message
func _handle_lobby_created(data: Dictionary):
	_lobby_id = data.get("lobbyId", "")
	_peer_id = int(data.get("peerId", 0))
	lobby_created.emit(_lobby_id, _peer_id)
	

## Handle peer_joined ... a peer joined the current lobby
func _handle_peer_joined(data: Dictionary):
	if _lobby_id == "":
		print("[Webstar] Received a peer joined message while not in a lobby")
		return
		
	var peer_id = int(data.get("peerId", 0))
	if peer_id == 0:
		print("[Webstar] Received invalid peer joined message")
		return
		
	peer_joined.emit(peer_id)
