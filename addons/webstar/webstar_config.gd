## Configuration for WebStar networking system
@tool
class_name WebStarConfig
extends Resource

# Signaling server configuration
@export var signaling_server_url: String = "ws://localhost:8080/ws"
@export var lobby_heartbeat_interval: float = 30.0  # seconds
@export var connection_timeout: float = 10.0  # seconds

# WebRTC configuration
@export var webrtc_enabled: bool = true
@export var ice_servers: Array[Dictionary] = []
@export var force_relay_only: bool = false  # Force TURN relay usage
@export var webrtc_timeout: float = 10.0  # seconds
@export var webrtc_max_reconnect_attempts: int = 3
@export var webrtc_reconnect_delay: float = 1.0  # seconds

# WebSocket relay fallback configuration
@export var use_websocket_fallback: bool = true
@export var relay_server_url: String = "ws://localhost:8080/relay"
@export var relay_timeout: float = 5.0  # seconds

# Host migration configuration
@export var enable_host_migration: bool = true
@export var host_migration_timeout: float = 15.0  # seconds
@export var auto_select_new_host: bool = true

# Heartbeat configuration
@export var heartbeat_interval: float = 2.0  # seconds
@export var heartbeat_timeout: float = 8.0  # seconds
@export var ping_samples: int = 5  # Number of ping samples to average

# Connection management
@export var auto_reconnect: bool = true
@export var max_reconnect_attempts: int = 3
@export var reconnect_delay: float = 1.0  # seconds

# Debugging
@export var debug_logging: bool = false
@export var simulate_packet_loss: float = 0.0  # 0.0 to 1.0
@export var simulate_latency: float = 0.0  # milliseconds

# Message compression
@export var enable_compression: bool = true
@export var compression_threshold: int = 1024  # bytes

func _init():
	# Set default ICE servers with both STUN and TURN
	if ice_servers.is_empty():
		ice_servers = [
			{"urls": "stun:stun.l.google.com:19302"},
			{"urls": "stun:stun1.l.google.com:19302"},
			# Add TURN servers if available
			# {"urls": "turn:your-turn-server.com:3478", "username": "user", "credential": "pass"}
		]

func add_turn_server(url: String, username: String, credential: String):
	"""Add a TURN server for relay connections."""
	ice_servers.append({
		"urls": url,
		"username": username,
		"credential": credential
	})

func set_signaling_server(url: String):
	"""Set the signaling server URL."""
	signaling_server_url = url

func set_relay_server(url: String):
	"""Set the WebSocket relay server URL."""
	relay_server_url = url

func enable_debug_mode():
	"""Enable debug logging and verbose output."""
	debug_logging = true

func disable_webrtc():
	"""Disable WebRTC and use only WebSocket relay."""
	webrtc_enabled = false
	use_websocket_fallback = true

func set_mobile_optimized():
	"""Optimize settings for mobile devices."""
	webrtc_timeout = 15.0
	heartbeat_interval = 3.0
	heartbeat_timeout = 12.0
	max_reconnect_attempts = 5
	enable_compression = true

func set_lan_optimized():
	"""Optimize settings for LAN play."""
	heartbeat_interval = 1.0
	heartbeat_timeout = 4.0
	webrtc_timeout = 5.0
	auto_reconnect = true

func validate() -> bool:
	"""Validate configuration settings."""
	if signaling_server_url == "":
		push_error("Signaling server URL is required")
		return false
	
	if heartbeat_timeout <= heartbeat_interval:
		push_error("Heartbeat timeout must be greater than heartbeat interval")
		return false
	
	if simulate_packet_loss < 0.0 or simulate_packet_loss > 1.0:
		push_error("Packet loss simulation must be between 0.0 and 1.0")
		return false
	
	return true
