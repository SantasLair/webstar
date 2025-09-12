extends Node

var server_address = "127.0.0.1"
var server_port = 5090
var use_enet = false  # Set to false to use WebStar, true to use ENet

signal lobby_created
signal lobby_joined


# WebStar specific settings
var webstar: WebstarManager = null
var status = ""

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Initialize WebStar if not using ENet
	if not use_enet:
		webstar = WebstarManager
		webstar.lobby_created.connect(_on_lobby_created)
		webstar.connect_to_signaling_server_async()

# =============================================================================
# Public Methods
# =============================================================================

## Create a lobby
##
## emits signal lobby_created 
# todo: add error handling, create_lobby_failed
func create_lobby(lobby_name):
	print("creating lobby %s" % [lobby_name])
	
	if use_enet:
		# ENet implementation
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_server(server_port, 32)
		if error:
			print("error creating lobby")
		else:
			multiplayer.multiplayer_peer = peer
			status = "created lobby"
			print("lobby created")
	else:		
		webstar.create_lobby(lobby_name, 8, false)
		

## Join a lobby
##
## emits signal lobby_joined
# todo: add error handling, lobby_join_failed
func join_lobby(lobby_name):
	print("joining lobby %s" % [lobby_name])
	
	if use_enet:
		# ENet implementation
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_client(server_address, server_port)
		if error:
			print("error connecting to lobby")
		else:
			multiplayer.multiplayer_peer = peer
			status = "connecting to lobby"
	else:		
		status = "joining WebStar lobby..."
		var success = await webstar.join_lobby(lobby_name)
		if success:
			status = "joined WebStar lobby - waiting for WebRTC"
			print("WebStar lobby joined, waiting for WebRTC connections")
		else:
			status = "WebStar join failed"
			print("ERROR: Failed to join WebStar lobby")
	
	
func leave():
	if use_enet:
		# ENet cleanup
		multiplayer.multiplayer_peer = null
	else:
		webstar.leave_lobby()
		multiplayer.multiplayer_peer = null
	
	status = ""
	%NetworkUI._update_controls()

	
# =============================================================================
# Signal Handlers
# =============================================================================

func _on_lobby_created(_lobby_id, _peer_id):
	lobby_created.emit()	
	

# ENet event handlers
func _on_player_connected(id):
	print("player %s connected" % [id])
	

func _on_player_disconnected(id):
	print("player %s disconnected" % [id])
	

func _on_connected_fail():
	print("connection failed")
	status = ""
	

func _on_server_disconnected():
	print("server disconnected")
	status = ""
	

# WebStar event handlers
func _on_webstar_lobby_joined(lobby_id: String, player_number: int):
	print("WebStar lobby joined: %s, player: %d" % [lobby_id, player_number])
	
	# Check if we're alone in the lobby
	#if webstar_manager and webstar_manager.has_method("get_player_list"):
	#	var players = webstar_manager.get_player_list()
	#	if players.size() == 1:
	#		print("Single player in lobby - setting up WebSocket relay mode")
	#		status = "WebStar lobby (single player) - relay ready"
	#		# Could set up relay mode here if needed
	#	else:
	#		status = "WebStar lobby joined - waiting for WebRTC"
	#else:
	#	status = "connected to WebStar lobby"
	

func _on_webstar_player_joined(player_id: int, player_info: Dictionary):
	print("WebStar player joined: %d, info: %s" % [player_id, player_info])

func _on_webstar_player_left(player_id: int):
	print("WebStar player left: %d" % player_id)

func _on_webstar_connection_failed(reason: String):
	print("WebStar connection failed: %s" % reason)
	status = ""


func _on_webrtc_connection_state_changed(player_id: int, state: String):
	print("WebRTC connection to player %d changed to: %s" % [player_id, state])


func _on_webrtc_ready():
	pass
	
func _try_set_multiplayer_peer():
	pass
