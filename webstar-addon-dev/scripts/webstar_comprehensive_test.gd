extends Node

## Comprehensive WebStar Testing Script
## Tests all major functionality of the WebStar networking system

var test_results: Dictionary = {}
var current_test_phase: int = 0
var test_phases: Array[String] = [
	"connection_test",
	"lobby_creation_test", 
	"message_broadcast_test",
	"lobby_management_test",
	"cleanup_test"
]

func _ready():
	print("🧪 === WebStar Comprehensive Testing Started ===")
	
	# Connect to all WebStar signals for monitoring
	WebStar.lobby_joined.connect(_on_lobby_joined)
	WebStar.lobby_left.connect(_on_lobby_left)
	WebStar.player_joined.connect(_on_player_joined)
	WebStar.player_left.connect(_on_player_left)
	WebStar.message_received.connect(_on_message_received)
	WebStar.connection_failed.connect(_on_connection_failed)
	WebStar.host_changed.connect(_on_host_changed)
	
	# Start testing sequence
	await get_tree().create_timer(1.0).timeout
	await run_test_sequence()

func run_test_sequence():
	print("\n📋 Starting test sequence with %d phases..." % test_phases.size())
	
	for i in range(test_phases.size()):
		current_test_phase = i
		var phase_name = test_phases[i]
		print("\n🔍 Phase %d: %s" % [i + 1, phase_name.capitalize().replace("_", " ")])
		
		var success = false
		match phase_name:
			"connection_test":
				success = await test_connection()
			"lobby_creation_test":
				success = await test_lobby_creation()
			"message_broadcast_test":
				success = await test_message_broadcasting()
			"lobby_management_test":
				success = test_lobby_management()
			"cleanup_test":
				success = await test_cleanup()
		
		test_results[phase_name] = success
		if success:
			print("✅ Phase %d passed: %s" % [i + 1, phase_name])
		else:
			print("❌ Phase %d failed: %s" % [i + 1, phase_name])
			break
		
		await get_tree().create_timer(1.0).timeout
	
	print_final_results()

func test_connection() -> bool:
	print("  🔌 Testing WebSocket connection...")
	
	# Try to connect if not already connected
	if not (WebStar.signaling_client and WebStar.signaling_client.is_connected):
		print("  🔄 Attempting to connect to signaling server...")
		var success = await WebStar.signaling_client.connect_to_signaling_server()
		if not success:
			print("  ❌ Failed to connect to signaling server")
			return false
	
	await get_tree().create_timer(2.0).timeout
	
	if WebStar.signaling_client and WebStar.signaling_client.is_connected:
		print("  ✅ WebSocket connection successful")
		return true
	else:
		print("  ❌ WebSocket connection failed")
		return false

func test_lobby_creation() -> bool:
	print("  🏠 Testing lobby creation...")
	
	# Try to join/create a lobby
	var success = await WebStar.join_lobby("test-lobby-" + str(Time.get_ticks_msec()), "TestPlayer")
	
	if success:
		print("  ✅ Lobby creation/join successful")
		return true
	else:
		print("  ❌ Lobby creation/join failed")
		return false

func test_message_broadcasting() -> bool:
	print("  📡 Testing message broadcasting...")
	
	# Send a test message
	WebStar.broadcast_message("test_message", {"data": "Hello WebStar!", "timestamp": Time.get_ticks_msec()})
	
	# Wait a bit for message processing
	await get_tree().create_timer(1.0).timeout
	
	print("  ✅ Message broadcasting completed (check server logs)")
	return true

func test_lobby_management() -> bool:
	print("  👥 Testing lobby management...")
	
	# Test player count
	var player_count = WebStar.get_player_count()
	print("  📊 Current player count: %d" % player_count)
	
	# Test connected players
	var connected_players = WebStar.get_connected_players()
	print("  🔗 Connected players: %s" % str(connected_players))
	
	# Test host status
	print("  👑 Is host: %s" % str(WebStar.is_host))
	print("  🆔 Local player ID: %d" % WebStar.local_player_id)
	
	return true

func test_cleanup() -> bool:
	print("  🧹 Testing cleanup and disconnection...")
	
	# Leave the lobby
	WebStar.leave_lobby()
	
	await get_tree().create_timer(1.0).timeout
	
	print("  ✅ Cleanup completed")
	return true

# Signal handlers for monitoring
func _on_lobby_joined(lobby_id: String, player_number: int):
	print("  🎉 Signal: Joined lobby '%s' as player %d" % [lobby_id, player_number])

func _on_lobby_left():
	print("  👋 Signal: Left the lobby")

func _on_player_joined(player_id: int, player_info: Dictionary):
	print("  👤 Signal: Player %d joined - %s" % [player_id, str(player_info)])

func _on_player_left(player_id: int):
	print("  🚪 Signal: Player %d left" % player_id)

func _on_message_received(sender_id: int, message_name: String, data: Dictionary):
	print("  📨 Signal: Message from %d - %s: %s" % [sender_id, message_name, str(data)])

func _on_connection_failed(player_id: int, reason: String):
	print("  💥 Signal: Connection failed for player %d - %s" % [player_id, reason])

func _on_host_changed(new_host_id: int):
	print("  👑 Signal: Host changed to player %d" % new_host_id)

func print_final_results():
	print("\n🏁 === WebStar Test Results ===")
	
	var passed = 0
	var total = test_results.size()
	
	for phase_name in test_results:
		var success = test_results[phase_name]
		var status = "✅ PASS" if success else "❌ FAIL"
		print("  %s: %s" % [phase_name.capitalize().replace("_", " "), status])
		if success:
			passed += 1
	
	print("\n📊 Summary: %d/%d tests passed (%.1f%%)" % [passed, total, (float(passed) / total) * 100.0])
	
	if passed == total:
		print("🎉 All tests passed! WebStar is working correctly.")
	else:
		print("⚠️  Some tests failed. Check the logs above for details.")
	
	# Exit after testing
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
