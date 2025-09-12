extends Node
## WebRTC P2P multiplayer networking using star-topoloy where the host
## acts as messaging hub.
##
## Can be used stand-alone or integrate with Godot's MultiplayerAPI

signal signaling_server_connected
signal signaling_server_connection_failed

signal lobby_created(lobby_id, peer_id)
signal lobby_joined(lobby_id, peer_id, player_list)


var _signal_client: WebstarSignalingClient = WebstarSignalingClient.new()
var _current_lobby: String = ""	

var _is_connecting: bool = false
var _is_connected: bool = false
var _peer_id: int = 0
var _is_host: bool = false


func _ready() -> void:
	_signal_client.socket_connected.connect(_on_socket_connected)
	_signal_client.socket_connection_failed.connect(_on_socket_connection_failed)
	_signal_client.lobby_created.connect(_on_lobby_created)
	_signal_client.lobby_joined.connect(_on_lobby_joined)
	set_process(false) # inactive until connect_to_signaling_server
	
	
func _process(_delta: float) -> void:
	_signal_client.poll()
	
## Connects to the singnaling server.  Raises signal signaling_server_connected
## or signaling_server_connection_failed
func connect_to_signaling_server(server_url) -> void: #ToDo: add timeout parameter
	if _is_connected or _is_connecting:
		print ("already connected or connecting to signaling sever")
		return
	
	_signal_client.start_connecting(server_url)
	_is_connecting = true
	set_process(true)


## Creates a lobby.  Lobby owners acts as hosts and will initiate WebRTC offers to peers.
func create_lobby(lobby_id: String, max_players: int, is_public: bool) -> bool:
	if !_is_connected:
		push_warning("create_lobby called but not connected to server")
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
	print("[Webstar] lobby %s joined as peer %d" % [lobby_id, peer_id])
	lobby_joined.emit(lobby_id, peer_id, player_list)
	
