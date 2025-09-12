extends Node

var _lobby_id = ""
var _can_send_messages = false

func _ready() -> void:
	%NetworkManager.lobby_created.connect(_on_lobby_created_or_joined)

func _process(delta: float) -> void:
	_update_controls()


func _on_host_button_pressed() -> void:
	%NetworkManager.create_lobby(%LobbyText.text)
	_lobby_id = "--pending--"


func _on_join_button_pressed() -> void:
	%NetworkManager.join_lobby(%LobbyText.text)
	_lobby_id = "--pending--"


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
	%NetworkManager.leave()
	_lobby_id = ""


func _on_send_button_pressed() -> void:
	chat.rpc($MessageText.text)


#quick and dirty messaging
@rpc("any_peer", "reliable", "call_local")
func chat(text):
	var current_text = $ChatBox.text
	if current_text == "":
		$ChatBox.text = text
	else:
		$ChatBox.text = current_text + "\n" + text

func _on_lobby_created_or_joined():
	_lobby_id = $LobbyText.text
	_can_send_messages = true
