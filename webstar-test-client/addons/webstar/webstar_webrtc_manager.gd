## WebRTC peer connection manager for WebStar networking
@tool
extends Node
class_name WebStarWebRTCManager

signal peer_connected(peer_id: String, player_id: int)
signal peer_disconnected(peer_id: String, player_id: int)
signal connection_failed(peer_id: String, player_id: int, reason: String)
signal data_received(peer_id: String, player_id: int, data: Dictionary)

var config: WebStarConfig
var peers: Dictionary = {} # peer_id -> WebRTCPeerConnection
var peer_to_player: Dictionary = {} # peer_id -> player_id
var multiplayer_peer: WebRTCMultiplayerPeer

func _init(p_config: WebStarConfig = null):
	if p_config:
		config = p_config
	else:
		config = WebStarConfig.new()
	
	multiplayer_peer = WebRTCMultiplayerPeer.new()

func connect_to_peer(peer_id: String, player_id: int):
	if not config.webrtc_enabled:
		connection_failed.emit(peer_id, player_id, "WebRTC disabled")
		return
	
	var peer_connection = WebRTCPeerConnection.new()
	peer_connection.initialize({
		"iceServers": config.ice_servers
	})
	
	peers[peer_id] = peer_connection
	peer_to_player[peer_id] = player_id
	
	# Set up data channel
	var data_channel = peer_connection.create_data_channel("webstar", {
		"ordered": true
	})
	
	data_channel.data_received.connect(_on_data_received.bind(peer_id))
	peer_connection.session_description_created.connect(_on_session_created.bind(peer_id))
	peer_connection.ice_candidate_created.connect(_on_ice_candidate_created.bind(peer_id))
	
	# Create offer
	peer_connection.create_offer()

func disconnect_peer(peer_id: String):
	if peers.has(peer_id):
		var peer_connection = peers[peer_id]
		peer_connection.close()
		peers.erase(peer_id)
		
		var player_id = peer_to_player.get(peer_id, 0)
		peer_to_player.erase(peer_id)
		peer_disconnected.emit(peer_id, player_id)

func disconnect_all():
	for peer_id in peers.keys():
		disconnect_peer(peer_id)

func send_data(peer_id: String, data: Dictionary):
	if peers.has(peer_id):
		var peer_connection = peers[peer_id]
		var json_string = JSON.stringify(data)
		# Note: This is simplified - would need proper data channel handling
		print("Sending data to ", peer_id, ": ", json_string)

func _on_data_received(peer_id: String, data: PackedByteArray):
	var json = JSON.new()
	var parse_result = json.parse(data.get_string_from_utf8())
	if parse_result == OK:
		var player_id = peer_to_player.get(peer_id, 0)
		data_received.emit(peer_id, player_id, json.data)

func _on_session_created(peer_id: String, type: String, sdp: String):
	print("Session created for ", peer_id, " type: ", type)

func _on_ice_candidate_created(peer_id: String, media: String, index: int, name: String):
	print("ICE candidate created for ", peer_id)
