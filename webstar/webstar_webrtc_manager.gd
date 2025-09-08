## WebRTC connection manager for WebStar networking
## Handles peer-to-peer connections using WebRTC
class_name WebStarWebRTCManager
extends RefCounted

signal peer_connected(peer_id: String, player_id: int)
signal peer_disconnected(peer_id: String, player_id: int)
signal connection_failed(peer_id: String, player_id: int, reason: String)
signal data_received(peer_id: String, player_id: int, data: Dictionary)

class PeerConnection:
	var peer: WebRTCPeerConnection
	var data_channel: WebRTCDataChannel
	var player_id: int
	var peer_id: String
	var state: String = "connecting"
	var connection_attempts: int = 0
	var last_attempt_time: int = 0
	
	func _init(p_player_id: int, p_peer_id: String):
		player_id = p_player_id
		peer_id = p_peer_id

var config: WebStarConfig
var signaling_client: WebStarSignalingClient
var connections: Dictionary = {}  # peer_id -> PeerConnection
var local_peer_id: String = ""
var is_host: bool = false

# Connection monitoring
var connection_timers: Dictionary = {}
var heartbeat_timer: Timer

func _init(p_config: WebStarConfig):
	config = p_config
	_generate_peer_id()
	_setup_heartbeat_timer()

func set_signaling_client(client: WebStarSignalingClient):
	signaling_client = client
	# Connect to signaling for WebRTC signals
	# This would be handled by the signaling client's message processing

func _generate_peer_id():
	# Generate a unique peer ID
	local_peer_id = "peer_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)

func get_peer_id() -> String:
	return local_peer_id

func set_as_host(host: bool):
	is_host = host

func connect_to_peer(peer_id: String, player_id: int):
	"""Initiate connection to a remote peer."""
	if connections.has(peer_id):
		push_warning("Already connected or connecting to peer: " + peer_id)
		return
	
	var peer_connection = PeerConnection.new(player_id, peer_id)
	connections[peer_id] = peer_connection
	
	# Create WebRTC peer connection
	peer_connection.peer = WebRTCPeerConnection.new()
	_configure_peer_connection(peer_connection.peer)
	
	# Set up event handlers
	_setup_peer_events(peer_connection)
	
	# Create data channel (for the initiator)
	peer_connection.data_channel = peer_connection.peer.create_data_channel("game_data", {
		"ordered": true,
		"max_retransmits": 3
	})
	_setup_data_channel_events(peer_connection)
	
	# Create offer
	_create_offer(peer_connection)

func accept_incoming_connection(peer_id: String, player_id: int, offer: Dictionary):
	"""Accept an incoming connection from a remote peer."""
	if connections.has(peer_id):
		push_warning("Already connected to peer: " + peer_id)
		return
	
	var peer_connection = PeerConnection.new(player_id, peer_id)
	connections[peer_id] = peer_connection
	
	# Create WebRTC peer connection
	peer_connection.peer = WebRTCPeerConnection.new()
	_configure_peer_connection(peer_connection.peer)
	
	# Set up event handlers
	_setup_peer_events(peer_connection)
	
	# Set remote description (offer)
	peer_connection.peer.set_remote_description("offer", offer)
	
	# Create answer
	_create_answer(peer_connection)

func send_data(peer_id: String, data: Dictionary):
	"""Send data to a specific peer."""
	var peer_connection = connections.get(peer_id)
	if not peer_connection or peer_connection.state != "connected":
		if config.debug_logging:
			print("Cannot send data to disconnected peer: ", peer_id)
		return
	
	var json_string = JSON.stringify(data)
	var bytes = json_string.to_utf8_buffer()
	
	# Apply compression if enabled and data is large enough
	if config.enable_compression and bytes.size() > config.compression_threshold:
		bytes = _compress_data(bytes)
	
	# Simulate packet loss for testing
	if config.simulate_packet_loss > 0.0 and randf() < config.simulate_packet_loss:
		if config.debug_logging:
			print("Simulated packet loss for peer: ", peer_id)
		return
	
	# Simulate latency for testing
	if config.simulate_latency > 0.0:
		await Engine.get_main_loop().create_timer(config.simulate_latency / 1000.0).timeout
	
	var error = peer_connection.data_channel.put_packet(bytes)
	if error != OK:
		push_warning("Failed to send data to peer " + peer_id + ": " + str(error))

func disconnect_peer(peer_id: String):
	"""Disconnect from a specific peer."""
	var peer_connection = connections.get(peer_id)
	if not peer_connection:
		return
	
	peer_connection.state = "disconnected"
	
	if peer_connection.data_channel:
		peer_connection.data_channel.close()
	
	if peer_connection.peer:
		peer_connection.peer.close()
	
	connections.erase(peer_id)
	
	# Clean up timers
	if connection_timers.has(peer_id):
		connection_timers[peer_id].queue_free()
		connection_timers.erase(peer_id)
	
	peer_disconnected.emit(peer_id, peer_connection.player_id)

func disconnect_all():
	"""Disconnect from all peers."""
	for peer_id in connections.keys():
		disconnect_peer(peer_id)

func get_connected_peers() -> Array[String]:
	"""Get list of connected peer IDs."""
	var connected = []
	for peer_id in connections:
		var peer_connection = connections[peer_id]
		if peer_connection.state == "connected":
			connected.append(peer_id)
	return connected

func is_peer_connected(peer_id: String) -> bool:
	"""Check if a specific peer is connected."""
	var peer_connection = connections.get(peer_id)
	return peer_connection != null and peer_connection.state == "connected"

# Internal methods
func _configure_peer_connection(peer: WebRTCPeerConnection):
	"""Configure WebRTC peer connection with ICE servers."""
	var ice_servers = []
	for server in config.ice_servers:
		ice_servers.append(server)
	
	peer.initialize({
		"iceServers": ice_servers,
		"iceTransportPolicy": "relay" if config.force_relay_only else "all"
	})

func _setup_peer_events(peer_connection: PeerConnection):
	"""Set up event handlers for a peer connection."""
	peer_connection.peer.session_description_created.connect(_on_session_description_created.bind(peer_connection))
	peer_connection.peer.ice_candidate_created.connect(_on_ice_candidate_created.bind(peer_connection))
	peer_connection.peer.data_channel_received.connect(_on_data_channel_received.bind(peer_connection))

func _setup_data_channel_events(peer_connection: PeerConnection):
	"""Set up event handlers for data channel."""
	if not peer_connection.data_channel:
		return
	
	peer_connection.data_channel.open.connect(_on_data_channel_open.bind(peer_connection))
	peer_connection.data_channel.closed.connect(_on_data_channel_closed.bind(peer_connection))

func _create_offer(peer_connection: PeerConnection):
	"""Create WebRTC offer."""
	peer_connection.connection_attempts += 1
	peer_connection.last_attempt_time = Time.get_ticks_msec()
	
	var error = peer_connection.peer.create_offer()
	if error != OK:
		_handle_connection_error(peer_connection, "Failed to create offer: " + str(error))

func _create_answer(peer_connection: PeerConnection):
	"""Create WebRTC answer."""
	var error = peer_connection.peer.create_answer()
	if error != OK:
		_handle_connection_error(peer_connection, "Failed to create answer: " + str(error))

func _setup_heartbeat_timer():
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = 1.0  # Check every second
	heartbeat_timer.autostart = true
	heartbeat_timer.timeout.connect(_check_connection_timeouts)

func _check_connection_timeouts():
	"""Check for connection timeouts and failed connections."""
	var current_time = Time.get_ticks_msec()
	
	for peer_id in connections.keys():
		var peer_connection = connections[peer_id]
		
		# Check for connection timeout
		if peer_connection.state == "connecting":
			var elapsed = current_time - peer_connection.last_attempt_time
			if elapsed > config.webrtc_timeout * 1000:
				if peer_connection.connection_attempts < config.webrtc_max_reconnect_attempts:
					_retry_connection(peer_connection)
				else:
					_handle_connection_error(peer_connection, "Connection timeout")

func _retry_connection(peer_connection: PeerConnection):
	"""Retry a failed connection."""
	print("Retrying connection to peer: ", peer_connection.peer_id)
	
	# Wait before retrying
	await Engine.get_main_loop().create_timer(config.webrtc_reconnect_delay).timeout
	
	# Recreate peer connection
	if peer_connection.peer:
		peer_connection.peer.close()
	
	peer_connection.peer = WebRTCPeerConnection.new()
	_configure_peer_connection(peer_connection.peer)
	_setup_peer_events(peer_connection)
	
	# Try again
	_create_offer(peer_connection)

func _handle_connection_error(peer_connection: PeerConnection, reason: String):
	"""Handle connection errors."""
	print("Connection error for peer ", peer_connection.peer_id, ": ", reason)
	
	peer_connection.state = "failed"
	connection_failed.emit(peer_connection.peer_id, peer_connection.player_id, reason)
	
	# Clean up
	connections.erase(peer_connection.peer_id)

func _compress_data(data: PackedByteArray) -> PackedByteArray:
	"""Compress data using gzip."""
	return data.compress(FileAccess.COMPRESSION_GZIP)

func _decompress_data(data: PackedByteArray) -> PackedByteArray:
	"""Decompress gzip data."""
	return data.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)

# Signal handlers
func _on_session_description_created(type: String, sdp: String, peer_connection: PeerConnection):
	"""Handle session description creation (offer/answer)."""
	peer_connection.peer.set_local_description(type, {"type": type, "sdp": sdp})
	
	# Send the session description via signaling
	if signaling_client:
		signaling_client.send_webrtc_signal(peer_connection.player_id, {
			"type": type,
			"sdp": sdp
		})

func _on_ice_candidate_created(media: String, index: int, name: String, peer_connection: PeerConnection):
	"""Handle ICE candidate creation."""
	# Send ICE candidate via signaling
	if signaling_client:
		signaling_client.send_webrtc_signal(peer_connection.player_id, {
			"type": "ice_candidate",
			"candidate": {
				"sdpMLineIndex": index,
				"sdpMid": media,
				"candidate": name
			}
		})

func _on_data_channel_received(channel: WebRTCDataChannel, peer_connection: PeerConnection):
	"""Handle incoming data channel."""
	peer_connection.data_channel = channel
	_setup_data_channel_events(peer_connection)

func _on_data_channel_open(peer_connection: PeerConnection):
	"""Handle data channel opening."""
	peer_connection.state = "connected"
	peer_connected.emit(peer_connection.peer_id, peer_connection.player_id)
	
	# Start monitoring for incoming data
	_start_data_monitoring(peer_connection)

func _on_data_channel_closed(peer_connection: PeerConnection):
	"""Handle data channel closing."""
	if peer_connection.state == "connected":
		peer_connection.state = "disconnected"
		peer_disconnected.emit(peer_connection.peer_id, peer_connection.player_id)

func _start_data_monitoring(peer_connection: PeerConnection):
	"""Start monitoring for incoming data on a data channel."""
	var timer = Timer.new()
	timer.wait_time = 0.016  # ~60 FPS
	timer.autostart = true
	timer.timeout.connect(_check_incoming_data.bind(peer_connection))
	connection_timers[peer_connection.peer_id] = timer

func _check_incoming_data(peer_connection: PeerConnection):
	"""Check for incoming data on a peer connection."""
	if not peer_connection.data_channel or peer_connection.state != "connected":
		return
	
	while peer_connection.data_channel.get_available_packet_count() > 0:
		var packet = peer_connection.data_channel.get_packet()
		
		# Handle compression
		if config.enable_compression:
			# Try to decompress, fallback to raw data if it fails
			var decompressed = _decompress_data(packet)
			if decompressed.size() > 0:
				packet = decompressed
		
		var message_text = packet.get_string_from_utf8()
		var json = JSON.new()
		var parse_result = json.parse(message_text)
		
		if parse_result == OK:
			data_received.emit(peer_connection.peer_id, peer_connection.player_id, json.data)
		else:
			push_warning("Failed to parse received data from peer: " + peer_connection.peer_id)
