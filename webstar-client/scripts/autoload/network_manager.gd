extends Node

var server_address = "127.0.0.1"
var server_port = 5090
var use_enet = false  # Set to false to use WebStar, true to use ENet
var lobby_name = "client-server-knights"

signal lobby_created
signal lobby_joined



func _ready():
	# not sure if need this, leaving it for now
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# connect to the lobby server
	# todo: handle errors.  should retry?  if so, how many times to retry, etc?
	await Webstar.connect_to_lobby_server()
	
	
	# when running a dedicated server, connect to signal-server and create a lobby
	# the lobby will be used to detect when peers join so that we can initiate WebRTC them
	# todo: get lobby name from command-line
	if DisplayServer.get_name() == "headless":
		print("starting headless server, creating lobby: %s" % lobby_name)
		Webstar.create_lobby(lobby_name, 32, true)
	
	

# =============================================================================
# Public Methods
# =============================================================================		


	
	
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
	

func _on_server_disconnected():
	print("server disconnected")
	

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


func _on_webrtc_connection_state_changed(player_id: int, state: String):
	print("WebRTC connection to player %d changed to: %s" % [player_id, state])


func _on_webrtc_ready():
	pass
	
func _try_set_multiplayer_peer():
	pass
