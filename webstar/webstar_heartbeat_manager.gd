## Heartbeat and ping monitoring for WebStar networking
## Monitors connection health and measures latency
class_name WebStarHeartbeatManager
extends RefCounted

signal peer_timeout(player_id: int)
signal ping_updated(player_id: int, ping: int)

class HeartbeatInfo:
	var player_id: int
	var last_heartbeat_sent: int = 0
	var last_heartbeat_received: int = 0
	var ping_samples: Array[int] = []
	var current_ping: int = 0
	var timeout_count: int = 0
	var is_active: bool = false
	
	func _init(p_player_id: int):
		player_id = p_player_id

var config: WebStarConfig
var heartbeat_infos: Dictionary = {}  # player_id -> HeartbeatInfo
var heartbeat_timer: Timer
var webstar_manager: WebStarManager

func _init(p_config: WebStarConfig):
	config = p_config
	_setup_heartbeat_timer()

func set_webstar_manager(manager: WebStarManager):
	webstar_manager = manager

func start_heartbeats():
	"""Start the heartbeat system."""
	if not heartbeat_timer.is_stopped():
		return
	
	heartbeat_timer.start()
	print("Heartbeat system started")

func stop_heartbeats():
	"""Stop the heartbeat system."""
	heartbeat_timer.stop()
	heartbeat_infos.clear()
	print("Heartbeat system stopped")

func start_heartbeat_for_player(player_id: int):
	"""Start monitoring heartbeat for a specific player."""
	if heartbeat_infos.has(player_id):
		heartbeat_infos[player_id].is_active = true
		return
	
	var heartbeat_info = HeartbeatInfo.new(player_id)
	heartbeat_info.is_active = true
	heartbeat_info.last_heartbeat_received = Time.get_ticks_msec()
	heartbeat_infos[player_id] = heartbeat_info
	
	if config.debug_logging:
		print("Started heartbeat monitoring for player: ", player_id)

func stop_heartbeat_for_player(player_id: int):
	"""Stop monitoring heartbeat for a specific player."""
	if heartbeat_infos.has(player_id):
		heartbeat_infos[player_id].is_active = false
		
		if config.debug_logging:
			print("Stopped heartbeat monitoring for player: ", player_id)

func remove_player(player_id: int):
	"""Remove a player from heartbeat monitoring."""
	heartbeat_infos.erase(player_id)

func stop_all():
	"""Stop monitoring all players."""
	for player_id in heartbeat_infos:
		heartbeat_infos[player_id].is_active = false
	
	heartbeat_timer.stop()

func handle_heartbeat_received(sender_id: int, timestamp: int = 0):
	"""Handle a heartbeat received from a player."""
	var heartbeat_info = heartbeat_infos.get(sender_id)
	if not heartbeat_info or not heartbeat_info.is_active:
		return
	
	var current_time = Time.get_ticks_msec()
	heartbeat_info.last_heartbeat_received = current_time
	heartbeat_info.timeout_count = 0
	
	# Calculate ping if timestamp is provided
	if timestamp > 0:
		var ping = current_time - timestamp
		_update_ping(heartbeat_info, ping)
	
	# Send heartbeat response if we're the host
	if webstar_manager and webstar_manager.is_host:
		_send_heartbeat_response(sender_id, timestamp)

func handle_heartbeat_response(sender_id: int, original_timestamp: int):
	"""Handle a heartbeat response from a player."""
	var heartbeat_info = heartbeat_infos.get(sender_id)
	if not heartbeat_info:
		return
	
	var current_time = Time.get_ticks_msec()
	var round_trip_time = current_time - original_timestamp
	var ping = round_trip_time / 2  # One-way latency
	
	_update_ping(heartbeat_info, ping)

func get_ping(player_id: int) -> int:
	"""Get the current ping for a player."""
	var heartbeat_info = heartbeat_infos.get(player_id)
	return heartbeat_info.current_ping if heartbeat_info else -1

func is_player_responsive(player_id: int) -> bool:
	"""Check if a player is responsive (recent heartbeat)."""
	var heartbeat_info = heartbeat_infos.get(player_id)
	if not heartbeat_info or not heartbeat_info.is_active:
		return false
	
	var current_time = Time.get_ticks_msec()
	var time_since_last_heartbeat = current_time - heartbeat_info.last_heartbeat_received
	return time_since_last_heartbeat < (config.heartbeat_timeout * 1000)

# Internal methods
func _setup_heartbeat_timer():
	heartbeat_timer = Timer.new()
	heartbeat_timer.wait_time = config.heartbeat_interval
	heartbeat_timer.autostart = false
	heartbeat_timer.timeout.connect(_process_heartbeats)

func _process_heartbeats():
	"""Process heartbeats - send heartbeats and check for timeouts."""
	var current_time = Time.get_ticks_msec()
	
	for player_id in heartbeat_infos:
		var heartbeat_info = heartbeat_infos[player_id]
		
		if not heartbeat_info.is_active:
			continue
		
		# Send heartbeat if enough time has passed
		var time_since_last_sent = current_time - heartbeat_info.last_heartbeat_sent
		if time_since_last_sent >= (config.heartbeat_interval * 1000):
			_send_heartbeat(heartbeat_info)
		
		# Check for timeout
		var time_since_last_received = current_time - heartbeat_info.last_heartbeat_received
		if time_since_last_received > (config.heartbeat_timeout * 1000):
			heartbeat_info.timeout_count += 1
			
			if heartbeat_info.timeout_count >= 3:  # 3 consecutive timeouts
				if config.debug_logging:
					print("Player ", player_id, " timed out")
				
				heartbeat_info.is_active = false
				peer_timeout.emit(player_id)

func _send_heartbeat(heartbeat_info: HeartbeatInfo):
	"""Send a heartbeat to a player."""
	if not webstar_manager:
		return
	
	var current_time = Time.get_ticks_msec()
	heartbeat_info.last_heartbeat_sent = current_time
	
	var heartbeat_data = {
		"type": "heartbeat",
		"timestamp": current_time,
		"sender_id": webstar_manager.local_player_id
	}
	
	webstar_manager.send_message(heartbeat_info.player_id, "system_heartbeat", heartbeat_data)

func _send_heartbeat_response(target_player_id: int, original_timestamp: int):
	"""Send a heartbeat response."""
	if not webstar_manager:
		return
	
	var response_data = {
		"type": "heartbeat_response",
		"original_timestamp": original_timestamp,
		"timestamp": Time.get_ticks_msec(),
		"sender_id": webstar_manager.local_player_id
	}
	
	webstar_manager.send_message(target_player_id, "system_heartbeat_response", response_data)

func _update_ping(heartbeat_info: HeartbeatInfo, new_ping: int):
	"""Update ping calculation with a new sample."""
	# Add new ping sample
	heartbeat_info.ping_samples.append(new_ping)
	
	# Keep only the last N samples
	if heartbeat_info.ping_samples.size() > config.ping_samples:
		heartbeat_info.ping_samples.pop_front()
	
	# Calculate average ping
	var total_ping = 0
	for ping in heartbeat_info.ping_samples:
		total_ping += ping
	
	var old_ping = heartbeat_info.current_ping
	heartbeat_info.current_ping = total_ping / heartbeat_info.ping_samples.size()
	
	# Emit signal if ping changed significantly
	if abs(heartbeat_info.current_ping - old_ping) > 10:  # 10ms threshold
		ping_updated.emit(heartbeat_info.player_id, heartbeat_info.current_ping)

func get_heartbeat_stats() -> Dictionary:
	"""Get heartbeat statistics for all players."""
	var stats = {}
	
	for player_id in heartbeat_infos:
		var heartbeat_info = heartbeat_infos[player_id]
		stats[player_id] = {
			"ping": heartbeat_info.current_ping,
			"responsive": is_player_responsive(player_id),
			"timeout_count": heartbeat_info.timeout_count,
			"last_heartbeat": heartbeat_info.last_heartbeat_received
		}
	
	return stats
