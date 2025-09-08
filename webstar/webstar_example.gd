## WebStar Networking Example
## Demonstrates how to use the WebStar networking system
extends Node

@export var lobby_id: String = "test_lobby"
@export var username: String = "Player"
@export var signaling_server_url: String = "ws://localhost:8080/ws"

var webstar_manager: WebStarManager
var webstar_config: WebStarConfig
var multiplayer_api: WebStarMultiplayerAPI

# UI References (connect these in the editor)
@onready var status_label: Label = $UI/StatusLabel
@onready var players_list: ItemList = $UI/PlayersList
@onready var connect_button: Button = $UI/ConnectButton
@onready var start_game_button: Button = $UI/StartGameButton
@onready var message_input: LineEdit = $UI/MessageInput
@onready var send_button: Button = $UI/SendButton
@onready var chat_log: TextEdit = $UI/ChatLog

func _ready():
	# Create and configure WebStar
	_setup_webstar()
	
	# Connect UI signals
	_setup_ui()
	
	# Optional: Use high-level multiplayer integration
	_setup_multiplayer_api()

func _setup_webstar():
	"""Initialize WebStar networking."""
	# Create configuration
	webstar_config = WebStarConfig.new()
	webstar_config.set_signaling_server(signaling_server_url)
	webstar_config.enable_debug_mode()
	
	# Add TURN server if available
	# webstar_config.add_turn_server("turn:your-server.com:3478", "username", "password")
	
	# Create WebStar manager
	webstar_manager = WebStarManager.new(webstar_config)
	
	# Connect signals
	webstar_manager.lobby_joined.connect(_on_lobby_joined)
	webstar_manager.lobby_left.connect(_on_lobby_left)
	webstar_manager.player_joined.connect(_on_player_joined)
	webstar_manager.player_left.connect(_on_player_left)
	webstar_manager.host_changed.connect(_on_host_changed)
	webstar_manager.game_started.connect(_on_game_started)
	webstar_manager.message_received.connect(_on_message_received)
	webstar_manager.connection_failed.connect(_on_connection_failed)

func _setup_ui():
	"""Setup UI connections."""
	if connect_button:
		connect_button.pressed.connect(_on_connect_pressed)
	
	if start_game_button:
		start_game_button.pressed.connect(_on_start_game_pressed)
		start_game_button.disabled = true
	
	if send_button:
		send_button.pressed.connect(_on_send_message_pressed)
	
	if message_input:
		message_input.text_submitted.connect(_on_message_submitted)

func _setup_multiplayer_api():
	"""Setup high-level multiplayer API integration."""
	multiplayer_api = WebStarMultiplayerAPI.new(webstar_manager)
	
	# Set as the multiplayer API for this scene tree
	# get_tree().set_multiplayer(multiplayer_api)
	
	# Connect multiplayer API signals
	multiplayer_api.peer_connected_api.connect(_on_peer_connected_api)
	multiplayer_api.peer_disconnected_api.connect(_on_peer_disconnected_api)

# UI Event Handlers
func _on_connect_pressed():
	"""Handle connect button press."""
	if webstar_manager.is_connected:
		# Disconnect
		webstar_manager.leave_lobby()
		connect_button.text = "Connect"
	else:
		# Connect
		_update_status("Connecting to lobby...")
		var success = await webstar_manager.join_lobby(lobby_id, username)
		
		if not success:
			_update_status("Failed to connect to lobby")

func _on_start_game_pressed():
	"""Handle start game button press."""
	if webstar_manager.is_host:
		webstar_manager.start_game()

func _on_send_message_pressed():
	"""Handle send message button press."""
	_send_chat_message()

func _on_message_submitted(text: String):
	"""Handle message input submission."""
	_send_chat_message()

func _send_chat_message():
	"""Send a chat message."""
	if not message_input or not webstar_manager.is_connected:
		return
	
	var message_text = message_input.text.strip_edges()
	if message_text == "":
		return
	
	# Send chat message to all players
	webstar_manager.broadcast_message("chat_message", {
		"text": message_text,
		"username": username
	})
	
	# Add to local chat log
	_add_chat_message(username + " (You)", message_text)
	
	# Clear input
	message_input.text = ""

# WebStar Event Handlers
func _on_lobby_joined(p_lobby_id: String, player_id: int):
	"""Handle lobby joined."""
	_update_status("Connected to lobby: " + p_lobby_id + " (Player ID: " + str(player_id) + ")")
	connect_button.text = "Disconnect"
	
	# Enable start game button if we're the host
	if webstar_manager.is_host:
		start_game_button.disabled = false
		start_game_button.text = "Start Game"
	else:
		start_game_button.disabled = true
		start_game_button.text = "Waiting for Host"
	
	_update_players_list()

func _on_lobby_left():
	"""Handle lobby left."""
	_update_status("Disconnected from lobby")
	connect_button.text = "Connect"
	start_game_button.disabled = true
	_clear_players_list()

func _on_player_joined(player_id: int, player_info: Dictionary):
	"""Handle player joined."""
	var player_name = player_info.get("username", "Player " + str(player_id))
	_add_chat_message("System", player_name + " joined the lobby")
	_update_players_list()

func _on_player_left(player_id: int):
	"""Handle player left."""
	_add_chat_message("System", "Player " + str(player_id) + " left the lobby")
	_update_players_list()

func _on_host_changed(new_host_id: int):
	"""Handle host change."""
	_add_chat_message("System", "Host changed to Player " + str(new_host_id))
	
	# Update start game button
	if webstar_manager.is_host:
		start_game_button.disabled = false
		start_game_button.text = "Start Game"
	else:
		start_game_button.disabled = true
		start_game_button.text = "Waiting for Host"

func _on_game_started():
	"""Handle game started."""
	_add_chat_message("System", "Game started!")
	start_game_button.text = "Game Running"

func _on_message_received(sender_id: int, message_name: String, data: Dictionary):
	"""Handle messages received from other players."""
	match message_name:
		"chat_message":
			var text = data.get("text", "")
			var sender_username = data.get("username", "Player " + str(sender_id))
			_add_chat_message(sender_username, text)
		
		"game_action":
			# Handle game-specific actions
			_handle_game_action(sender_id, data)
		
		_:
			print("Unknown message type: ", message_name, " from player ", sender_id)

func _on_connection_failed(player_id: int, reason: String):
	"""Handle connection failure."""
	_add_chat_message("System", "Connection failed with Player " + str(player_id) + ": " + reason)

# High-level Multiplayer API Handlers
func _on_peer_connected_api(peer_id: int):
	"""Handle peer connected through multiplayer API."""
	print("Godot Multiplayer API: Peer connected: ", peer_id)

func _on_peer_disconnected_api(peer_id: int):
	"""Handle peer disconnected through multiplayer API."""
	print("Godot Multiplayer API: Peer disconnected: ", peer_id)

# Game-specific message handling
func _handle_game_action(sender_id: int, data: Dictionary):
	"""Handle game-specific actions."""
	var action_type = data.get("action", "")
	
	match action_type:
		"move":
			# Handle player movement
			var position = data.get("position", Vector2.ZERO)
			print("Player ", sender_id, " moved to: ", position)
		
		"attack":
			# Handle player attack
			var target = data.get("target", Vector2.ZERO)
			print("Player ", sender_id, " attacked: ", target)
		
		_:
			print("Unknown game action: ", action_type)

# UI Helper Methods
func _update_status(text: String):
	"""Update status label."""
	if status_label:
		status_label.text = text
	print("Status: ", text)

func _update_players_list():
	"""Update the players list UI."""
	if not players_list:
		return
	
	players_list.clear()
	
	var connected_players = webstar_manager.get_connected_players()
	for player_id in connected_players:
		var player_info = webstar_manager.get_player_info(player_id)
		var display_text = ""
		
		if player_info:
			display_text = player_info.username
			if player_id == webstar_manager.host_player_id:
				display_text += " (Host)"
			if player_id == webstar_manager.local_player_id:
				display_text += " (You)"
			
			var ping = webstar_manager.get_ping(player_id)
			if ping >= 0:
				display_text += " - " + str(ping) + "ms"
		else:
			display_text = "Player " + str(player_id)
		
		players_list.add_item(display_text)

func _clear_players_list():
	"""Clear the players list UI."""
	if players_list:
		players_list.clear()

func _add_chat_message(sender: String, message: String):
	"""Add a message to the chat log."""
	if not chat_log:
		return
	
	var timestamp = Time.get_datetime_string_from_system().split(" ")[1]  # Get time part
	var formatted_message = "[" + timestamp + "] " + sender + ": " + message + "\n"
	
	chat_log.text += formatted_message
	
	# Auto-scroll to bottom
	chat_log.scroll_vertical = chat_log.get_line_count()

# Example game functions using WebStar
func send_player_movement(new_position: Vector2):
	"""Example: Send player movement to other players."""
	webstar_manager.broadcast_message("game_action", {
		"action": "move",
		"position": new_position
	})

func send_player_attack(target_position: Vector2):
	"""Example: Send player attack to other players."""
	webstar_manager.broadcast_message("game_action", {
		"action": "attack",
		"target": target_position
	})

# Example RPC function using high-level multiplayer
@rpc("any_peer", "call_local")
func player_did_something(data: Dictionary):
	"""Example RPC function."""
	print("Player did something: ", data)

func _input(event):
	"""Handle input for testing."""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				# Test movement
				send_player_movement(Vector2(randf() * 100, randf() * 100))
			
			KEY_2:
				# Test attack
				send_player_attack(Vector2(randf() * 100, randf() * 100))
			
			KEY_3:
				# Test RPC (if multiplayer API is set up)
				if multiplayer_api and multiplayer_api.is_connected():
					player_did_something.rpc({"test": "data"})

func _exit_tree():
	"""Clean up when exiting."""
	if webstar_manager and webstar_manager.is_connected:
		webstar_manager.leave_lobby()
