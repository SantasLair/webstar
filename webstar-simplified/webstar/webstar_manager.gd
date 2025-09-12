extends Node
## WebRTC P2P multiplayer networking using star-topoloy where the host
## acts as messaging hub.
##
## Can be used stand-alone or integrate with Godot's MultiplayerAPI

signal signaling_server_connected
signal signaling_server_connection_failed

signal lobby_created(lobby_id, peer_id)
signal lobby_joined(lobby_id, peer_id, player_list)


var _server_url := "ws://localhost:5090/ws"
var _connect_timeout_seconds := 5
var _signal_client: WebstarSignalingClient = WebstarSignalingClient.new()
var _current_lobby: String = ""	

var _is_connecting: bool = false
var _is_connected: bool = false
var _is_in_lobby: bool = false
var _peer_id: int = 0
var _lobby_id: String = ""
var _is_host: bool = false


func _ready() -> void:
	_signal_client.lobby_created.connect(_on_lobby_created)
	_signal_client.lobby_joined.connect(_on_lobby_joined)
	set_process(false) # inactive until connect_to_signaling_server
	
	
func _process(_delta: float) -> void:
	_signal_client.poll()
	
## Async Connects to the singnaling server.  Raises signal signaling_server_connected
## or signaling_server_connection_failed
func connect_to_signaling_server_async() -> bool:
	if _is_connecting or _is_connected:
		print("[Webstar] Already connected or connecting to signaling server")
		return false
		
	_is_connecting = true
	print("[Webstar] Connecting to signaling server: ", _server_url)
	var websocket = WebSocketPeer.new()
	var error = websocket.connect_to_url(_server_url)
	if error != OK:
		push_error("[Webstar] Failed to connect to signaling server: " + str(error))
		return false
	
	# Wait for connection    
	var elapsed = 0.0
	var last_print_time = 0.0
	print("[WebStar] Waiting for connection, timeout: ", _connect_timeout_seconds, " seconds")
	
	while websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		websocket.poll()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
		# Only print every second to reduce spam
		if elapsed - last_print_time >= 1.0:
			print("[WebStar] Still connecting... elapsed: ", elapsed, " state: ", websocket.get_ready_state())
			last_print_time = elapsed
			
		if elapsed > _connect_timeout_seconds:
			print("[Webstar] Timeout conneting to signaling server")
			push_error("Connection timeout")
			return false

	# when connected, pass websocket to signal client and enable processing
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		print("[Webstar] Connected to signaling server")
		_signal_client.set_websocket(websocket)
		_is_connected = true
		set_process(true)
		return true

	return false


## Creates a lobby.  Lobby owners acts as hosts and will initiate WebRTC offers to peers.
func create_lobby(lobby_id: String, max_players: int, is_public: bool) -> bool:
	if !_is_connected:
		_is_connected = await connect_to_signaling_server_async()
		if !_is_connected:
			return false
		
	if _current_lobby != "":
		push_warning("Already connected to a lobby")
		return false

	_signal_client.send_message({
		"type": "create_lobby",
		"lobbyId": lobby_id,      
		"maxPlayers": max_players,
		"isPublic": is_public
	})
	return true
	

## Joins an existing lobby. Fails if the lobby does not exist. Once lobby is joined,
## will receive WebRTC offer from host.	
func join_lobby(lobby_id: String):
	pass


func leave_lobby():
	if _is_in_lobby:
		_signal_client.disconnect_from_sever()
		_is_connected = false
		_is_in_lobby = false
		_is_connecting = false
		_lobby_id = ""
	
# =============================================================================
# Signal handlers
# =============================================================================

## Handles socket connection success
func _on_socket_connected():
	print("[Webstar] Connected to signaling server")
	_is_connected = true
	_is_connecting = false
	signaling_server_connected.emit()
	

## Handles connection failure
func _on_socket_connection_failed():
	print("[Webstar] Failed to connect to signaling server")
	_is_connected = false
	_is_connecting = false	
	signaling_server_connection_failed.emit()
	set_process(false)
	

## We created a lobby, we are the host, peer_id should be 1
func _on_lobby_created(lobby_id: String, peer_id: int):
	_peer_id = peer_id
	_is_host = true
	print("[Webstar] lobby %s created as peer %d" % [lobby_id, _peer_id])
	lobby_created.emit(lobby_id, _peer_id)


## We joined a lobby, relay lobby joined signal.
func _on_lobby_joined(lobby_id: String, peer_id: int, player_list: Array):
	_peer_id = peer_id
	_lobby_id = lobby_id
	_is_in_lobby = true
	print("[Webstar] lobby %s joined as peer %d" % [lobby_id, peer_id])
	lobby_joined.emit(lobby_id, peer_id, player_list)
	
