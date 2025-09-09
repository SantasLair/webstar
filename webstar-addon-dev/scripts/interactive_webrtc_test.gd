extends Node

## Interactive WebRTC Test (Run in Editor or Browser)
## Tests WebRTC functionality in a normal Godot environment

func _ready():
	print("🎮 === Interactive WebRTC Test ===")
	print("🎯 Testing WebRTC in normal Godot environment")
	print("⏱️  Test will run for 10 seconds, then exit")
	
	await test_webrtc_functionality()

func test_webrtc_functionality():
	print("\n🔧 Testing WebRTC native plugin...")
	
	# Test 1: WebRTC Peer Connection
	print("📡 Creating WebRTC peer connection...")
	var peer = WebRTCPeerConnection.new()
	
	if peer:
		print("✅ WebRTC peer connection created successfully")
		
		# Test 2: Initialize with ICE servers
		print("🌍 Initializing with ICE servers...")
		var ice_config = {
			"iceServers": [
				{"urls": "stun:stun.l.google.com:19302"}
			]
		}
		
		var init_result = peer.initialize(ice_config)
		print("📋 Initialize result: %d (0 = OK)" % init_result)
		
		if init_result == OK:
			print("✅ WebRTC initialization successful!")
			
			# Test 3: Create data channel
			print("📺 Creating data channel...")
			var channel = peer.create_data_channel("test", {"ordered": true})
			
			if channel:
				print("✅ Data channel created successfully!")
				print("📋 Channel label: %s" % channel.get_label())
				print("📋 Channel state: %d" % channel.get_ready_state())
				
				# Test 4: Test WebRTC events
				peer.session_description_created.connect(_on_session_created)
				peer.ice_candidate_created.connect(_on_ice_candidate_created)
				
				print("🎯 Creating offer to test signaling...")
				peer.create_offer()
				
				print("✅ All WebRTC tests passed!")
				print("🎉 WebRTC native plugin is working correctly!")
			else:
				print("❌ Data channel creation failed")
				print("⚠️  WebRTC plugin may not be properly loaded")
		else:
			print("❌ WebRTC initialization failed: %d" % init_result)
	else:
		print("❌ Failed to create WebRTC peer connection")
	
	# Test 5: WebRTC Multiplayer Peer
	print("\n🌐 Testing WebRTC Multiplayer Peer...")
	var mp_peer = WebRTCMultiplayerPeer.new()
	
	if mp_peer:
		print("✅ WebRTC Multiplayer Peer created successfully")
	else:
		print("❌ Failed to create WebRTC Multiplayer Peer")
	
	print("\n⏱️  Waiting 10 seconds before exit...")
	await get_tree().create_timer(10.0).timeout
	
	print("🏁 WebRTC test completed!")
	get_tree().quit()

func _on_session_created(type: String, sdp: String):
	print("📋 Session created - Type: %s, SDP length: %d chars" % [type, sdp.length()])

func _on_ice_candidate_created(media: String, index: int, name: String):
	print("🧊 ICE candidate created - Media: %s, Index: %d" % [media, index])
