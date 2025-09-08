extends Node2D

## Simple WebStar Demo
## Shows basic lobby joining and messaging functionality

func _ready():
	print("=== WebStar Demo Starting ===")
	
	# Initialize WebStar with default config
	WebStar.initialize()
	
	# Connect to signals for demo
	WebStar.lobby_joined.connect(_on_lobby_joined)
	WebStar.message_received.connect(_on_message_received)
	WebStar.lobby_left.connect(_on_lobby_left)
	WebStar.connection_failed.connect(_on_connection_failed)
	
	# Demo: Join a lobby
	await get_tree().create_timer(1.0).timeout
	print("Attempting to join demo lobby...")
	var success = await WebStar.join_lobby("demo-lobby", "DemoPlayer")
	
	if success:
		print("✅ Successfully joined lobby!")
		# Send a test message after joining
		await get_tree().create_timer(2.0).timeout
		WebStar.send_message({"type": "demo_message", "text": "Hello from Godot!"})
	else:
		print("❌ Failed to join lobby")

func _on_lobby_joined(lobby_id: String, player_id: int, player_list: Array):
	print("🎉 Joined lobby: ", lobby_id, " as player: ", player_id)
	print("Players in lobby: ", player_list.size())

func _on_message_received(data):
	print("📨 Received message: ", data)

func _on_lobby_left():
	print("👋 Left the lobby")

func _on_connection_failed(message: String):
	print("💥 Connection failed: ", message)
