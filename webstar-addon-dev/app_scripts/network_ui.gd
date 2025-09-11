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
