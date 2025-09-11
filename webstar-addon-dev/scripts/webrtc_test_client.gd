extends Node

## WebRTC P2P Connection Test
## Tests peer-to-peer WebRTC connections between multiple clients

class_name WebRTCTestClient

var client_id: String
var webstar_manager: Node
var test_lobby_id: String = "webrtc-test-" + str(Time.get_ticks_msec())
var connected_peers: Array[String] = []
var messages_received: Array[Dictionary] = []
var webrtc_test_complete: bool = false

signal client_ready(client_id: String)
signal webrtc_connection_established(client_id: String, peer_id: String)
signal webrtc_data_received(client_id: String, data: Dictionary)
signal test_completed(client_id: String, success: bool) ## Emitted when test finishes

func _init(p_client_id: String):
	client_id = p_client_id
	name = "WebRTCClient_" + client_id

func _ready():
	print("🔧 [%s] Initializing WebRTC test client..." % client_id)
	
	# Create WebStar manager instance
	var WebStarManagerScript = preload("res://addons/webstar/webstar_manager.gd")
	webstar_manager = WebStarManagerScript.new()
	add_child(webstar_manager)
	
	# Connect to WebStar signals
	webstar_manager.lobby_joined.connect(_on_lobby_joined)
	webstar_manager.player_joined.connect(_on_player_joined)
	webstar_manager.player_left.connect(_on_player_left)
	webstar_manager.message_received.connect(_on_message_received)
	
	# Connect to WebRTC-specific signals
	if webstar_manager.webrtc_manager:
		webstar_manager.webrtc_manager.peer_connected.connect(_on_webrtc_peer_connected)
		webstar_manager.webrtc_manager.peer_disconnected.connect(_on_webrtc_peer_disconnected)
		webstar_manager.webrtc_manager.data_received.connect(_on_webrtc_data_received)
		webstar_manager.webrtc_manager.connection_failed.connect(_on_webrtc_connection_failed)
	
	# Wait for initialization
	await get_tree().create_timer(1.0).timeout
	
	client_ready.emit(client_id)

func join_test_lobby() -> bool:
	print("🏠 [%s] Joining test lobby: %s" % [client_id, test_lobby_id])
	
	var success = await webstar_manager.join_lobby(test_lobby_id, "WebRTC_" + client_id)
	
	if success:
		print("✅ [%s] Successfully joined lobby" % client_id)
	else:
		print("❌ [%s] Failed to join lobby" % client_id)
	
	return success

func start_webrtc_connections():
	print("🔗 [%s] Starting WebRTC peer connections..." % client_id)
	
	# In a real scenario, this would be coordinated through the signaling server
	# For testing, we'll simulate the process
	
	# Send a message to indicate this client is ready for WebRTC
	webstar_manager.broadcast_message("webrtc_ready", {
		"client_id": client_id,
		"timestamp": Time.get_ticks_msec()
	})

func send_webrtc_test_data():
	print("📡 [%s] Sending WebRTC test data to all peers..." % client_id)
	
	var test_data = {
		"type": "webrtc_test",
		"sender": client_id,
		"message": "Hello from %s via WebRTC!" % client_id,
		"timestamp": Time.get_ticks_msec(),
		"sequence": messages_received.size() + 1
	}
	
	# Send via WebRTC data channels to all connected peers
	for peer_id in connected_peers:
		if webstar_manager.webrtc_manager:
			webstar_manager.webrtc_manager.send_data(peer_id, test_data)

func cleanup():
	print("🧹 [%s] Cleaning up WebRTC test client..." % client_id)
	
	if webstar_manager:
		webstar_manager.leave_lobby()
		await get_tree().create_timer(0.5).timeout
		webstar_manager.queue_free()

# WebStar signal handlers
func _on_lobby_joined(_lobby_id: String, player_number: int):
	print("🎉 [%s] Joined lobby as player %d" % [client_id, player_number])

func _on_player_joined(player_id: int, player_info: Dictionary):
	print("👤 [%s] Player %d joined: %s" % [client_id, player_id, str(player_info)])
	
	# When another player joins, initiate WebRTC connection
	await get_tree().create_timer(1.0).timeout
	start_webrtc_connections()

func _on_player_left(player_id: int):
	print("🚪 [%s] Player %d left" % [client_id, player_id])

func _on_message_received(sender_id: int, message_name: String, data: Dictionary):
	print("📨 [%s] WebSocket message from %d - %s: %s" % [client_id, sender_id, message_name, str(data)])
	
	if message_name == "webrtc_ready":
		print("🤝 [%s] Peer %s is ready for WebRTC" % [client_id, data.get("client_id", "unknown")])

# WebRTC signal handlers
func _on_webrtc_peer_connected(peer_id: String, player_id: int):
	print("🔗 [%s] WebRTC peer connected: %s (player %d)" % [client_id, peer_id, player_id])
	connected_peers.append(peer_id)
	webrtc_connection_established.emit(client_id, peer_id)

func _on_webrtc_peer_disconnected(peer_id: String, player_id: int):
	print("💔 [%s] WebRTC peer disconnected: %s (player %d)" % [client_id, peer_id, player_id])
	connected_peers.erase(peer_id)

func _on_webrtc_data_received(peer_id: String, _player_id: int, data: Dictionary):
	print("📦 [%s] WebRTC data from %s: %s" % [client_id, peer_id, str(data)])
	messages_received.append(data)
	webrtc_data_received.emit(client_id, data)

func _on_webrtc_connection_failed(peer_id: String, _player_id: int, reason: String):
	print("💥 [%s] WebRTC connection failed to %s: %s" % [client_id, peer_id, reason])

func get_test_results() -> Dictionary:
	var results = {
		"client_id": client_id,
		"connected_peers": connected_peers.size(),
		"messages_received": messages_received.size(),
		"test_successful": connected_peers.size() > 0 and messages_received.size() > 0
	}
	
	# Emit test completion signal
	if not webrtc_test_complete:
		webrtc_test_complete = true
		test_completed.emit(client_id, results.test_successful)
	
	return results
