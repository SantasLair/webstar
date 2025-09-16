extends Node

var _lobby_id = ""
var _can_send_messages = false
var _peer_id: int = 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected_to_server)	
	multiplayer.server_disconnected.connect(_server_disconnected)
	Webstar.lobby_joined.connect(_on_lobby_created_or_joined)
	Webstar.lobby_created.connect(_on_lobby_created_or_joined)
	
	#todo: refactor so that await is not required, add connected_to_lobby_server signal (failed, etc)
	await Webstar.connect_to_lobby_server()
	

func _process(_delta: float) -> void:
	_update_controls()


func _on_host_button_pressed() -> void:	
	Webstar.create_lobby(%LobbyText.text, 8, true)
	_lobby_id = "--pending--"
	_peer_id = 1


func _on_join_button_pressed() -> void:
	Webstar.join_lobby(%LobbyText.text)
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
	var is_in_lobby := Webstar.is_in_lobby()
	$HostButton.disabled = is_in_lobby
	$JoinButton.disabled = is_in_lobby
	$LeaveButton.disabled = !is_in_lobby
	$SendButton.disabled = !is_in_lobby
	

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
	Webstar.leave_lobby() #do we need disconnect_from_lobby_server() ?
	Webstar.leave_game()  #disconnects fromWebRTC, should this method name change?
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
