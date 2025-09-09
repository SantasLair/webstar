extends Node

## WebRTC Multi-Client Test Orchestrator
## Coordinates multiple clients to test peer-to-peer WebRTC connections

var test_clients: Array[Node] = []
var clients_ready: int = 0
var webrtc_connections: int = 0
var total_test_duration: float = 30.0  # seconds
var test_start_time: float
var webrtc_test_results: Dictionary = {}

func _ready():
	print("🎮 === WebRTC Multi-Client Test Suite ===")
	print("🎯 Goal: Test P2P WebRTC connections between multiple Godot clients")
	print("📋 Test plan:")
	print("  1. Create multiple WebStar clients")
	print("  2. Join them to the same lobby") 
	print("  3. Establish WebRTC peer connections")
	print("  4. Test P2P data transfer")
	print("  5. Measure connection stability")
	
	await run_webrtc_test_suite()

func run_webrtc_test_suite():
	print("\n🚀 Starting WebRTC test suite...")
	test_start_time = Time.get_ticks_msec() / 1000.0
	
	# Step 1: Create test clients
	await create_webrtc_test_clients(3)
	
	# Step 2: Join lobby
	await join_all_clients_to_lobby()
	
	# Step 3: Wait for WebRTC connections
	await wait_for_webrtc_connections()
	
	# Step 4: Test P2P data transfer
	await test_p2p_data_transfer()
	
	# Step 5: Monitor connection stability
	await monitor_connection_stability()
	
	# Step 6: Cleanup and results
	await cleanup_and_report_results()

func create_webrtc_test_clients(count: int):
	print("\n👥 Creating %d WebRTC test clients..." % count)
	
	for i in range(count):
		var client_id = "Client" + str(i + 1)
		var client_script = preload("res://scripts/webrtc_test_client.gd")
		var client = client_script.new(client_id)
		
		add_child(client)
		test_clients.append(client)
		
		# Connect client signals
		client.client_ready.connect(_on_client_ready)
		client.webrtc_connection_established.connect(_on_webrtc_connection_established)
		client.webrtc_data_received.connect(_on_webrtc_data_received)
		
		print("  🔧 Created client: %s" % client_id)
		
		# Small delay between client creation
		await get_tree().create_timer(0.5).timeout
	
	print("✅ All %d clients created" % count)

func join_all_clients_to_lobby():
	print("\n🏠 Joining all clients to test lobby...")
	
	var successful_joins = 0
	
	for client in test_clients:
		var success = await client.join_test_lobby()
		if success:
			successful_joins += 1
		
		# Small delay between joins
		await get_tree().create_timer(1.0).timeout
	
	print("📊 Lobby join results: %d/%d clients successfully joined" % [successful_joins, test_clients.size()])

func wait_for_webrtc_connections():
	print("\n🔗 Waiting for WebRTC peer connections to establish...")
	print("⏱️  Timeout: 15 seconds")
	
	var timeout = 15.0
	var elapsed = 0.0
	
	while elapsed < timeout:
		if webrtc_connections >= expected_webrtc_connections():
			print("✅ All expected WebRTC connections established!")
			return
		
		await get_tree().create_timer(1.0).timeout
		elapsed += 1.0
		
		print("  ⏳ Waiting... (%d/%d connections, %.1fs elapsed)" % [webrtc_connections, expected_webrtc_connections(), elapsed])
	
	print("⚠️  WebRTC connection timeout reached. Proceeding with current connections: %d/%d" % [webrtc_connections, expected_webrtc_connections()])

func expected_webrtc_connections() -> int:
	# For N clients, we expect N*(N-1) total directional connections
	# But WebRTC is bidirectional, so it's N*(N-1)/2 peer connections
	var n = test_clients.size()
	return n * (n - 1)  # Total directional connections for monitoring

func test_p2p_data_transfer():
	print("\n📡 Testing P2P data transfer...")
	
	# Have each client send test data
	for i in range(test_clients.size()):
		var client = test_clients[i]
		client.send_webrtc_test_data()
		
		print("  📤 %s sent test data" % client.client_id)
		await get_tree().create_timer(1.0).timeout
	
	# Wait for data propagation
	print("  ⏳ Waiting for data propagation (5 seconds)...")
	await get_tree().create_timer(5.0).timeout

func monitor_connection_stability():
	print("\n📊 Monitoring connection stability for 10 seconds...")
	
	var monitor_start = Time.get_ticks_msec() / 1000.0
	var monitor_duration = 10.0
	
	while (Time.get_ticks_msec() / 1000.0 - monitor_start) < monitor_duration:
		# Check connection health
		var active_connections = 0
		for client in test_clients:
			active_connections += client.connected_peers.size()
		
		print("  💓 Active WebRTC connections: %d" % active_connections)
		await get_tree().create_timer(2.0).timeout
	
	print("✅ Connection stability monitoring completed")

func cleanup_and_report_results():
	print("\n🧹 Cleaning up and generating test report...")
	
	# Collect results from all clients
	for client in test_clients:
		webrtc_test_results[client.client_id] = client.get_test_results()
	
	# Cleanup clients
	for client in test_clients:
		await client.cleanup()
		client.queue_free()
	
	test_clients.clear()
	
	# Generate final report
	print_final_webrtc_report()

func print_final_webrtc_report():
	var total_test_time = (Time.get_ticks_msec() / 1000.0) - test_start_time
	
	print("\n🏁 === WebRTC Test Suite Results ===")
	print("⏱️  Total test time: %.1f seconds" % total_test_time)
	print("👥 Clients tested: %d" % webrtc_test_results.size())
	print("🔗 WebRTC connections established: %d" % webrtc_connections)
	
	print("\n📊 Per-client results:")
	var successful_clients = 0
	
	for client_id in webrtc_test_results:
		var result = webrtc_test_results[client_id]
		var status = "✅ PASS" if result.test_successful else "❌ FAIL"
		print("  %s: %s (peers: %d, messages: %d)" % [
			client_id, 
			status, 
			result.connected_peers, 
			result.messages_received
		])
		
		if result.test_successful:
			successful_clients += 1
	
	# Overall assessment
	print("\n🎯 Overall Results:")
	print("  ✅ Successful clients: %d/%d" % [successful_clients, webrtc_test_results.size()])
	print("  📡 Connection success rate: %.1f%%" % ((float(successful_clients) / webrtc_test_results.size()) * 100.0))
	
	if successful_clients >= 2:
		print("🎉 WebRTC P2P functionality is working!")
		print("💡 Clients can establish peer connections and exchange data")
	else:
		print("⚠️  WebRTC testing shows issues:")
		print("   - Check ICE server configuration")
		print("   - Verify firewall/NAT settings") 
		print("   - Ensure STUN/TURN servers are accessible")
	
	# Exit
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()

# Signal handlers
func _on_client_ready(client_id: String):
	clients_ready += 1
	print("  ✅ %s ready (%d/%d)" % [client_id, clients_ready, test_clients.size()])

func _on_webrtc_connection_established(client_id: String, peer_id: String):
	webrtc_connections += 1
	print("  🤝 WebRTC connection: %s ↔ %s (total: %d)" % [client_id, peer_id, webrtc_connections])

func _on_webrtc_data_received(client_id: String, data: Dictionary):
	print("  📦 %s received P2P data: %s" % [client_id, data.get("message", "unknown")])
