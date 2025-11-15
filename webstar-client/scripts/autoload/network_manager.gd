extends Node

var server_address = "127.0.0.1"
var server_port = 5090
var use_enet = false  # Set to false to use WebStar, true to use ENet
var lobby_name = "client-server-knights"
var gamelift_manager = null

signal lobby_created
signal lobby_joined



func _ready():
	# not sure if need this, leaving it for now
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	
	# Initialize GameLift Manager for headless servers
	if DisplayServer.get_name() == "headless":
		_setup_gamelift_manager()
	
	# connect to the lobby server
	# todo: handle errors.  should retry?  if so, how many times to retry, etc?
	await Webstar.connect_to_lobby_server()
	
	
	# when running a dedicated server, connect to signal-server and create a lobby
	# the lobby will be used to detect when peers join so that we can initiate WebRTC them
	if DisplayServer.get_name() == "headless" and not gamelift_manager:
		print("starting headless server (non-GameLift), creating lobby: %s" % lobby_name)
		Webstar.create_lobby(lobby_name, 32, true)
	
	

# =============================================================================
# GameLift Integration
# =============================================================================

func _setup_gamelift_manager():
	print("Setting up GameLift Manager...")
	
	# Create GameLiftManager instance
	var gamelift_scene = preload("res://GameLift/GameLiftManager.tscn")
	gamelift_manager = gamelift_scene.instantiate()
	add_child(gamelift_manager)
	
	# Connect GameLift signals
	gamelift_manager.connect("game_lift_initialized", _on_gamelift_initialized)
	gamelift_manager.connect("game_session_started", _on_gamelift_session_started)
	gamelift_manager.connect("game_session_ended", _on_gamelift_session_ended)
	gamelift_manager.connect("player_session_created", _on_gamelift_player_session_created)
	gamelift_manager.connect("player_session_terminated", _on_gamelift_player_session_terminated)
	gamelift_manager.connect("game_lift_error", _on_gamelift_error)

func _on_gamelift_initialized():
	print("GameLift initialized successfully")

func _on_gamelift_session_started(game_session_id: String):
	print("GameLift session started: %s" % game_session_id)
	lobby_name = game_session_id
	# Create the lobby with GameLift session ID
	Webstar.create_lobby(lobby_name, gamelift_manager.MaxPlayers, true)

func _on_gamelift_session_ended(game_session_id: String):
	print("GameLift session ended: %s" % game_session_id)
	# Clean up lobby and connections
	# Todo: implement cleanup

func _on_gamelift_player_session_created(player_session_id: String, player_id: String):
	print("GameLift player session created: %s for player: %s" % [player_session_id, player_id])
	# Accept the player session in GameLift
	if gamelift_manager:
		gamelift_manager.AcceptPlayerSession(player_session_id)

func _on_gamelift_player_session_terminated(player_session_id: String, player_id: String):
	print("GameLift player session terminated: %s for player: %s" % [player_session_id, player_id])
	# Handle player disconnection cleanup here

func _on_gamelift_error(error: String):
	print("GameLift error: %s" % error)

# =============================================================================
# Public Methods
# =============================================================================		

# GameLift helper methods
func is_running_on_gamelift() -> bool:
	return gamelift_manager != null and gamelift_manager.IsInitialized

func get_gamelift_status() -> Dictionary:
	if gamelift_manager:
		return gamelift_manager.GetServerStatus()
	return {}

func accept_player_session(player_session_id: String) -> bool:
	if gamelift_manager:
		return gamelift_manager.AcceptPlayerSession(player_session_id)
	return false

func remove_player_session(player_session_id: String) -> bool:
	if gamelift_manager:
		return gamelift_manager.RemovePlayerSession(player_session_id)
	return false

func log_gamelift_event(event_name: String, event_data: Dictionary = {}):
	if gamelift_manager:
		gamelift_manager.LogGameEvent(event_name, event_data)
	
	
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
