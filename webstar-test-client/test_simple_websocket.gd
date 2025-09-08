extends Node

func _ready():
	test_websocket()

func test_websocket():
	print("Testing simple WebSocket connection to .NET server...")
	
	var websocket = WebSocketPeer.new()
	var result = websocket.connect_to_url("ws://localhost:5090/ws")
	print("connect_to_url result: ", result)
	
	# Wait for connection
	var timeout = 5.0
	var elapsed = 0.0
	
	while websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING and elapsed < timeout:
		websocket.poll()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
	print("Final state: ", websocket.get_ready_state())
	
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		print("SUCCESS! WebSocket connected to .NET server")
		
		# Send a test message
		var test_message = {"type": "join_lobby", "lobby_id": "test123"}
		websocket.send_text(JSON.stringify(test_message))
		print("Sent test message: ", test_message)
		
		# Wait for response
		await get_tree().create_timer(1.0).timeout
		websocket.poll()
		
		while websocket.get_available_packet_count() > 0:
			var packet = websocket.get_packet()
			var message = packet.get_string_from_utf8()
			print("Received: ", message)
		
		websocket.close()
	else:
		print("FAILED to connect. State: ", websocket.get_ready_state())
	
	print("Test complete!")
	get_tree().quit()
