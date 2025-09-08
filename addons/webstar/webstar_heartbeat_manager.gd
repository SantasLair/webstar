## Heartbeat manager for connection monitoring
@tool
extends Node
class_name WebStarHeartbeatManager

signal peer_timeout(player_id: int)
signal ping_updated(player_id: int, ping: int)

var config: WebStarConfig
var heartbeat_timers: Dictionary = {} # player_id -> Timer
var ping_data: Dictionary = {} # player_id -> {last_ping: timestamp, samples: Array}

func _init(p_config: WebStarConfig = null):
	if p_config:
		config = p_config
	else:
		config = WebStarConfig.new()

func start_heartbeats():
	print("Started heartbeat monitoring")

func start_heartbeat_for_player(player_id: int):
	if heartbeat_timers.has(player_id):
		return
	
	var timer = Timer.new()
	timer.wait_time = config.heartbeat_interval
	timer.autostart = true
	timer.timeout.connect(_send_heartbeat_to_player.bind(player_id))
	add_child(timer)
	
	heartbeat_timers[player_id] = timer
	ping_data[player_id] = {
		"last_ping": Time.get_ticks_msec(),
		"samples": []
	}

func stop_heartbeat_for_player(player_id: int):
	if heartbeat_timers.has(player_id):
		var timer = heartbeat_timers[player_id]
		timer.queue_free()
		heartbeat_timers.erase(player_id)
		ping_data.erase(player_id)

func stop_all():
	for player_id in heartbeat_timers.keys():
		stop_heartbeat_for_player(player_id)

func _send_heartbeat_to_player(player_id: int):
	# Send heartbeat through the appropriate connection
	# This would integrate with WebRTC or relay manager
	ping_data[player_id]["last_ping"] = Time.get_ticks_msec()

func handle_heartbeat_response(player_id: int, timestamp: int):
	if ping_data.has(player_id):
		var now = Time.get_ticks_msec()
		var ping = now - timestamp
		
		var data = ping_data[player_id]
		data.samples.append(ping)
		
		# Keep only recent samples
		if data.samples.size() > config.ping_samples:
			data.samples.pop_front()
		
		# Calculate average ping
		var avg_ping = 0
		for sample in data.samples:
			avg_ping += sample
		avg_ping /= data.samples.size()
		
		ping_updated.emit(player_id, avg_ping)
