extends MultiplayerSpawner

@export var network_player: PackedScene

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)
	

func spawn_player(id: int) -> void:
	print("spawn_player called")
	if multiplayer.get_unique_id() != 1 : return
	
	var player: Node = network_player.instantiate()
	player.name = str(id)
	
	%Players.add_child(player)
