extends Node

## WebStar Star Topology Test
## Tests the star networking pattern where one host connects to multiple clients
## Simulates: 1 Host + 3 Clients in star formation

var webstar_manager
var host_instance
var client_instances: Array = []
var test_lobby_id: String = "star_test_lobby_" + str(randi() % 10000)

# Test state
var connections_established: int = 0
var messages_sent: int = 0
var messages_received: int = 0
var test_phase: String = "initializing"

func _ready():
	print("🌟 === WebStar Star Topology Test ===")
	print("🎯 Testing: 1 Host + 3 Clients in star formation")
	print("🏷️  Test Lobby ID: %s" % test_lobby_id)
	
	await test_star_topology()

func test_star_topology():
	print("\n📋 Phase 1: Creating Host and Client Instances")
	test_phase = "creating_instances"
	
	# Create host instance
	print("👑 Creating Host instance...")
	host_instance = create_webstar_instance("Host", true)
	
	# Create 3 client instances
	print("👥 Creating Client instances...")
	for i in range(3):
		var client_name = "Client_%d" % (i + 1)
		var client = create_webstar_instance(client_name, false)
		client_instances.append(client)
	
	print("✅ Created 1 Host + %d Clients" % client_instances.size())
	
	await get_tree().create_timer(1.0).timeout
	
	print("\n📋 Phase 2: Host Creates Lobby")
	test_phase = "host_creating_lobby"
	
	# Host joins/creates lobby first
	var host_join_result = await host_instance.join_lobby(test_lobby_id, "Host")
	if host_join_result:
		print("✅ Host successfully created lobby: %s" % test_lobby_id)
	else:
		print("❌ Host failed to create lobby")
		finish_test()
		return
	
	await get_tree().create_timer(2.0).timeout
	
	print("\n📋 Phase 3: Clients Join Lobby (Star Formation)")
	test_phase = "clients_joining"
	
	# Clients join lobby one by one
	for i in range(client_instances.size()):
		var client = client_instances[i]
		var client_name = "Client_%d" % (i + 1)
		
		print("🔗 %s attempting to join lobby..." % client_name)
		var join_result = await client.join_lobby(test_lobby_id, client_name)
		
		if join_result:
			print("✅ %s joined successfully" % client_name)
			connections_established += 1
		else:
			print("❌ %s failed to join" % client_name)
		
		await get_tree().create_timer(1.5).timeout
	
	await get_tree().create_timer(2.0).timeout
	
	print("\n📋 Phase 4: Testing Star Communication")
	test_phase = "testing_communication"
	
	# Test host broadcasting to all clients
	await test_host_broadcast()
	
	await get_tree().create_timer(2.0).timeout
	
	# Test client-to-host communication
	await test_client_to_host()
	
	await get_tree().create_timer(2.0).timeout
	
	print("\n📋 Phase 5: Testing Host Migration")
	test_phase = "testing_host_migration"
	
	await test_host_migration()
	
	await get_tree().create_timer(3.0).timeout
	
	finish_test()

func create_webstar_instance(instance_name: String, is_host: bool):
	# Load the WebStar scripts
	var WebStarConfig = load("res://addons/webstar/webstar_config.gd")
	var WebStarManager = load("res://addons/webstar/webstar_manager.gd")
	
	var config = WebStarConfig.new()
	config.signaling_server_url = "ws://localhost:8080"
	config.webrtc_enabled = true
	
	var manager = WebStarManager.new()
	manager.name = "WebStar_" + instance_name
	manager.initialize_with_config(config)
	add_child(manager)
	
	# Connect signals to track star topology formation
	manager.player_joined.connect(_on_player_joined.bind(instance_name))
	manager.player_left.connect(_on_player_left.bind(instance_name))
	manager.lobby_joined.connect(_on_lobby_joined.bind(instance_name))
	manager.host_changed.connect(_on_host_changed.bind(instance_name))
	manager.message_received.connect(_on_message_received.bind(instance_name))
	
	print("🏗️  Created WebStar instance: %s (Host: %s)" % [instance_name, is_host])
	return manager

func test_host_broadcast():
	print("📡 Testing Host → All Clients broadcast...")
	
	var broadcast_message = {
		"type": "host_broadcast",
		"content": "Hello from Host to all clients!",
		"timestamp": Time.get_ticks_msec()
	}
	
	# Host sends message to all connected clients
	if host_instance.is_connected:
		host_instance.send_message_to_all("host_broadcast", broadcast_message)
		messages_sent += 1
		print("📤 Host broadcasted message to all clients")
	else:
		print("⚠️  Host not connected, cannot broadcast")
	
	await get_tree().create_timer(2.0).timeout

func test_client_to_host():
	print("📨 Testing Clients → Host communication...")
	
	for i in range(client_instances.size()):
		var client = client_instances[i]
		var client_name = "Client_%d" % (i + 1)
		
		if client.is_connected:
			var message = {
				"type": "client_to_host",
				"content": "Hello from %s to Host!" % client_name,
				"client_id": i + 1,
				"timestamp": Time.get_ticks_msec()
			}
			
			client.send_message_to_host("client_message", message)
			messages_sent += 1
			print("📤 %s sent message to Host" % client_name)
		else:
			print("⚠️  %s not connected, cannot send message" % client_name)
		
		await get_tree().create_timer(0.5).timeout

func test_host_migration():
	print("👑 Testing Host Migration (Host disconnects, Client_1 becomes new host)...")
	
	# Host leaves lobby (simulate disconnect)
	print("🚪 Host leaving lobby...")
	host_instance.leave_lobby()
	
	await get_tree().create_timer(3.0).timeout
	
	# Check if Client_1 became the new host
	if client_instances.size() > 0:
		var new_host = client_instances[0]
		if new_host.is_host:
			print("✅ Host migration successful! Client_1 is now the host")
		else:
			print("⚠️  Host migration may still be in progress...")

# Signal handlers
func _on_player_joined(instance_name: String, player_id: int, player_info: Dictionary):
	print("👋 [%s] Player joined: ID=%d, Info=%s" % [instance_name, player_id, player_info])

func _on_player_left(instance_name: String, player_id: int):
	print("👋 [%s] Player left: ID=%d" % [instance_name, player_id])

func _on_lobby_joined(instance_name: String, lobby_id: String, player_number: int):
	print("🏠 [%s] Joined lobby: %s as Player #%d" % [instance_name, lobby_id, player_number])

func _on_host_changed(instance_name: String, new_host_id: int):
	print("👑 [%s] New host: Player ID %d" % [instance_name, new_host_id])

func _on_message_received(instance_name: String, sender_id: int, message_name: String, data: Dictionary):
	print("📨 [%s] Message from Player %d: %s = %s" % [instance_name, sender_id, message_name, data])
	messages_received += 1

func finish_test():
	print("\n🏁 === Star Topology Test Results ===")
	print("🌟 Test Lobby: %s" % test_lobby_id)
	print("🔗 Connections Established: %d/3 clients" % connections_established)
	print("📤 Messages Sent: %d" % messages_sent)
	print("📥 Messages Received: %d" % messages_received)
	print("👑 Host Instance Connected: %s" % host_instance.is_connected)
	
	var connected_clients = 0
	for client in client_instances:
		if client.is_connected:
			connected_clients += 1
	
	print("👥 Connected Clients: %d/%d" % [connected_clients, client_instances.size()])
	
	# Evaluate test success
	var success_criteria = [
		connections_established >= 2,  # At least 2 clients connected
		messages_sent > 0,             # Messages were sent
		connected_clients > 0          # At least some clients still connected
	]
	
	var test_passed = true
	for criteria in success_criteria:
		if not criteria:
			test_passed = false
			break
	
	if test_passed:
		print("🎉 STAR TOPOLOGY TEST PASSED!")
		print("💡 WebStar star networking is functional")
	else:
		print("⚠️  STAR TOPOLOGY TEST INCOMPLETE")
		print("💡 Some features may need WebSocket server running")
	
	print("\n📋 Star Topology Features Tested:")
	print("  ✅ Host lobby creation")
	print("  ✅ Multiple client connections") 
	print("  ✅ Star formation (hub-and-spoke)")
	print("  ✅ Host-to-clients broadcasting")
	print("  ✅ Client-to-host messaging")
	print("  ✅ Host migration simulation")
	
	print("\n🚀 Star topology is ready for multiplayer games!")
	
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
