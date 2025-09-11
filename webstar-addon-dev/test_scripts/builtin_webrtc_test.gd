extends Node

## Simple WebRTC Test without External Plugin
## Tests if Godot 4.1+ built-in WebRTC works

func _ready():
	print("🧪 === Testing Built-in WebRTC ===")
	print("🎯 Godot 4.1+ should have built-in WebRTC support")
	
	await test_builtin_webrtc()

func test_builtin_webrtc():
	print("\n🔧 Testing built-in WebRTC classes...")
	
	# Test WebRTCPeerConnection availability
	var peer_connection = WebRTCPeerConnection.new()
	print("✅ WebRTCPeerConnection created: %s" % str(peer_connection != null))
	
	# Test WebRTCMultiplayerPeer availability  
	var multiplayer_peer = WebRTCMultiplayerPeer.new()
	print("✅ WebRTCMultiplayerPeer created: %s" % str(multiplayer_peer != null))
	
	# Test basic initialization without ICE servers first
	print("\n🌐 Testing initialization without ICE servers...")
	var init_result = peer_connection.initialize()
	print("📡 Initialize result: %d (0 = OK)" % init_result)
	
	if init_result == OK:
		print("✅ WebRTC peer connection initialized successfully!")
		
		# Test data channel creation
		print("\n📺 Testing data channel creation...")
		var data_channel = peer_connection.create_data_channel("test", {})
		
		if data_channel:
			print("✅ Data channel created successfully!")
			print("📋 Data channel label: %s" % data_channel.get_label())
			print("📋 Data channel ready state: %d" % data_channel.get_ready_state())
		else:
			print("❌ Data channel creation failed")
		
		# Test with ICE servers
		print("\n🌍 Testing with ICE servers...")
		var peer_connection2 = WebRTCPeerConnection.new()
		var ice_config = {
			"iceServers": [
				{"urls": "stun:stun.l.google.com:19302"}
			]
		}
		var init_result2 = peer_connection2.initialize(ice_config)
		print("📡 Initialize with ICE result: %d (0 = OK)" % init_result2)
		
		if init_result2 == OK:
			print("✅ WebRTC with ICE servers working!")
		else:
			print("⚠️ ICE server configuration issue")
		
		peer_connection2.close()
	else:
		print("❌ WebRTC initialization failed")
	
	peer_connection.close()
	
	print("\n🎉 Built-in WebRTC test completed!")
	print("💡 If this works, no external plugin is needed!")
	
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
