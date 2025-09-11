extends Node

var server_address = "127.0.0.1"
var server_port = 5090
var use_enet = true

var status = ""

func _ready():
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connected_fail)
	multiplayer.server_disconnected.connect(_on_server_disconnected)	
	

func create_lobby(lobby_name):
	print("creating lobby %s" % [lobby_name])
	if use_enet:
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_server(server_port, 32)
		if error:
			print("error creating lobby")
		else:
			multiplayer.multiplayer_peer = peer
			status = "created lobby"
			print("lobby created")
		


func join_lobby(lobby_name):
	print("joining lobby %s" % [lobby_name])
	if use_enet:
		var peer = ENetMultiplayerPeer.new()
		var error = peer.create_client(server_address, server_port)
		if error:
			print("error connecting to lobby")
		else:
			multiplayer.multiplayer_peer = peer
			status = "connecting to lobby"
	
	
func leave():
	multiplayer.multiplayer_peer = null
	status = ""
	%NetworkUI._update_controls()

	
func _on_player_connected(id):
	print("player %s connected" % [id])
	

func _on_player_disconnected(id):
	print("player %s disconnected" % [id])


func _on_connected_ok():
	print("connectred ok")
	

func _on_connected_fail():
	print("connection failed")
	

func _on_server_disconnected():
	print("server disconnected")
	status = ""
	
	#cheating
	%NetworkUI._update_controls()
