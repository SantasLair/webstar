## Host migration system for WebStar networking
## Handles switching hosts when the current host disconnects
class_name WebStarHostMigration
extends RefCounted

signal migration_started(new_host_id: int)
signal migration_completed(new_host_id: int)
signal migration_failed(reason: String)

enum MigrationState {
	IDLE,
	SELECTING_HOST,
	WAITING_FOR_CONNECTIONS,
	MIGRATING_STATE,
	COMPLETED,
	FAILED
}

var config: WebStarConfig
var webstar_manager: WebStarManager
var current_state: MigrationState = MigrationState.IDLE
var new_host_id: int = 0
var migration_start_time: int = 0
var expected_connections: Array[int] = []
var connected_players: Array[int] = []

# Migration timeout timer
var migration_timer: Timer

func _init(p_config: WebStarConfig):
	config = p_config
	_setup_migration_timer()

func set_webstar_manager(manager: WebStarManager):
	webstar_manager = manager

func start_migration(target_host_id: int = 0):
	"""Start host migration process."""
	if current_state != MigrationState.IDLE:
		push_warning("Host migration already in progress")
		return
	
	if not config.enable_host_migration:
		push_warning("Host migration is disabled")
		migration_failed.emit("Host migration disabled")
		return
	
	print("Starting host migration...")
	current_state = MigrationState.SELECTING_HOST
	migration_start_time = Time.get_ticks_msec()
	
	# Select new host
	if target_host_id > 0:
		new_host_id = target_host_id
	else:
		new_host_id = _select_new_host()
	
	if new_host_id == 0:
		_handle_migration_failure("No suitable host found")
		return
	
	migration_started.emit(new_host_id)
	
	# Notify signaling server about host migration
	if webstar_manager and webstar_manager.signaling_client:
		webstar_manager.signaling_client.request_host_migration()
	
	# Start migration process
	_begin_migration()

func _select_new_host() -> int:
	"""Select a new host from connected players."""
	if not webstar_manager:
		return 0
	
	var connected_players = webstar_manager.get_connected_players()
	
	# Remove current host from candidates
	var current_host = webstar_manager.host_player_id
	connected_players.erase(current_host)
	
	if connected_players.is_empty():
		return 0
	
	# Strategy 1: Select player with lowest ID (deterministic)
	if config.auto_select_new_host:
		connected_players.sort()
		return connected_players[0]
	
	# Strategy 2: Select player with best connection (lowest ping)
	var best_candidate = connected_players[0]
	var best_ping = webstar_manager.get_ping(best_candidate)
	
	for player_id in connected_players:
		var ping = webstar_manager.get_ping(player_id)
		if ping >= 0 and (best_ping < 0 or ping < best_ping):
			best_candidate = player_id
			best_ping = ping
	
	return best_candidate

func _begin_migration():
	"""Begin the migration process."""
	current_state = MigrationState.WAITING_FOR_CONNECTIONS
	
	# Get list of players that should reconnect to new host
	expected_connections = webstar_manager.get_connected_players()
	expected_connections.erase(new_host_id)  # New host doesn't need to connect to itself
	connected_players.clear()
	
	if webstar_manager.local_player_id == new_host_id:
		# We are becoming the new host
		_become_new_host()
	else:
		# We need to connect to the new host
		_connect_to_new_host()
	
	# Start migration timeout
	migration_timer.start()

func _become_new_host():
	"""Handle becoming the new host."""
	print("Becoming new host (ID: ", new_host_id, ")")
	
	webstar_manager.is_host = true
	webstar_manager.host_player_id = new_host_id
	
	# Disconnect from old host connections
	webstar_manager.webrtc_manager.disconnect_all()
	webstar_manager.relay_manager.disconnect_all()
	
	# Wait for other players to connect to us
	if expected_connections.is_empty():
		# No other players, migration complete
		_complete_migration()
	else:
		# Wait for players to reconnect
		current_state = MigrationState.WAITING_FOR_CONNECTIONS
		print("Waiting for ", expected_connections.size(), " players to reconnect...")

func _connect_to_new_host():
	"""Connect to the new host."""
	print("Connecting to new host (ID: ", new_host_id, ")")
	
	webstar_manager.is_host = false
	webstar_manager.host_player_id = new_host_id
	
	# Disconnect from old connections
	webstar_manager.webrtc_manager.disconnect_all()
	webstar_manager.relay_manager.disconnect_all()
	
	# Get new host's peer info
	var new_host_info = webstar_manager.get_player_info(new_host_id)
	if not new_host_info:
		_handle_migration_failure("New host info not found")
		return
	
	# Try to establish connection to new host
	if new_host_info.peer_id != "":
		# Try WebRTC first
		webstar_manager.webrtc_manager.connect_to_peer(new_host_info.peer_id, new_host_id)
	else:
		# Fallback to relay
		webstar_manager.relay_manager.connect_to_player(new_host_id)
	
	current_state = MigrationState.WAITING_FOR_CONNECTIONS

func handle_player_connected(player_id: int):
	"""Handle a player connection during migration."""
	if current_state != MigrationState.WAITING_FOR_CONNECTIONS:
		return
	
	if webstar_manager.local_player_id == new_host_id:
		# We are the new host, track incoming connections
		if player_id in expected_connections and player_id not in connected_players:
			connected_players.append(player_id)
			print("Player ", player_id, " connected to new host (", connected_players.size(), "/", expected_connections.size(), ")")
			
			# Check if all expected players have connected
			if connected_players.size() >= expected_connections.size():
				_complete_migration()
	else:
		# We connected to the new host
		if player_id == new_host_id:
			print("Connected to new host successfully")
			_complete_migration()

func handle_connection_failed(player_id: int, reason: String):
	"""Handle connection failure during migration."""
	if current_state != MigrationState.WAITING_FOR_CONNECTIONS:
		return
	
	if player_id == new_host_id:
		# Failed to connect to new host
		_handle_migration_failure("Failed to connect to new host: " + reason)
	else:
		# A player failed to connect to us as new host
		# Remove them from expected connections and continue
		expected_connections.erase(player_id)
		
		if webstar_manager.local_player_id == new_host_id:
			print("Player ", player_id, " failed to connect, continuing without them")
			
			# Check if we can complete migration with remaining players
			if connected_players.size() >= expected_connections.size():
				_complete_migration()

func _complete_migration():
	"""Complete the migration process."""
	if current_state == MigrationState.COMPLETED:
		return
	
	print("Host migration completed successfully")
	current_state = MigrationState.COMPLETED
	migration_timer.stop()
	
	# Update host info in all components
	if webstar_manager.heartbeat_manager:
		webstar_manager.heartbeat_manager.start_heartbeats()
	
	migration_completed.emit(new_host_id)
	
	# Reset state for next migration
	_reset_migration_state()

func _handle_migration_failure(reason: String):
	"""Handle migration failure."""
	print("Host migration failed: ", reason)
	current_state = MigrationState.FAILED
	migration_timer.stop()
	
	migration_failed.emit(reason)
	
	# Reset state
	_reset_migration_state()

func _reset_migration_state():
	"""Reset migration state."""
	current_state = MigrationState.IDLE
	new_host_id = 0
	migration_start_time = 0
	expected_connections.clear()
	connected_players.clear()

func _setup_migration_timer():
	"""Setup the migration timeout timer."""
	migration_timer = Timer.new()
	migration_timer.wait_time = config.host_migration_timeout
	migration_timer.one_shot = true
	migration_timer.timeout.connect(_on_migration_timeout)

func _on_migration_timeout():
	"""Handle migration timeout."""
	if current_state == MigrationState.WAITING_FOR_CONNECTIONS:
		if webstar_manager.local_player_id == new_host_id:
			# We are the new host, complete migration with whoever is connected
			print("Migration timeout reached, completing with ", connected_players.size(), " connected players")
			_complete_migration()
		else:
			# We failed to connect to new host in time
			_handle_migration_failure("Migration timeout: failed to connect to new host")
	else:
		_handle_migration_failure("Migration timeout in state: " + str(current_state))

func is_migration_in_progress() -> bool:
	"""Check if migration is currently in progress."""
	return current_state != MigrationState.IDLE and current_state != MigrationState.COMPLETED and current_state != MigrationState.FAILED

func get_migration_progress() -> Dictionary:
	"""Get current migration progress."""
	return {
		"state": current_state,
		"new_host_id": new_host_id,
		"expected_connections": expected_connections.size(),
		"connected_players": connected_players.size(),
		"time_elapsed": Time.get_ticks_msec() - migration_start_time if migration_start_time > 0 else 0
	}
