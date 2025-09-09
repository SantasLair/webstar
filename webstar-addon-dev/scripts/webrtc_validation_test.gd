extends Node

## WebRTC Component Validation Test
## Tests WebRTC components and readiness without requiring full P2P connections

func _ready():
	print("🧪 === WebRTC Component Validation Test ===")
	print("🎯 Goal: Validate WebRTC components are properly configured and functional")
	
	await run_webrtc_validation()

func run_webrtc_validation():
	var test_results = {
		"webrtc_manager_creation": false,
		"ice_server_configuration": false,
		"webrtc_peer_creation": false,
		"data_channel_creation": false,
		"component_integration": false
	}
	
	print("\n🔧 Testing WebRTC component creation...")
	test_results.webrtc_manager_creation = test_webrtc_manager_creation()
	
	print("\n🌐 Testing ICE server configuration...")
	test_results.ice_server_configuration = test_ice_server_config()
	
	print("\n📡 Testing WebRTC peer connection creation...")
	test_results.webrtc_peer_creation = test_webrtc_peer_creation()
	
	print("\n📺 Testing data channel creation...")
	test_results.data_channel_creation = test_data_channel_creation()
	
	print("\n🔗 Testing WebStar integration...")
	test_results.component_integration = test_webstar_integration()
	
	print_validation_results(test_results)

func test_webrtc_manager_creation() -> bool:
	print("  🔧 Creating WebRTC manager...")
	
	var config = WebStarConfig.new()
	var webrtc_manager = WebStarWebRTCManager.new(config)
	
	if webrtc_manager:
		print("  ✅ WebRTC manager created successfully")
		webrtc_manager.queue_free()
		return true
	else:
		print("  ❌ Failed to create WebRTC manager")
		return false

func test_ice_server_config() -> bool:
	print("  🌐 Checking ICE server configuration...")
	
	var config = WebStarConfig.new()
	
	if config.ice_servers.size() > 0:
		print("  ✅ ICE servers configured: %d servers" % config.ice_servers.size())
		for i in range(config.ice_servers.size()):
			var server = config.ice_servers[i]
			print("    🌍 Server %d: %s" % [i + 1, server.get("urls", "unknown")])
		return true
	else:
		print("  ❌ No ICE servers configured")
		return false

func test_webrtc_peer_creation() -> bool:
	print("  📡 Creating WebRTC peer connection...")
	
	var peer_connection = WebRTCPeerConnection.new()
	var config = WebStarConfig.new()
	
	var init_result = peer_connection.initialize({
		"iceServers": config.ice_servers
	})
	
	if init_result == OK:
		print("  ✅ WebRTC peer connection initialized successfully")
		peer_connection.close()
		return true
	else:
		print("  ❌ WebRTC peer connection initialization failed: %d" % init_result)
		return false

func test_data_channel_creation() -> bool:
	print("  📺 Testing data channel creation...")
	
	var peer_connection = WebRTCPeerConnection.new()
	var config = WebStarConfig.new()
	
	peer_connection.initialize({
		"iceServers": config.ice_servers
	})
	
	var data_channel = peer_connection.create_data_channel("test", {
		"ordered": true
	})
	
	if data_channel:
		print("  ✅ Data channel created successfully")
		peer_connection.close()
		return true
	else:
		print("  ❌ Failed to create data channel")
		return false

func test_webstar_integration() -> bool:
	print("  🔗 Testing WebStar WebRTC integration...")
	
	# Test that WebStar manager includes WebRTC manager
	if WebStar and WebStar.webrtc_manager:
		print("  ✅ WebStar has WebRTC manager integrated")
		
		# Test that WebRTC is enabled in config
		if WebStar.config and WebStar.config.webrtc_enabled:
			print("  ✅ WebRTC is enabled in configuration")
			return true
		else:
			print("  ⚠️  WebRTC is disabled in configuration")
			return false
	else:
		print("  ❌ WebStar WebRTC manager not found")
		return false

func print_validation_results(results: Dictionary):
	print("\n🏁 === WebRTC Validation Results ===")
	
	var passed = 0
	var total = results.size()
	
	for test_name in results:
		var success = results[test_name]
		var status = "✅ PASS" if success else "❌ FAIL"
		var display_name = test_name.replace("_", " ").capitalize()
		print("  %s: %s" % [display_name, status])
		
		if success:
			passed += 1
	
	print("\n📊 Summary: %d/%d validation tests passed (%.1f%%)" % [passed, total, (float(passed) / total) * 100.0])
	
	if passed == total:
		print("🎉 WebRTC components are fully functional and ready!")
		print("💡 To test actual P2P connections:")
		print("   - Use separate browser tabs/windows")
		print("   - Ensure clients join the same lobby")
		print("   - Add WebRTC signaling to .NET server")
	elif passed >= 3:
		print("👍 WebRTC components are mostly functional")
		print("⚠️  Some features may need configuration adjustments")
	else:
		print("⚠️  WebRTC components have significant issues")
		print("🔧 Check Godot WebRTC addon installation and configuration")
	
	# Exit
	await get_tree().create_timer(2.0).timeout
	get_tree().quit()
