extends Node
## WebstarManager connects to signaling server and orchestrates WebRTC connections
##
class_name WebstarManager


signal signaling_server_connected
signal signaling_server_connection_failed
signal lobby_created(lobby_id, peer_id)
signal lobby_joined(lobby_id, peer_id)

var _server_url := "wss://dev.webstar.santaslair.net/ws"
var _connect_timeout_seconds := 5
var _lobby: String = ""	
var _is_connecting: bool = false
var _is_connected: bool = false
var _is_in_lobby: bool = false
var _peer_id: int = 0
var _lobby_id: String = ""
var _is_host: bool = false
var _is_mutiplayer_set = false

var _signal_client: WebstarSignalingClient = null
var _rtc_mp: WebRTCMultiplayerPeer = WebRTCMultiplayerPeer.new()	

func _process(_delta: float) -> void:
	if _signal_client:
		_signal_client.poll()
	_rtc_mp.poll()	
	
	# check webrtc peer statuses
	#var peer_ids = _rtc_mp.get_peers()
	#for key in peer_ids:
	#	var peer_info = _rtc_mp.get_peer(key)
	#	if peer_info["connected"]:
	#		print("RTC connected to peer")
	

## Async Connects to the singnaling server.  Raises signal signaling_server_connected
## or signaling_server_connection_failed
func connect_to_signaling_server_async() -> bool:
	if _is_connecting or _is_connected:
		print("[Webstar] Already connected or connecting to signaling server")
		return false
		
	_is_connecting = true
	print("[Webstar] Connecting to signaling server: ", _server_url)
	var websocket = WebSocketPeer.new()
	var error = websocket.connect_to_url(_server_url)
	if error != OK:
		push_error("[Webstar] Failed to connect to signaling server: " + str(error))
		return false
	
	# Wait for connection    
	var elapsed = 0.0
	var last_print_time = 0.0
	print("[WebStar] Waiting for connection, timeout: ", _connect_timeout_seconds, " seconds")
	
	while websocket.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		websocket.poll()
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		
		# Only print every second to reduce spam
		if elapsed - last_print_time >= 1.0:
			print("[WebStar] Still connecting... elapsed: ", elapsed, " state: ", websocket.get_ready_state())
			last_print_time = elapsed
			
		if elapsed > _connect_timeout_seconds:
			print("[Webstar] Timeout conneting to signaling server")
			push_error("Connection timeout")
			return false

	# when connected, pass websocket to signal client and enable processing
	if websocket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		print("[Webstar] Connected to signaling server")
		_signal_client = WebstarSignalingClient.new(websocket)
		_connect_signals(_signal_client)
		_is_connected = true
		set_process(true)
		return true
	return false
	

func _connect_signals(signal_client: WebstarSignalingClient) -> void:
	signal_client.lobby_created.connect(_on_lobby_created)
	signal_client.lobby_joined.connect(_on_lobby_joined)
	signal_client.peer_joined.connect(_on_peer_joined)
	signal_client.offer_received.connect(_on_offer_received)
	signal_client.answer_received.connect(_on_answer_received)
	signal_client.candidate_received.connect(_on_candidate_received)


## Creates a lobby.  Lobby owners are hosts and will initiate WebRTC offers to peers.
func create_lobby(lobby: String, max_players: int, is_public: bool) -> bool:
	if !_is_connected:
		_is_connected = await connect_to_signaling_server_async()
		if !_is_connected:
			return false
		
	if _lobby != "":
		push_warning("Already connected to a lobby")
		return false

	_signal_client.create_lobby(lobby, max_players, is_public)
	return true
	

## Joins an existing lobby. Fails if the lobby does not exist. Once lobby is joined,
## will receive WebRTC offer from host.	
func join_lobby(lobby_id: String):
	if !_is_connected:
		_is_connected = await connect_to_signaling_server_async()
		if !_is_connected:
			return false

	if _lobby != "":
		push_warning("Already connected to a lobby")
		return false

	_signal_client.join_lobby(lobby_id)
	return true


## closes connection to the signaling server, leaving the lobby
func leave_lobby():
	if _is_in_lobby:
		_signal_client.disconnect_from_sever()
		_is_connected = false
		_is_in_lobby = false
		_is_connecting = false
		_lobby_id = ""
		

## closes WebRTCConnections, if any	
func leave_game():
	_rtc_mp.close()


# =============================================================================
# Signal handlers
# =============================================================================

## Handles socket connection success
func _on_socket_connected():
	print("[Webstar] Connected to signaling server")
	_is_connected = true
	_is_connecting = false
	signaling_server_connected.emit()
	

## Handles connection failure
func _on_socket_connection_failed():
	print("[Webstar] Failed to connect to signaling server")
	_is_connected = false
	_is_connecting = false	
	signaling_server_connection_failed.emit()
	set_process(false)
	

## We created a lobby, we are the host, peer_id should be 1
func _on_lobby_created(lobby_id: String, peer_id: int):
	_peer_id = peer_id
	_is_host = true
	_rtc_mp.create_server() # we will act as multiplayer server
	print("[Webstar] lobby %s created as peer %d" % [lobby_id, _peer_id])
	lobby_created.emit(lobby_id, _peer_id)


## We joined a lobby, relay lobby joined signal.
func _on_lobby_joined(lobby_id: String, peer_id: int):
	_peer_id = peer_id
	_lobby_id = lobby_id
	_is_in_lobby = true
	_rtc_mp.create_client(peer_id)  # actic as a client 
	print("[Webstar] lobby %s joined as peer %d" % [lobby_id, peer_id])
	lobby_joined.emit(lobby_id, peer_id)
	

func _create_peer(peer_id: int) -> WebRTCPeerConnection:
	print("[Webstar] Creating a WebRTCPeerConnection for peer %d" % peer_id)
	var peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
	peer.initialize({
		"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ]
	})
	peer.session_description_created.connect(_on_session_description_created.bind(peer_id))
	peer.ice_candidate_created.connect(_new_ice_candidate.bind(peer_id))
	_rtc_mp.add_peer(peer, peer_id)
	
	# host always creates offer
	if _peer_id == 1:                 
		print("[Webstar] I am host, creating an offer")
		peer.create_offer()
	
	if !_is_mutiplayer_set:
		multiplayer.multiplayer_peer = _rtc_mp
		_is_mutiplayer_set = true
		
	return peer


## A peer joined
func _on_peer_joined(peer_id):
	print("[Webstar] peer %d joined, creating WebRTCPeer" % peer_id)
	_create_peer(peer_id)


func _new_ice_candidate(mid: String, index: int, sdp: String, peer_id: int) -> void:
	_send_candidate(peer_id, mid, index, sdp)


## Callback from WebRTCPeerConnect when it creates an offer.
func _on_session_description_created(type: String, data: String, peer_id: int) -> void:
	print("[Webstar] session description created")
	if not _rtc_mp.has_peer(peer_id):
		return
	print("created", type)
	_rtc_mp.get_peer(peer_id).connection.set_local_description(type, data)
	if type == "offer": _send_offer(peer_id, data)
	else: _send_answer(peer_id, data)
	
	
func _on_offer_received(peer_id: int, offer: String) -> void:
	print("Got offer: %d" % peer_id)
	if !_rtc_mp.has_peer(peer_id):
		_create_peer(peer_id)
	_rtc_mp.get_peer(peer_id).connection.set_remote_description("offer", offer)


func _on_answer_received(peer_id: int, answer: String) -> void:
	print("Got answer: %d" % peer_id)
	if _rtc_mp.has_peer(peer_id):
		_rtc_mp.get_peer(peer_id).connection.set_remote_description("answer", answer)


func _on_candidate_received(peer_id: int, mid: String, index: int, sdp: String) -> void:
	print("[Webstar] candidate received")
	if _rtc_mp.has_peer(peer_id):
		_rtc_mp.get_peer(peer_id).connection.add_ice_candidate(mid, index, sdp)
	else: "no peer to receive candidate"


func _send_offer(peer_id: int, data: String) -> void:
	print("[Webstar] Sending offer: %s" % data)
	_signal_client.send_message({
		"type": "offer",
		"targetPeerId": peer_id,
		"data": data
	})
		

func _send_answer(peerId: int, data: String) -> void:
	print("[Webstar] Sending answer: %s" % data)
	_signal_client.send_message({
		"type": "answer",
		"targetPeerId": peerId,
		"data": data
	})
	

func _send_candidate(peer_id: int, mid: String, index: int, sdp: String) -> void:
	_signal_client.send_message({
		"type": "candidate",
		"targetPeerId": peer_id,
		"mid": mid,
		"index": index,
		"sdp": sdp
	})
