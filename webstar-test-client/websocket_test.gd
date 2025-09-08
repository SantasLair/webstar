extends Node

var websocket: WebSocketPeer

func _ready():
	print("Starting WebSocket connection test...")
	websocket = WebSocketPeer.new()
	
	var url = "ws://localhost:5090/ws"
	print("Connecting to: ", url)
	
	var error = websocket.connect_to_url(url)
	print("connect_to_url returned: ", error)
	
	if error != OK:
		print("ERROR: Failed to initiate connection: ", error)
		return
	
	# Start monitoring the connection
	var start_time = Time.get_ticks_msec()
	_monitor_connection(start_time)

func _monitor_connection(start_time: int):
	var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
	var state = websocket.get_ready_state()
	
	print("Elapsed: %.1fs - State: %d (%s)" % [elapsed, state, _state_to_string(state)])
	
	# Poll the websocket
	websocket.poll()
	
	match state:
		WebSocketPeer.STATE_CONNECTING:
			if elapsed < 10.0:  # 10 second timeout
				# Continue monitoring
				await get_tree().create_timer(0.1).timeout
				_monitor_connection(start_time)
			else:
				print("TIMEOUT: Connection took too long")
		
		WebSocketPeer.STATE_OPEN:
			print("SUCCESS: WebSocket connected!")
			
			# Test sending a message
			var test_message = {"type": "test", "data": "hello"}
			var json_string = JSON.stringify(test_message)
			print("Sending test message: ", json_string)
			websocket.send_text(json_string)
			
			# Wait a bit for any response
			await get_tree().create_timer(2.0).timeout
			_check_for_messages()
			
			websocket.close()
			print("Test completed - closing connection")
		
		WebSocketPeer.STATE_CLOSED:
			print("FAILED: Connection closed")
		
		_:
			print("UNKNOWN STATE: ", state)

func _check_for_messages():
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
