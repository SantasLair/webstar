## Example usage of WebStar networking addon
extends Node

var webstar_manager: WebStarManager
var config: WebStarConfig

func _ready():
	# Create and configure WebStar
	config = WebStarConfig.new()
	config.signaling_server_url = "ws://localhost:8080/ws"
	config.relay_server_url = "ws://localhost:8080/relay"
	config.debug_logging = true
	
	# Use the autoload WebStar manager
	webstar_manager = WebStar
	webstar_manager.initialize_with_config(config)
	
	# Connect to signals
	webstar_manager.lobby_joined.connect(_on_lobby_joined)
	webstar_manager.player_joined.connect(_on_player_joined)
	webstar_manager.player_left.connect(_on_player_left)
	webstar_manager.message_received.connect(_on_message_received)
	webstar_manager.host_changed.connect(_on_host_changed)
	
	# Example: Join a lobby
	join_test_lobby()

func join_test_lobby():
	var lobby_id = "TEST123"
	var username = "Player_" + str(randi() % 1000)
	
	print("Joining lobby: ", lobby_id, " as ", username)
	var success = await webstar_manager.join_lobby(lobby_id, username)
	
	if success:
		print("Successfully joined lobby!")
	else:
		print("Failed to join lobby")

func _on_lobby_joined(lobby_id: String, player_id: int):
	print("Joined lobby: ", lobby_id, " with player ID: ", player_id)
	
	# Send a test message after 2 seconds
	await get_tree().create_timer(2.0).timeout
	send_test_message()

func _on_player_joined(player_id: int, player_info: Dictionary):
	print("Player joined: ", player_id, " - ", player_info.get("username", "Unknown"))

func _on_player_left(player_id: int):
	print("Player left: ", player_id)

func _on_message_received(sender_id: int, message_name: String, data: Dictionary):
	print("Received message '", message_name, "' from player ", sender_id, ": ", data)

func _on_host_changed(new_host_id: int):
	print("New host: ", new_host_id)
	if webstar_manager.local_player_id == new_host_id:
		print("I am now the host!")

func send_test_message():
	# Broadcast a test message to all players
	webstar_manager.broadcast_message("test_message", {
		"text": "Hello from " + str(webstar_manager.local_player_id),
		"timestamp": Time.get_ticks_msec()
	})

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				send_test_message()
			KEY_2:
				if webstar_manager.is_host:
					webstar_manager.start_game()
			KEY_3:
				webstar_manager.leave_lobby()
			KEY_4:
				join_test_lobby()

# Example of sending position updates (for a multiplayer game)
func send_position_update(position: Vector2):
	webstar_manager.broadcast_message("position_update", {
		"x": position.x,
		"y": position.y,
		"timestamp": Time.get_ticks_msec()
	})

# Example of handling position updates
func handle_position_update(sender_id: int, data: Dictionary):
	var position = Vector2(data.get("x", 0), data.get("y", 0))
	var timestamp = data.get("timestamp", 0)
	
	# Update player position in your game
	print("Player ", sender_id, " moved to: ", position)
