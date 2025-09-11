## WebStar Networking Manager
## Implements WebRTC star topology similar to GDevelop
## Uses WebSocket for signaling and optional relay fallback
@tool
extends Node

signal player_joined(player_id: int, player_info: Dictionary)
signal player_left(player_id: int)
signal host_changed(new_host_id: int)
signal connection_failed(player_id: int, reason: String)
signal lobby_joined(lobby_id: String, player_number: int)
signal lobby_left()
signal game_started()
signal game_ended()
signal message_received(sender_id: int, message_name: String, data: Dictionary)

enum ConnectionType {
	WEBRTC,
	WEBSOCKET_RELAY
}

enum PlayerState {
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	RECONNECTING
}

class PlayerInfo:
	var player_id: int
	var peer_id: String
	var username: String
	var ping: int = 0
	var state: PlayerState = PlayerState.DISCONNECTED
	var connection_type: ConnectionType = ConnectionType.WEBRTC
	
	func _init(p_id: int, p_peer_id: String = "", p_username: String = ""):
		player_id = p_id
		peer_id = p_peer_id
		username = p_username

# Core components
var signaling_client: WebStarSignalingClient
var webrtc_manager: WebStarWebRTCManager
var relay_manager: WebStarRelayManager
var heartbeat_manager: WebStarHeartbeatManager
var host_migration: WebStarHostMigration
var message_handler: WebStarMessageHandler
var multiplayer_peer: WebRTCMultiplayerPeer

# State
var lobby_id: String = ""
var local_player_id: int = 0
var host_player_id: int = 0
var is_host: bool = false
var is_connected: bool = false
var players: Dictionary = {} # player_id -> PlayerInfo
var config: WebStarConfig

# Callbacks
var connection_callbacks: Dictionary = {}

func _ready():
	print("[WebStar] starting webstar_manager")
	if not config:
		config = WebStarConfig.new()
	_initialize_components()

func initialize_with_config(p_config: WebStarConfig):
	config = p_config
	if is_inside_tree():
		_initialize_components()

func _initialize_components():
	# Load component scripts
	var SignalingClientScript = preload("res://addons/webstar/webstar_signaling_client.gd")
	var WebRTCManagerScript = preload("res://addons/webstar/webstar_webrtc_manager.gd")
	var RelayManagerScript = preload("res://addons/webstar/webstar_relay_manager.gd")
	var HeartbeatManagerScript = preload("res://addons/webstar/webstar_heartbeat_manager.gd")
	var HostMigrationScript = preload("res://addons/webstar/webstar_host_migration.gd")
	var MessageHandlerScript = preload("res://addons/webstar/webstar_message_handler.gd")
	
	# Initialize all components
	signaling_client = SignalingClientScript.new(config)
	webrtc_manager = WebRTCManagerScript.new(config)
	relay_manager = RelayManagerScript.new(config)
	heartbeat_manager = HeartbeatManagerScript.new(config)
	host_migration = HostMigrationScript.new(config)
	message_handler = MessageHandlerScript.new()
	
	# Get the WebRTC multiplayer peer from the WebRTC manager
	multiplayer_peer = webrtc_manager.multiplayer_peer
	
	# Add as children for proper lifecycle management
	add_child(signaling_client)
	add_child(webrtc_manager)
	add_child(relay_manager)
	add_child(heartbeat_manager)
	add_child(host_migration)
	add_child(message_handler)
	
	# Set up multiplayer peer for scene tree (optional - can be done by user)
	# get_tree().set_multiplayer(SceneMultiplayer.new(), self.get_path())
	# get_tree().get_multiplayer().multiplayer_peer = multiplayer_peer
	
	# Connect signals
	_connect_component_signals()

func _connect_component_signals():
	# Signaling client signals
	signaling_client.lobby_joined.connect(_on_lobby_joined)
	signaling_client.peer_id_received.connect(_on_peer_id_received)
	signaling_client.game_started.connect(_on_game_started)
	signaling_client.player_list_updated.connect(_on_player_list_updated)
	signaling_client.host_migration_requested.connect(_on_host_migration_requested)
	
	# WebRTC manager signals
	webrtc_manager.peer_connected.connect(_on_peer_connected)
	webrtc_manager.peer_disconnected.connect(_on_peer_disconnected)
	webrtc_manager.connection_failed.connect(_on_connection_failed)
	webrtc_manager.data_received.connect(_on_data_received)
	
	# Relay manager signals
	relay_manager.peer_connected.connect(_on_relay_peer_connected)
	relay_manager.peer_disconnected.connect(_on_relay_peer_disconnected)
	relay_manager.data_received.connect(_on_relay_data_received)
	
	# Heartbeat manager signals
	heartbeat_manager.peer_timeout.connect(_on_peer_timeout)
	heartbeat_manager.ping_updated.connect(_on_ping_updated)
	
	# Host migration signals
	host_migration.migration_started.connect(_on_migration_started)
	host_migration.migration_completed.connect(_on_migration_completed)
	host_migration.migration_failed.connect(_on_migration_failed)

# Public API
func join_lobby(lobby_id: String, username: String = "Player") -> bool:
	if is_connected:
		push_warning("Already connected to a lobby")
		return false
	
	self.lobby_id = lobby_id
	return await signaling_client.join_lobby(lobby_id, username)

func leave_lobby():
	if not is_connected:
		return
	
	_cleanup_connections()
	signaling_client.leave_lobby()
	is_connected = false
	lobby_left.emit()

func start_game() -> bool:
	if not is_host:
		push_warning("Only host can start the game")
		return false
	
	return signaling_client.start_game()

func send_message(target_player_id: int, message_name: String, data: Dictionary = {}):
	if not is_connected:
		push_warning("Not connected to lobby")
		return
	
	var message_data = {
		"message_name": message_name,
		"data": data,
		"sender_id": local_player_id,
		"timestamp": Time.get_ticks_msec()
	}
	
	if target_player_id == -1:  # Broadcast to all
		_send_to_all_players(message_data)
	else:
		_send_to_player(target_player_id, message_data)

func broadcast_message(message_name: String, data: Dictionary = {}):
	send_message(-1, message_name, data)

func get_player_count() -> int:
	return players.size()

func get_player_info(player_id: int) -> PlayerInfo:
	return players.get(player_id)

func get_connected_players() -> Array[int]:
	var connected: Array[int] = []
	for player_id in players:
		var player_info: PlayerInfo = players[player_id]
		if player_info.state == PlayerState.CONNECTED:
			connected.append(player_id)
	return connected

func is_player_connected(player_id: int) -> bool:
	var player_info = players.get(player_id)
	return player_info != null and player_info.state == PlayerState.CONNECTED

func get_ping(player_id: int) -> int:
	var player_info = players.get(player_id)
	return player_info.ping if player_info else -1

# High-level networking integration
func get_multiplayer_peer() -> WebRTCMultiplayerPeer:
	return multiplayer_peer

func setup_high_level_networking() -> bool:
	if not multiplayer_peer:
		push_error("Multiplayer peer not initialized")
		return false
	
	# Set the multiplayer peer on the scene tree
	get_tree().set_multiplayer(SceneMultiplayer.new(), NodePath("/root"))
	get_tree().get_multiplayer().multiplayer_peer = multiplayer_peer
	
	print("[WebStar] High-level networking configured")
	return true

func get_player_list() -> Dictionary:
	return players.duplicate()

func send_message_to_player(player_id: int, message_name: String, data: Dictionary):
	var message_data = {
		"message_name": message_name,
		"data": data,
		"sender_id": local_player_id,
		"timestamp": Time.get_ticks_msec()
	}
	_send_to_player(player_id, message_data)

func send_message_to_all(message_name: String, data: Dictionary):
	var message_data = {
		"message_name": message_name, 
		"data": data,
		"sender_id": local_player_id,
		"timestamp": Time.get_ticks_msec()
	}
	_send_to_all_players(message_data)

func disconnect_player(player_id: int):
	if players.has(player_id):
		var player_info = players[player_id]
		match player_info.connection_type:
			ConnectionType.WEBRTC:
				webrtc_manager.disconnect_peer(player_info.peer_id)
			ConnectionType.WEBSOCKET_RELAY:
				relay_manager.disconnect_peer(player_id)
		return player_info.ping
	return -1

# Internal methods
func _send_to_all_players(data: Dictionary):
	if is_host:
		# Host relays to all other players
		for player_id in players:
			if player_id != local_player_id:
				_send_to_player(player_id, data)
	else:
		# Non-host sends to host only
		_send_to_player(host_player_id, data)

func _send_to_player(player_id: int, data: Dictionary):
	var player_info = players.get(player_id)
	if not player_info or player_info.state != PlayerState.CONNECTED:
		return
	
	match player_info.connection_type:
		ConnectionType.WEBRTC:
			webrtc_manager.send_data(player_info.peer_id, data)
		ConnectionType.WEBSOCKET_RELAY:
			relay_manager.send_data(player_id, data)

func _cleanup_connections():
	if webrtc_manager:
		webrtc_manager.disconnect_all()
	if relay_manager:
		relay_manager.disconnect_all()
	if heartbeat_manager:
		heartbeat_manager.stop_all()
	players.clear()
	local_player_id = 0
	host_player_id = 0
	is_host = false

# Signal handlers
func _on_lobby_joined(p_lobby_id: String, player_id: int, player_list: Array):
	lobby_id = p_lobby_id
	local_player_id = player_id
	is_connected = true
	
	# Update player list
	for player_data in player_list:
		var player_info = PlayerInfo.new(
			player_data.player_id,
			player_data.get("peer_id", ""),
			player_data.get("username", "Player " + str(player_data.player_id))
		)
		players[player_data.player_id] = player_info
	
	# Determine host (lowest player ID)
	var player_ids = players.keys()
	player_ids.sort()
	host_player_id = player_ids[0]
	is_host = (host_player_id == local_player_id)
	
	lobby_joined.emit(lobby_id, player_id)

func _on_peer_id_received(player_id: int, peer_id: String):
	var player_info = players.get(player_id)
	if player_info:
		player_info.peer_id = peer_id
		player_info.state = PlayerState.CONNECTING
		
		# If we're not the host and this is the host's peer ID, connect to them
		if not is_host and player_id == host_player_id:
			webrtc_manager.connect_to_peer(peer_id, player_id)
		# If we're the host, wait for them to connect to us
		elif is_host:
			# Host waits for incoming connections
			pass

func _on_game_started():
	heartbeat_manager.start_heartbeats()
	game_started.emit()

func _on_player_list_updated(player_list: Array):
	# Handle players joining/leaving
	var current_player_ids = Set.new(players.keys())
	var new_player_ids = Set.new()
	
	for player_data in player_list:
		new_player_ids.add(player_data.player_id)
		
		if not players.has(player_data.player_id):
			# New player joined
			var player_info = PlayerInfo.new(
				player_data.player_id,
				player_data.get("peer_id", ""),
				player_data.get("username", "Player " + str(player_data.player_id))
			)
			players[player_data.player_id] = player_info
			player_joined.emit(player_data.player_id, player_data)
	
	# Check for players who left
	for player_id in current_player_ids.difference(new_player_ids):
		players.erase(player_id)
		if webrtc_manager:
			webrtc_manager.disconnect_peer(str(player_id))
		player_left.emit(player_id)

func _on_host_migration_requested(new_host_id: int):
	if host_migration:
		host_migration.start_migration(new_host_id)

func _on_peer_connected(peer_id: String, player_id: int):
	var player_info = players.get(player_id)
	if player_info:
		player_info.state = PlayerState.CONNECTED
		player_info.connection_type = ConnectionType.WEBRTC
		if heartbeat_manager:
			heartbeat_manager.start_heartbeat_for_player(player_id)
		print("WebRTC connection established with player ", player_id)

func _on_peer_disconnected(peer_id: String, player_id: int):
	var player_info = players.get(player_id)
	if player_info:
		player_info.state = PlayerState.DISCONNECTED
		if heartbeat_manager:
			heartbeat_manager.stop_heartbeat_for_player(player_id)
		
		# Try to reconnect or fallback to relay
		_handle_peer_disconnection(player_id)

func _on_connection_failed(peer_id: String, player_id: int, reason: String):
	print("WebRTC connection failed for player ", player_id, ": ", reason)
	
	# Fallback to WebSocket relay
	if config.use_websocket_fallback:
		_fallback_to_websocket_relay(player_id)
	else:
		connection_failed.emit(player_id, reason)

func _on_relay_peer_connected(player_id: int):
	var player_info = players.get(player_id)
	if player_info:
		player_info.state = PlayerState.CONNECTED
		player_info.connection_type = ConnectionType.WEBSOCKET_RELAY
		if heartbeat_manager:
			heartbeat_manager.start_heartbeat_for_player(player_id)
		print("WebSocket relay connection established with player ", player_id)

func _on_relay_peer_disconnected(player_id: int):
	var player_info = players.get(player_id)
	if player_info:
		player_info.state = PlayerState.DISCONNECTED
		if heartbeat_manager:
			heartbeat_manager.stop_heartbeat_for_player(player_id)

func _on_relay_data_received(sender_id: int, data: Dictionary):
	_handle_received_data(sender_id, data)

func _on_data_received(peer_id: String, player_id: int, data: Dictionary):
	_handle_received_data(player_id, data)

func _handle_received_data(sender_id: int, data: Dictionary):
	if data.has("message_name"):
		# User message
		message_received.emit(sender_id, data.message_name, data.get("data", {}))
	else:
		# System message - let message handler process it
		if message_handler:
			message_handler.handle_message(sender_id, data, self)

func _on_peer_timeout(player_id: int):
	print("Player ", player_id, " timed out")
	_handle_peer_disconnection(player_id)

func _on_ping_updated(player_id: int, ping: int):
	var player_info = players.get(player_id)
	if player_info:
		player_info.ping = ping

func _handle_peer_disconnection(player_id: int):
	# If host disconnected, trigger host migration
	if player_id == host_player_id and config.enable_host_migration:
		var new_host_candidates = get_connected_players()
		new_host_candidates.erase(player_id)
		if new_host_candidates.size() > 0:
			new_host_candidates.sort()
			var new_host_id = new_host_candidates[0]
			if host_migration:
				host_migration.start_migration(new_host_id)
	
	# Try to reconnect
	if config.auto_reconnect:
		_attempt_reconnection(player_id)

func _attempt_reconnection(player_id: int):
	var player_info = players.get(player_id)
	if not player_info:
		return
	
	player_info.state = PlayerState.RECONNECTING
	
	# Try WebRTC first, then fallback to relay
	if player_info.peer_id != "":
		webrtc_manager.connect_to_peer(player_info.peer_id, player_id)
	else:
		_fallback_to_websocket_relay(player_id)

func _fallback_to_websocket_relay(player_id: int):
	print("Falling back to WebSocket relay for player ", player_id)
	if relay_manager:
		relay_manager.connect_to_player(player_id)

func _on_migration_started(new_host_id: int):
	print("Host migration started, new host: ", new_host_id)

func _on_migration_completed(new_host_id: int):
	host_player_id = new_host_id
	is_host = (new_host_id == local_player_id)
	host_changed.emit(new_host_id)
	print("Host migration completed, new host: ", new_host_id)

func _on_migration_failed(reason: String):
	print("Host migration failed: ", reason)
	# Handle migration failure - might need to leave lobby
	leave_lobby()

# Helper class for set operations
class Set:
	var data: Dictionary = {}
	
	func _init(array: Array = []):
		for item in array:
			data[item] = true
	
	func add(item):
		data[item] = true
	
	func has(item) -> bool:
		return data.has(item)
	
	func difference(other: Set) -> Array:
		var result = []
		for item in data:
			if not other.has(item):
				result.append(item)
		return result
