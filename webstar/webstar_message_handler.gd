## Message handling system for WebStar networking
## Handles system messages and routing for the networking stack
class_name WebStarMessageHandler
extends RefCounted

var system_message_handlers: Dictionary = {}

func _init():
	_setup_system_handlers()

func _setup_system_handlers():
	"""Setup handlers for system messages."""
	system_message_handlers = {
		"system_heartbeat": _handle_heartbeat,
		"system_heartbeat_response": _handle_heartbeat_response,
		"system_host_migration": _handle_host_migration_message,
		"system_player_state": _handle_player_state,
		"system_connection_test": _handle_connection_test,
		"system_sync_request": _handle_sync_request,
		"system_game_state": _handle_game_state_sync
	}

func handle_message(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle incoming system messages."""
	if not data.has("message_name"):
		return
	
	var message_name = data.message_name
	var message_data = data.get("data", {})
	
	if system_message_handlers.has(message_name):
		system_message_handlers[message_name].call(sender_id, message_data, webstar_manager)

# System message handlers
func _handle_heartbeat(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle heartbeat messages."""
	if not webstar_manager.heartbeat_manager:
		return
	
	var timestamp = data.get("timestamp", 0)
	webstar_manager.heartbeat_manager.handle_heartbeat_received(sender_id, timestamp)

func _handle_heartbeat_response(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle heartbeat response messages."""
	if not webstar_manager.heartbeat_manager:
		return
	
	var original_timestamp = data.get("original_timestamp", 0)
	webstar_manager.heartbeat_manager.handle_heartbeat_response(sender_id, original_timestamp)

func _handle_host_migration_message(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle host migration related messages."""
	var migration_type = data.get("type", "")
	
	match migration_type:
		"migration_started":
			var new_host_id = data.get("new_host_id", 0)
			if webstar_manager.host_migration:
				webstar_manager.host_migration.start_migration(new_host_id)
		
		"migration_completed":
			# Host migration completed notification
			pass
		
		"request_state_sync":
			# New host requesting game state synchronization
			if webstar_manager.is_host:
				_send_game_state_sync(webstar_manager)

func _handle_player_state(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle player state updates."""
	var state_type = data.get("type", "")
	
	match state_type:
		"player_joined":
			# Handle player joining notification
			pass
		
		"player_left":
			# Handle player leaving notification
			pass
		
		"player_ready":
			# Handle player ready state
			pass

func _handle_connection_test(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle connection test messages."""
	var test_type = data.get("type", "")
	
	match test_type:
		"ping":
			# Respond to ping
			var response_data = {
				"type": "pong",
				"original_timestamp": data.get("timestamp", 0),
				"timestamp": Time.get_ticks_msec()
			}
			webstar_manager.send_message(sender_id, "system_connection_test", response_data)
		
		"pong":
			# Handle pong response
			var original_timestamp = data.get("original_timestamp", 0)
			var round_trip_time = Time.get_ticks_msec() - original_timestamp
			print("Connection test to player ", sender_id, ": ", round_trip_time, "ms")

func _handle_sync_request(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle synchronization requests."""
	if not webstar_manager.is_host:
		return
	
	var sync_type = data.get("type", "")
	
	match sync_type:
		"full_state":
			# Send full game state to requesting player
			_send_game_state_sync(webstar_manager, sender_id)
		
		"player_list":
			# Send current player list
			_send_player_list_sync(webstar_manager, sender_id)

func _handle_game_state_sync(sender_id: int, data: Dictionary, webstar_manager: WebStarManager):
	"""Handle game state synchronization."""
	if webstar_manager.is_host:
		return  # Host doesn't receive state sync
	
	var sync_type = data.get("type", "")
	
	match sync_type:
		"full_state":
			# Apply full game state
			var game_state = data.get("game_state", {})
			_apply_game_state(game_state, webstar_manager)
		
		"player_list":
			# Update player list
			var player_list = data.get("player_list", [])
			_apply_player_list_update(player_list, webstar_manager)

# Helper methods
func _send_game_state_sync(webstar_manager: WebStarManager, target_player_id: int = -1):
	"""Send game state synchronization to players."""
	var game_state = _collect_game_state(webstar_manager)
	
	var sync_data = {
		"type": "full_state",
		"game_state": game_state,
		"timestamp": Time.get_ticks_msec()
	}
	
	if target_player_id > 0:
		webstar_manager.send_message(target_player_id, "system_game_state", sync_data)
	else:
		webstar_manager.broadcast_message("system_game_state", sync_data)

func _send_player_list_sync(webstar_manager: WebStarManager, target_player_id: int):
	"""Send player list synchronization."""
	var player_list = []
	
	for player_id in webstar_manager.players:
		var player_info = webstar_manager.players[player_id]
		player_list.append({
			"player_id": player_id,
			"username": player_info.username,
			"state": player_info.state,
			"ping": player_info.ping
		})
	
	var sync_data = {
		"type": "player_list",
		"player_list": player_list,
		"timestamp": Time.get_ticks_msec()
	}
	
	webstar_manager.send_message(target_player_id, "system_game_state", sync_data)

func _collect_game_state(webstar_manager: WebStarManager) -> Dictionary:
	"""Collect current game state for synchronization."""
	# This should be implemented based on your game's specific state
	# For now, return basic state information
	return {
		"lobby_id": webstar_manager.lobby_id,
		"host_player_id": webstar_manager.host_player_id,
		"player_count": webstar_manager.get_player_count(),
		"game_time": Time.get_ticks_msec()
	}

func _apply_game_state(game_state: Dictionary, webstar_manager: WebStarManager):
	"""Apply received game state."""
	# This should be implemented based on your game's specific state
	# For now, just update basic information
	if game_state.has("host_player_id"):
		webstar_manager.host_player_id = game_state.host_player_id
		webstar_manager.is_host = (webstar_manager.host_player_id == webstar_manager.local_player_id)

func _apply_player_list_update(player_list: Array, webstar_manager: WebStarManager):
	"""Apply player list update."""
	# Update local player list with received data
	for player_data in player_list:
		var player_id = player_data.get("player_id", 0)
		if webstar_manager.players.has(player_id):
			var player_info = webstar_manager.players[player_id]
			player_info.username = player_data.get("username", player_info.username)
			player_info.ping = player_data.get("ping", player_info.ping)

# Utility methods for custom message handling
func register_custom_handler(message_name: String, handler: Callable):
	"""Register a custom message handler."""
	system_message_handlers[message_name] = handler

func unregister_custom_handler(message_name: String):
	"""Unregister a custom message handler."""
	system_message_handlers.erase(message_name)

func send_connection_test(webstar_manager: WebStarManager, target_player_id: int):
	"""Send a connection test ping to a player."""
	var ping_data = {
		"type": "ping",
		"timestamp": Time.get_ticks_msec()
	}
	
	webstar_manager.send_message(target_player_id, "system_connection_test", ping_data)

func request_game_state_sync(webstar_manager: WebStarManager):
	"""Request game state synchronization from host."""
	if webstar_manager.is_host:
		return
	
	var sync_request = {
		"type": "full_state"
	}
	
	webstar_manager.send_message(webstar_manager.host_player_id, "system_sync_request", sync_request)
