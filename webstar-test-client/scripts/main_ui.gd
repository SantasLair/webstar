extends Node2D


func _ready():
	# Enable debug logging
	var config = WebStarConfig.new()
	config.debug_logging = true
	WebStar.initialize_with_config(config)
	
	# Connect to debug signals to see what's happening
	WebStar.lobby_joined.connect(_onLobbyJoined)
	WebStar.message_received.connect(_onMessageReceived)
	WebStar.lobby_left.connect(_onLobbyLeft)
	WebStar.connection_failed.connect(_onConnectionFailed)
	
	print("WebStar config - signaling server: ", WebStar.config.signaling_server_url)
	print("WebStar config - relay server: ", WebStar.config.relay_server_url)
	
	# Run standalone WebSocket test first
	print("Running standalone WebSocket test...")
	_test_websocket_connection()
	
	# Wait a bit then test WebStar
	await get_tree().create_timer(3.0).timeout
	print("Testing WebStar join_lobby...")
	var result = await WebStar.join_lobby("test-lobby", "TestPlayer")
	print("WebStar join_lobby result: ", result)


func _test_websocket_connection():
	print("Testing basic HTTP connectivity first...")
	
	# Test HTTP connectivity to localhost
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	print("Testing HTTP to localhost:5090...")
	http_request.request("http://localhost:5090")
	var result = await http_request.request_completed
	print("HTTP result: ", result)
	remove_child(http_request)
	
	print("Now testing WebSocket connections...")
	var websocket = WebSocketPeer.new()
	
	# Try different URL formats
	var urls = [
		"ws://127.0.0.1:5090/ws",
		"ws://localhost:5090/ws"
	]
	
	for url in urls:
		print("Testing URL: ", url)
		websocket = WebSocketPeer.new()  # Fresh instance
		
		var error = websocket.connect_to_url(url)
		print("connect_to_url returned: ", error, " (", _error_to_string(error), ")")
		
		if error != OK:
			print("ERROR: Failed to initiate connection")
			continue
		
		# Quick test for 2 seconds
		for i in range(20):  # 2 seconds
			await get_tree().create_timer(0.1).timeout
			websocket.poll()
			var state = websocket.get_ready_state()
			print("State at %.1fs: %d (%s)" % [i * 0.1, state, _state_to_string(state)])
			if state == WebSocketPeer.STATE_OPEN:
				print("SUCCESS with URL: ", url)
				websocket.close()
				return
			elif state == WebSocketPeer.STATE_CLOSED:
				print("FAILED - connection closed for URL: ", url)
				print("Close code: ", websocket.get_close_code())
				print("Close reason: ", websocket.get_close_reason())
				break
		
		websocket.close()
		print("TIMEOUT for URL: ", url)
	
	print("All URL formats failed!")


func _error_to_string(error_code: int) -> String:
	match error_code:
		OK:
			return "OK"
		ERR_INVALID_PARAMETER:
			return "INVALID_PARAMETER"
		ERR_CANT_CONNECT:
			return "CANT_CONNECT"
		ERR_CANT_RESOLVE:
			return "CANT_RESOLVE"
		_:
			return "UNKNOWN_ERROR_" + str(error_code)


func _monitor_connection(websocket: WebSocketPeer, start_time: int):
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	var state = websocket.get_ready_state()
	
	print("Elapsed: %.1fs - State: %d (%s)" % [elapsed, state, _state_to_string(state)])
	
	# Poll the websocket - CRITICAL for receiving messages!
	websocket.poll()
	
	# Check for any messages immediately after polling
	if websocket.get_available_packet_count() > 0:
		print("Packets available: ", websocket.get_available_packet_count())
		_check_for_messages(websocket)
	
	match state:
		WebSocketPeer.STATE_CONNECTING:
			if elapsed < 10.0:  # 10 second timeout
				# Continue monitoring
				await get_tree().create_timer(0.1).timeout
				_monitor_connection(websocket, start_time)
			else:
				print("TIMEOUT: Connection took too long")
		
		WebSocketPeer.STATE_OPEN:
			print("SUCCESS: WebSocket connected!")
			
			# Keep the connection alive and process messages
			print("Keeping connection alive for 5 seconds...")
			for i in range(50):  # 5 seconds with 0.1s intervals
				await get_tree().create_timer(0.1).timeout
				websocket.poll()  # Critical - must keep polling!
				
				# Check for messages
				if websocket.get_available_packet_count() > 0:
					_check_for_messages(websocket)
				
				var current_state = websocket.get_ready_state()
				if current_state != WebSocketPeer.STATE_OPEN:
					print("Connection state changed to: ", _state_to_string(current_state))
					break
				if i % 10 == 0:  # Print every second
					print("Connection still alive... (%.1fs)" % (i * 0.1))
			
			# Test sending a message if still connected
			if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
				var test_message = {"type": "test", "data": "hello"}
				var json_string = JSON.stringify(test_message)
				print("Sending test message: ", json_string)
				websocket.send_text(json_string)
				
				# Poll and wait for any response
				for i in range(20):  # 2 seconds
					await get_tree().create_timer(0.1).timeout
					websocket.poll()
					if websocket.get_available_packet_count() > 0:
						_check_for_messages(websocket)
			
			websocket.close()
			print("Test completed - closing connection")
		
		WebSocketPeer.STATE_CLOSED:
			print("FAILED: Connection closed")
			print("Close code: ", websocket.get_close_code())
			print("Close reason: ", websocket.get_close_reason())
		
		_:
			print("UNKNOWN STATE: ", state)


func _check_for_messages(websocket: WebSocketPeer):
	websocket.poll()
	
	while websocket.get_available_packet_count() > 0:
		var packet = websocket.get_packet()
		var message = packet.get_string_from_utf8()
		print("Received message: ", message)


func _state_to_string(state: int) -> String:
	match state:
		WebSocketPeer.STATE_CONNECTING:
			return "CONNECTING"
		WebSocketPeer.STATE_OPEN:
			return "OPEN"
		WebSocketPeer.STATE_CLOSING:
			return "CLOSING"
		WebSocketPeer.STATE_CLOSED:
			return "CLOSED"
		_:
			return "UNKNOWN"


func _onLobbyJoined(lobby_id: String, player_id: int):
	print("Successfully joined lobby: ", lobby_id, " as player: ", player_id)
	

func _onMessageReceived(sender_id: int, message_name: String, data: Dictionary):
	print("Received: ", message_name, " from ", sender_id)	
	
	
func _onLobbyLeft():
	print("Left the lobby")


func _onConnectionFailed(player_id: int, reason: String):
	print("Connection failed for player ", player_id, ": ", reason)

func _on_join_lobby_button_pressed() -> void:
	print("Join lobby button pressed!")
	$JoinLobbyButton.disabled = true
	
	print("Attempting to join lobby 'filly-monkey' as 'Anonymous'...")
	var result = await WebStar.join_lobby("filly-monkey", "Anonymous")
	print("Join lobby result: ", result)
	
	if not result:
		print("Failed to join lobby, re-enabling button")
		$JoinLobbyButton.disabled = false
