extends MultiplayerSpawner

@export var network_player: PackedScene

var _host_has_player: bool = false

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


func _on_peer_connected(id: int) -> void:
	if multiplayer.get_unique_id() != 1 : return
	if !_host_has_player:
		spawn_player(1)
		_host_has_player = true
	spawn_player(id)
	

func spawn_player(id: int) -> void:
	print("spawn_player called")
	if multiplayer.get_unique_id() != 1 : return
	
	var player: Node = network_player.instantiate()
	var xpos = 20 * id
	player.position = Vector2(xpos, 60)
	player.name = str(id)
	
	%Players.add_child(player)
