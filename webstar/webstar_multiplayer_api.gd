## High-level multiplayer integration for WebStar networking
## Provides integration with Godot's built-in multiplayer system
class_name WebStarMultiplayerAPI
extends MultiplayerAPIExtension

signal peer_connected_api(id: int)
signal peer_disconnected_api(id: int)

var webstar_manager: WebStarManager
var peer_id_mapping: Dictionary = {}  # webstar_player_id -> godot_peer_id
var reverse_peer_mapping: Dictionary = {}  # godot_peer_id -> webstar_player_id
var next_peer_id: int = 2  # Start from 2 (1 is reserved for server/host)
var is_initialized: bool = false

func _init(manager: WebStarManager = null):
	if manager:
		set_webstar_manager(manager)

func set_webstar_manager(manager: WebStarManager):
	"""Set the WebStar manager and connect signals."""
	webstar_manager = manager
	
	if webstar_manager:
		# Connect WebStar signals to API
		webstar_manager.player_joined.connect(_on_webstar_player_joined)
		webstar_manager.player_left.connect(_on_webstar_player_left)
		webstar_manager.host_changed.connect(_on_webstar_host_changed)
		webstar_manager.lobby_joined.connect(_on_webstar_lobby_joined)
		webstar_manager.message_received.connect(_on_webstar_message_received)

# MultiplayerAPI overrides
func _poll():
	"""Poll the multiplayer API for updates."""
	if webstar_manager:
		# WebStar handles its own polling internally
		pass

func _rpc(peer: int, object: Object, method: StringName, args: Array) -> int:
	"""Send RPC call through WebStar."""
	if not webstar_manager or not webstar_manager.is_connected:
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	
	# Convert Godot peer ID to WebStar player ID
	var target_player_id = reverse_peer_mapping.get(peer, -1)
	if target_player_id == -1 and peer != 0:  # 0 means broadcast
		return MultiplayerPeer.CONNECTION_DISCONNECTED
	
	# Prepare RPC data
	var rpc_data = {
		"object_path": str(object.get_path()) if object.has_method("get_path") else "",
		"method": method,
		"args": args,
		"rpc_id": _generate_rpc_id()
	}
	
	# Send via WebStar
	if peer == 0:  # Broadcast
		webstar_manager.broadcast_message("godot_rpc", rpc_data)
	else:
		webstar_manager.send_message(target_player_id, "godot_rpc", rpc_data)
	
	return OK

func _object_configuration_add(object: Object, config: Variant) -> int:
	"""Add object configuration for networking."""
	# Store object configuration if needed
	return OK

func _object_configuration_remove(object: Object) -> int:
	"""Remove object configuration."""
	# Clean up object configuration if needed
	return OK

func _get_unique_id() -> int:
	"""Get unique ID for this peer."""
	if webstar_manager:
		return _get_godot_peer_id(webstar_manager.local_player_id)
	return 1

func _get_peer_ids() -> PackedInt32Array:
	"""Get all connected peer IDs."""
	var peer_ids = PackedInt32Array()
	
	if webstar_manager:
		for player_id in webstar_manager.get_connected_players():
			var godot_peer_id = _get_godot_peer_id(player_id)
			peer_ids.append(godot_peer_id)
	
	return peer_ids

func _get_remote_sender_id() -> int:
	"""Get the sender ID of the current RPC."""
	# This would need to be set during RPC processing
	return 0

# WebStar signal handlers
func _on_webstar_player_joined(player_id: int, player_info: Dictionary):
	"""Handle player joining in WebStar."""
	var godot_peer_id = _get_godot_peer_id(player_id)
	
	print("WebStar player joined: ", player_id, " -> Godot peer: ", godot_peer_id)
	
	# Emit Godot multiplayer signal
	peer_connected_api.emit(godot_peer_id)
	
	# Call the built-in peer connected signal
	if has_signal("peer_connected"):
		emit_signal("peer_connected", godot_peer_id)

func _on_webstar_player_left(player_id: int):
	"""Handle player leaving in WebStar."""
	var godot_peer_id = peer_id_mapping.get(player_id, -1)
	
	if godot_peer_id != -1:
		print("WebStar player left: ", player_id, " -> Godot peer: ", godot_peer_id)
		
		# Clean up mappings
		peer_id_mapping.erase(player_id)
		reverse_peer_mapping.erase(godot_peer_id)
		
		# Emit Godot multiplayer signal
		peer_disconnected_api.emit(godot_peer_id)
		
		# Call the built-in peer disconnected signal
		if has_signal("peer_disconnected"):
			emit_signal("peer_disconnected", godot_peer_id)

func _on_webstar_host_changed(new_host_id: int):
	"""Handle host change in WebStar."""
	print("WebStar host changed to: ", new_host_id)
	
	# Update authority if needed
	# The host in WebStar should be peer ID 1 in Godot
	if new_host_id == webstar_manager.local_player_id:
		print("We are now the host")

func _on_webstar_lobby_joined(lobby_id: String, player_id: int):
	"""Handle lobby joined in WebStar."""
	is_initialized = true
	print("WebStar lobby joined: ", lobby_id, ", player ID: ", player_id)

func _on_webstar_message_received(sender_id: int, message_name: String, data: Dictionary):
	"""Handle messages received through WebStar."""
	if message_name == "godot_rpc":
		_handle_godot_rpc(sender_id, data)

func _handle_godot_rpc(sender_id: int, rpc_data: Dictionary):
	"""Handle Godot RPC messages received through WebStar."""
	var object_path = rpc_data.get("object_path", "")
	var method = rpc_data.get("method", "")
	var args = rpc_data.get("args", [])
	
	if object_path == "" or method == "":
		push_warning("Invalid RPC data received")
		return
	
	# Get the object by path
	var object = get_tree().get_node_or_null(NodePath(object_path))
	if not object:
		push_warning("RPC target object not found: " + object_path)
		return
	
	# Set the remote sender ID context
	var godot_sender_id = _get_godot_peer_id(sender_id)
	
	# Call the method
	if object.has_method(method):
		object.callv(method, args)
	else:
		push_warning("RPC method not found: " + method + " on " + object_path)

# Helper methods
func _get_godot_peer_id(webstar_player_id: int) -> int:
	"""Convert WebStar player ID to Godot peer ID."""
	if webstar_player_id == webstar_manager.local_player_id:
		return 1  # Local player is always peer 1
	
	if not peer_id_mapping.has(webstar_player_id):
		# Assign new Godot peer ID
		var godot_peer_id = next_peer_id
		next_peer_id += 1
		
		peer_id_mapping[webstar_player_id] = godot_peer_id
		reverse_peer_mapping[godot_peer_id] = webstar_player_id
	
	return peer_id_mapping[webstar_player_id]

func _generate_rpc_id() -> String:
	"""Generate unique RPC ID."""
	return "rpc_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000)

# Public API
func is_connected() -> bool:
	"""Check if multiplayer is connected."""
	return webstar_manager != null and webstar_manager.is_connected

func get_webstar_player_id(godot_peer_id: int) -> int:
	"""Get WebStar player ID from Godot peer ID."""
	return reverse_peer_mapping.get(godot_peer_id, -1)

func get_player_info(godot_peer_id: int) -> Dictionary:
	"""Get player information."""
	var webstar_player_id = get_webstar_player_id(godot_peer_id)
	if webstar_player_id == -1:
		return {}
	
	var player_info = webstar_manager.get_player_info(webstar_player_id)
	if player_info:
		return {
			"webstar_id": webstar_player_id,
			"godot_id": godot_peer_id,
			"username": player_info.username,
			"ping": player_info.ping,
			"state": player_info.state
		}
	
	return {}

func send_webstar_message(target_player_id: int, message_name: String, data: Dictionary):
	"""Send a WebStar message directly (bypassing Godot RPC)."""
	if webstar_manager:
		webstar_manager.send_message(target_player_id, message_name, data)

func broadcast_webstar_message(message_name: String, data: Dictionary):
	"""Broadcast a WebStar message directly."""
	if webstar_manager:
		webstar_manager.broadcast_message(message_name, data)
