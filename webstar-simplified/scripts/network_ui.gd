extends Node

var _lobby_id = ""
var _can_send_messages = false
var _webstar: WebstarManager
var _peer_id: int = 0


func _ready() -> void:
	_webstar = %WebstarManager
	_webstar.lobby_joined.connect(_on_lobby_created_or_joined)
	_webstar.lobby_created.connect(_on_lobby_created_or_joined)
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)	
	multiplayer.server_disconnected.connect(_server_disconnected)
	


func _process(_delta: float) -> void:
	_update_controls()


func _on_host_button_pressed() -> void:
	_webstar.create_lobby(%LobbyText.text, 8, true)
	_lobby_id = "--pending--"
	_peer_id = 1


func _on_join_button_pressed() -> void:
	_webstar.join_lobby(%LobbyText.text)
	_lobby_id = "--pending--"
	
	

# ==============================================================================
# Multiplayer API Signals
# ==============================================================================

func _peer_connected(peer_id: int):
	chat("--- PEER %s ARRIVED! ---" % peer_id)

func _peer_disconnected(peer_id: int):
	chat("--- PEER %s LEFT ---" % peer_id)
	
func _connected_to_server():
	_peer_id = multiplayer.get_unique_id()
	chat("connected as peer %d" % _peer_id)
	
func _server_disconnected():
	if _peer_id == 1:
		chat("-- HOST CLOSED --")
	else:
		chat("-- DISCONNECTED FROM HOST --")
	_lobby_id = ""

#===============================================================================

func _update_controls():
	$HostButton.disabled = _lobby_id.length() > 0
	$JoinButton.disabled = _lobby_id.length() > 0
	$LeaveButton.disabled = _lobby_id.length() == 0 or _lobby_id == "--pending--"
	$SendButton.disabled = !_can_send_messages
	

func _add_system_message(message: String):
	var current_text = $ChatBox.text
	var datetime_parts = Time.get_datetime_string_from_system().split(" ")
	var timestamp = "00:00:00"  # Default fallback
	if datetime_parts.size() >= 2:
		timestamp = datetime_parts[1]  # Get time part
	elif datetime_parts.size() == 1:
		# If no space, try to extract time from the string
		timestamp = Time.get_time_string_from_system()
	
	var system_msg = "[%s] %s" % [timestamp, message]
	
	if current_text == "":
		$ChatBox.text = system_msg
	else:
		$ChatBox.text = current_text + "\n" + system_msg


func _on_leave_button_pressed() -> void:
	_webstar.leave_lobby()
	_webstar.leave_game()
	_lobby_id = ""


func _on_send_button_pressed() -> void:
	chat.rpc("peer%s: %s" % [str(_peer_id), $MessageText.text])


#quick and dirty messaging
@rpc("any_peer", "reliable", "call_local")
func chat(text):
	var current_text = $ChatBox.text
	if current_text == "":
		$ChatBox.text = text
	else:
		$ChatBox.text = current_text + "\n" + text


func _on_lobby_created_or_joined(lobby: String, _peer_id: int):
	_lobby_id = lobby
	_can_send_messages = true
