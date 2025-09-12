extends Node


func _ready():
	_update_controls()


func _on_host_button_pressed() -> void:
	%NetworkManager.create_lobby(%LobbyText.text)
	_update_controls()

func _on_join_button_pressed() -> void:
	%NetworkManager.join_lobby(%LobbyText.text)
	_update_controls()


func _update_controls():
	$HostButton.disabled = %NetworkManager.status != ""
	$JoinButton.disabled = %NetworkManager.status != ""
	$LeaveButton.disabled = %NetworkManager.status == ""
	
	# Disable send button until WebRTC is ready
	$SendButton.disabled = %NetworkManager.status == ""
	

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
	_update_controls()


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
