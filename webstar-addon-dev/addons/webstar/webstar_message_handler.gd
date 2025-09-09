## Message handler for WebStar networking
@tool
extends Node
class_name WebStarMessageHandler

func handle_message(sender_id: int, data: Dictionary, network_manager):
	var message_type = data.get("type", "")
	
	match message_type:
		"heartbeat":
			_handle_heartbeat(sender_id, data, network_manager)
		"ping":
			_handle_ping(sender_id, data, network_manager)
		"pong":
			_handle_pong(sender_id, data, network_manager)
		_:
			print("Unknown message type: ", message_type)

func _handle_heartbeat(sender_id: int, data: Dictionary, network_manager):
	# Echo heartbeat back
	var response = {
		"type": "heartbeat_response",
		"timestamp": data.get("timestamp", 0)
	}
	network_manager._send_to_player(sender_id, response)

func _handle_ping(sender_id: int, data: Dictionary, network_manager):
	# Respond with pong
	var response = {
		"type": "pong",
		"timestamp": data.get("timestamp", 0)
	}
	network_manager._send_to_player(sender_id, response)

func _handle_pong(sender_id: int, data: Dictionary, network_manager):
	# Update ping information
	var timestamp = data.get("timestamp", 0)
	if network_manager.heartbeat_manager:
		network_manager.heartbeat_manager.handle_heartbeat_response(sender_id, timestamp)
