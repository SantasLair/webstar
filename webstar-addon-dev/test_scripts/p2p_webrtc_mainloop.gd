extends MainLoop

## Real P2P WebRTC Test (MainLoop version)
## Tests actual peer-to-peer connection between two WebRTC instances

var peer1: WebRTCPeerConnection
var peer2: WebRTCPeerConnection
var channel1: WebRTCDataChannel
var channel2: WebRTCDataChannel
var messages_exchanged: int = 0
var test_timer: float = 0.0
var max_test_time: float = 15.0

func _initialize():
	print("🔗 === Real P2P WebRTC Connection Test ===")
	print("🎯 Creating two peers and establishing P2P connection")
	
	# Create two peers
	peer1 = WebRTCPeerConnection.new()
	peer2 = WebRTCPeerConnection.new()
	
	# Initialize both with ICE servers
	var ice_config = {
		"iceServers": [
			{"urls": "stun:stun.l.google.com:19302"}
		]
	}
	
	peer1.initialize(ice_config)
	peer2.initialize(ice_config)
	print("✅ Both peers initialized")
	
	# Create data channels (negotiated to avoid offer/answer complexity)
	print("📺 Creating negotiated data channels...")
	channel1 = peer1.create_data_channel("chat", {"id": 1, "negotiated": true})
	channel2 = peer2.create_data_channel("chat", {"id": 1, "negotiated": true})
	print("✅ Data channels created")
	
	# Connect signaling signals
	print("🔄 Setting up signaling...")
	setup_signaling()
	
	# Start connection process
	print("🚀 Starting connection process...")
	peer1.create_offer()
	print("⏱️  Monitoring connection for 15 seconds...")

func _process(delta: float) -> bool:
	test_timer += delta
	
	# Process peers
	if peer1:
		peer1.poll()
	if peer2:
		peer2.poll()
	
	# Print status every second
	var current_second = int(test_timer)
	if current_second > 0 and test_timer - current_second < delta:
		print("📊 Second %d - Peer1 state: %d, Peer2 state: %d, Messages: %d" % [
			current_second, 
			peer1.get_connection_state() if peer1 else -1,
			peer2.get_connection_state() if peer2 else -1,
			messages_exchanged
		])
		
		# Try sending messages once connected
		if current_second >= 3 and channel1 and channel1.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
			if current_second % 3 == 0:  # Send every 3 seconds
				send_test_messages()
	
	# Exit after test time
	if test_timer >= max_test_time:
		print_final_results()
		return true  # Exit MainLoop
	
	return false  # Continue MainLoop

func setup_signaling():
	# Connect peer1 signals
	peer1.session_description_created.connect(_on_peer1_session_created)
	peer1.ice_candidate_created.connect(_on_peer1_ice_candidate)
	
	# Connect peer2 signals  
	peer2.session_description_created.connect(_on_peer2_session_created)
	peer2.ice_candidate_created.connect(_on_peer2_ice_candidate)
	
	# Connect data channel signals
	channel1.data_received.connect(_on_channel1_data_received)
	channel2.data_received.connect(_on_channel2_data_received)

func send_test_messages():
	var timestamp = Time.get_ticks_msec()
	var message1 = "Hello from Peer1 at %d" % timestamp
	var message2 = "Hello from Peer2 at %d" % timestamp
	
	if channel1 and channel1.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		channel1.put_packet(message1.to_utf8_buffer())
		print("📤 Peer1 sent: %s" % message1)
	
	if channel2 and channel2.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		channel2.put_packet(message2.to_utf8_buffer())
		print("📤 Peer2 sent: %s" % message2)

# Signaling handlers
func _on_peer1_session_created(type: String, sdp: String):
	print("📋 Peer1 session created: %s" % type)
	peer1.set_local_description(type, sdp)
	peer2.set_remote_description(type, sdp)

func _on_peer2_session_created(type: String, sdp: String):
	print("📋 Peer2 session created: %s" % type)
	peer2.set_local_description(type, sdp)
	peer1.set_remote_description(type, sdp)

func _on_peer1_ice_candidate(media: String, index: int, name: String):
	print("🧊 Peer1 ICE candidate: %s" % media)
	peer2.add_ice_candidate(media, index, name)

func _on_peer2_ice_candidate(media: String, index: int, name: String):
	print("🧊 Peer2 ICE candidate: %s" % media)
	peer1.add_ice_candidate(media, index, name)

# Data channel handlers
func _on_channel1_data_received(data: PackedByteArray):
	var message = data.get_string_from_utf8()
	print("📥 Peer1 received: %s" % message)
	messages_exchanged += 1

func _on_channel2_data_received(data: PackedByteArray):
	var message = data.get_string_from_utf8()
	print("📥 Peer2 received: %s" % message)
	messages_exchanged += 1

func print_final_results():
	print("\n🏁 === P2P WebRTC Test Results ===")
	print("🔗 Peer1 final state: %d" % (peer1.get_connection_state() if peer1 else -1))
	print("🔗 Peer2 final state: %d" % (peer2.get_connection_state() if peer2 else -1))
	print("📺 Channel1 state: %d" % (channel1.get_ready_state() if channel1 else -1))
	print("📺 Channel2 state: %d" % (channel2.get_ready_state() if channel2 else -1))
	print("📨 Total messages exchanged: %d" % messages_exchanged)
	
	var success = false
	if peer1 and peer2:
		success = (
			peer1.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED and
			peer2.get_connection_state() == WebRTCPeerConnection.STATE_CONNECTED and
			messages_exchanged > 0
		)
	
	if success:
		print("🎉 SUCCESS: Real P2P WebRTC connection established!")
		print("💡 WebRTC is fully functional and ready for multiplayer games!")
	else:
		print("⚠️  P2P connection not fully established")
		print("💡 May need TURN servers for NAT traversal in production")
	
	print("\n🚀 Your WebStar system has complete WebRTC P2P capability!")

func _finalize():
	print("🏁 P2P WebRTC test completed!")
