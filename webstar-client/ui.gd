extends CanvasLayer


func _ready() -> void:
	Webstar.lobby_created.connect(_lobby_created)
	Webstar.lobby_joined.connect(_lobby_joined)
	
	await Webstar.connect_to_lobby_server()


func _on_host_button_pressed() -> void:
	Webstar.create_lobby("demo-knights", 32, true)
	

func _on_join_button_pressed() -> void:
	Webstar.join_lobby("demo-knights")


func _lobby_created(lobbyId: String, peerId: int) -> void:
	%MultiplayerSpawner.spawn(1)
	visible = false


func _lobby_joined(lobbyId: String, peerId: int) -> void:
	visible = false
