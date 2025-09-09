extends Node

## Multi-Client WebStar Test
## Tests multiple clients connecting to the same lobby

var clients: Array[Node] = []
var lobby_id: String = "multi-test-" + str(Time.get_ticks_msec())

func _ready():
	print("🔗 === Multi-Client WebStar Test ===")
	print("🏠 Testing lobby: %s" % lobby_id)
	
	# Create multiple test clients
	await create_test_clients(3)
	
	# Test messaging between clients
	await test_inter_client_messaging()
	
	# Cleanup
	await cleanup_all_clients()
	
	print("✅ Multi-client test completed!")
	get_tree().quit()

func create_test_clients(count: int):
	print("\n👥 Creating %d test clients..." % count)
	
	for i in range(count):
		var client = await create_client("Player" + str(i + 1))
		clients.append(client)
		
		# Small delay between connections
		await get_tree().create_timer(0.5).timeout
	
	print("✅ All clients connected!")

func create_client(username: String) -> Node:
	print("  🔌 Creating client: %s" % username)
	
	# Create a new WebStar manager instance for this client
	var WebStarManagerScript = preload("res://addons/webstar/webstar_manager.gd")
	var client_manager = WebStarManagerScript.new()
	
	add_child(client_manager)
	
	# Connect signals for monitoring
	client_manager.lobby_joined.connect(_on_client_lobby_joined.bind(username))
	client_manager.player_joined.connect(_on_client_player_joined.bind(username))
	client_manager.message_received.connect(_on_client_message_received.bind(username))
	
	# Wait for initialization
	await get_tree().create_timer(1.0).timeout
	
	# Join the test lobby
	var success = await client_manager.join_lobby(lobby_id, username)
	
	if success:
		print("  ✅ %s joined lobby successfully" % username)
	else:
		print("  ❌ %s failed to join lobby" % username)
	
	return client_manager

func test_inter_client_messaging():
	print("\n📡 Testing inter-client messaging...")
	
	if clients.size() < 2:
		print("  ⚠️ Need at least 2 clients for messaging test")
		return
	
	# Have each client send a message
	for i in range(clients.size()):
		var client = clients[i]
		var message = "Hello from client %d!" % (i + 1)
		
		client.broadcast_message("test_broadcast", {"message": message, "sender": i + 1})
		print("  📤 Client %d sent: %s" % [i + 1, message])
		
		await get_tree().create_timer(0.5).timeout
	
	# Wait for message processing
	await get_tree().create_timer(2.0).timeout

func cleanup_all_clients():
	print("\n🧹 Cleaning up all clients...")
	
	for client in clients:
		if client and is_instance_valid(client):
			client.leave_lobby()
			await get_tree().create_timer(0.2).timeout
			client.queue_free()
	
	clients.clear()
	print("✅ All clients cleaned up")

# Signal handlers
func _on_client_lobby_joined(username: String, _joined_lobby_id: String, player_number: int):
	print("  🎉 %s joined lobby as player %d" % [username, player_number])

func _on_client_player_joined(username: String, player_id: int, player_info: Dictionary):
	print("  👤 %s sees player %d joined: %s" % [username, player_id, str(player_info)])

func _on_client_message_received(username: String, sender_id: int, message_name: String, data: Dictionary):
	print("  📨 %s received from %d - %s: %s" % [username, sender_id, message_name, str(data)])
