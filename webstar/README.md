# WebStar Networking Package

A comprehensive WebRTC star topology networking system for Godot, inspired by GDevelop's multiplayer implementation.

## Features

- **WebRTC Star Topology**: Host-based P2P networking with automatic relay
- **WebSocket Signaling**: Reliable connection coordination and lobby management  
- **WebSocket Relay Fallback**: Automatic fallback when WebRTC fails
- **Host Migration**: Seamless host transitions when the host disconnects
- **Heartbeat Monitoring**: Connection health monitoring and ping measurement
- **High-Level Integration**: Optional integration with Godot's multiplayer API
- **Comprehensive Error Handling**: Multi-layer connection failure detection and recovery

## Quick Start

```gdscript
# Create and configure WebStar
var config = WebStarConfig.new()
config.set_signaling_server("ws://your-server.com:8080/ws")

var webstar = WebStarManager.new(config)

# Connect to lobby
await webstar.join_lobby("my_lobby", "PlayerName")

# Send messages
webstar.broadcast_message("chat", {"text": "Hello World!"})

# Handle events
webstar.message_received.connect(_on_message_received)
```

## Architecture

### Core Components

1. **WebStarManager**: Main networking coordinator
2. **WebStarSignalingClient**: WebSocket signaling for lobby coordination
3. **WebStarWebRTCManager**: WebRTC P2P connection management
4. **WebStarRelayManager**: WebSocket relay fallback system
5. **WebStarHeartbeatManager**: Connection monitoring and ping measurement
6. **WebStarHostMigration**: Host migration coordination
7. **WebStarMultiplayerAPI**: High-level Godot multiplayer integration

### Network Topology

```
WebSocket Signaling Server
         |
    [Host Player] ←--WebRTC--> [Player 2]
         |
    WebRTC/Relay
         |
    [Player 3] ←--WebRTC--> [Player 4]
```

- **Host relays all messages** between non-host players
- **WebRTC used for low-latency P2P** communication
- **WebSocket relay as fallback** when WebRTC fails
- **Signaling server coordinates** lobby and host migration

## Configuration

```gdscript
var config = WebStarConfig.new()

# Signaling server
config.set_signaling_server("ws://localhost:8080/ws")
config.set_relay_server("ws://localhost:8080/relay")

# WebRTC settings
config.add_turn_server("turn:your-turn.com:3478", "user", "pass")
config.force_relay_only = false  # Use STUN + TURN

# Host migration
config.enable_host_migration = true
config.host_migration_timeout = 15.0

# Connection monitoring
config.heartbeat_interval = 2.0
config.heartbeat_timeout = 8.0
config.auto_reconnect = true

# Fallback options
config.use_websocket_fallback = true
config.max_reconnect_attempts = 3

# Performance tuning
config.enable_compression = true
config.compression_threshold = 1024
```

## Usage Examples

### Basic Lobby System

```gdscript
extends Node

var webstar: WebStarManager

func _ready():
    var config = WebStarConfig.new()
    config.set_signaling_server("ws://localhost:8080/ws")
    
    webstar = WebStarManager.new(config)
    webstar.lobby_joined.connect(_on_lobby_joined)
    webstar.player_joined.connect(_on_player_joined)
    webstar.message_received.connect(_on_message_received)

func join_game():
    await webstar.join_lobby("game_room_1", "MyUsername")

func _on_lobby_joined(lobby_id: String, player_id: int):
    print("Joined lobby: ", lobby_id, " as player: ", player_id)
    
    if webstar.is_host:
        print("I am the host!")
        # Start game when ready
        webstar.start_game()

func _on_player_joined(player_id: int, player_info: Dictionary):
    print("Player joined: ", player_info.username)

func _on_message_received(sender_id: int, message_name: String, data: Dictionary):
    match message_name:
        "player_move":
            update_player_position(sender_id, data.position)
        "chat_message":
            display_chat(data.username, data.text)
```

### Game State Synchronization

```gdscript
# Send player movement
func move_player(new_position: Vector2):
    player.position = new_position
    
    # Broadcast to other players
    webstar.broadcast_message("player_move", {
        "position": new_position,
        "timestamp": Time.get_ticks_msec()
    })

# Handle received movement
func update_player_position(player_id: int, position: Vector2):
    var player_node = get_player_node(player_id)
    if player_node:
        player_node.position = position
```

### Host Migration Handling

```gdscript
func _ready():
    webstar.host_changed.connect(_on_host_changed)

func _on_host_changed(new_host_id: int):
    print("New host: ", new_host_id)
    
    if webstar.is_host:
        # We became the host - take over game logic
        setup_host_responsibilities()
    else:
        # Connect to new host
        print("Connecting to new host...")
```

### High-Level Multiplayer Integration

```gdscript
extends Node

var webstar_api: WebStarMultiplayerAPI

func _ready():
    var webstar = WebStarManager.new()
    webstar_api = WebStarMultiplayerAPI.new(webstar)
    
    # Set as the multiplayer API
    get_tree().set_multiplayer(webstar_api)
    
    # Now you can use standard Godot multiplayer features
    multiplayer.peer_connected.connect(_on_peer_connected)

@rpc("any_peer", "call_local")
func player_action(action_data: Dictionary):
    # This RPC will be sent through WebStar automatically
    handle_player_action(action_data)

func _on_peer_connected(peer_id: int):
    print("Peer connected via WebStar: ", peer_id)
```

## Server Requirements

WebStar requires a signaling server that handles:

### Signaling Messages
- `join_lobby` - Player joins a lobby
- `leave_lobby` - Player leaves a lobby  
- `start_game` - Host starts the game
- `peer_id` - WebRTC peer ID exchange
- `webrtc_signal` - WebRTC signaling (offer/answer/ICE)
- `request_host_migration` - Request new host selection

### Relay Messages (Fallback)
- `join_relay` - Join WebSocket relay
- `relay_data` - Relay data between players
- `broadcast_data` - Broadcast to all players

### Example Server Messages

```json
// Join lobby request
{
  "type": "join_lobby",
  "lobby_id": "room_1",
  "username": "Player1"
}

// Lobby joined response
{
  "type": "lobby_joined", 
  "player_id": 1,
  "player_list": [
    {"player_id": 1, "username": "Player1"},
    {"player_id": 2, "username": "Player2"}
  ]
}

// WebRTC signaling
{
  "type": "webrtc_signal",
  "from_player": 1,
  "to_player": 2,
  "signal": {
    "type": "offer",
    "sdp": "..."
  }
}
```

## Error Handling

WebStar provides comprehensive error handling:

### Connection Failures
- **WebRTC timeout**: Automatic retry with exponential backoff
- **ICE failure**: Restart ICE gathering process  
- **Data channel error**: Fallback to WebSocket relay
- **Host disconnection**: Automatic host migration

### Recovery Strategies
1. **Quick retry**: Immediate reconnection attempt
2. **ICE restart**: Force new ICE candidate gathering
3. **TURN fallback**: Use relay servers only
4. **WebSocket relay**: Fallback to WebSocket-based communication
5. **Host migration**: Select new host and rebuild connections

### Monitoring
- **Heartbeat system**: Regular connection health checks
- **Ping measurement**: Network latency monitoring  
- **Connection state tracking**: Real-time connection status
- **Timeout detection**: Automatic cleanup of dead connections

## Performance Considerations

### Bandwidth Usage
- **Star topology**: O(N) messages per update (host relays)
- **Mesh alternative**: O(N²) messages per update  
- **Compression**: Automatic compression for large messages
- **Message batching**: Combine multiple updates when possible

### Latency Characteristics
- **WebRTC P2P**: 20-100ms typical (depends on network path)
- **WebSocket relay**: 50-150ms typical (via server)
- **Host relay penalty**: +1 hop for non-host communication
- **Heartbeat overhead**: ~100 bytes every 2 seconds per player

### Scalability Limits
- **Recommended**: 2-8 players per lobby
- **Maximum tested**: 16 players
- **Host bottleneck**: Host processes all message relay
- **WebRTC limits**: Browser connection limits (~50-100 total)

## Debugging

Enable debug mode for detailed logging:

```gdscript
var config = WebStarConfig.new()
config.enable_debug_mode()

# Simulate network conditions for testing
config.simulate_packet_loss = 0.1  # 10% packet loss
config.simulate_latency = 50.0     # 50ms additional latency
```

Debug output includes:
- Connection state changes
- Message send/receive logging  
- Heartbeat monitoring
- Host migration progress
- Error conditions and recovery

## License

This WebStar networking package is provided as-is for educational and development purposes. Suitable for both commercial and non-commercial projects.
