# WebStar Networking Addon

A Godot 4 addon that provides WebRTC star topology networking for multiplayer games with WebSocket fallback and host migration.

## Features

- **WebRTC Star Topology**: Efficient P2P networking where the host relays messages between players
- **WebSocket Fallback**: Automatic fallback when WebRTC connections fail
- **Host Migration**: Seamless host migration when the current host disconnects
- **Easy Integration**: Simple API with autoload support
- **Production Ready**: Includes heartbeat monitoring, connection recovery, and error handling

## Installation

1. Copy the `webstar` folder to your project's `addons/` directory
2. Enable the "WebStar Networking" plugin in Project Settings > Plugins
3. The addon will automatically add a `WebStar` autoload

## Quick Start

### Basic Setup

```gdscript
extends Node

func _ready():
    # Configure WebStar
    var config = WebStarConfig.new()
    config.signaling_server_url = "ws://localhost:8080/ws"
    config.relay_server_url = "ws://localhost:8080/relay"
    
    # Initialize the autoload manager
    WebStar.initialize_with_config(config)
    
    # Connect to events
    WebStar.lobby_joined.connect(_on_lobby_joined)
    WebStar.message_received.connect(_on_message_received)
    
    # Join a lobby
    await WebStar.join_lobby("ROOM123", "PlayerName")

func _on_lobby_joined(lobby_id: String, player_id: int):
    print("Joined lobby: ", lobby_id)
    
    # Send a message to all players
    WebStar.broadcast_message("hello", {"text": "Hello everyone!"})

func _on_message_received(sender_id: int, message_name: String, data: Dictionary):
    print("Received: ", message_name, " from ", sender_id)
```

### Server Setup

You'll need a WebStar signaling server. Use the included Node.js server:

```bash
cd addons/webstar/server
npm install
npm start
```

The server runs on `ws://localhost:8080` by default.

## Configuration

Create a `WebStarConfig` resource to customize the networking behavior:

```gdscript
var config = WebStarConfig.new()

# Server settings
config.signaling_server_url = "ws://your-server.com:8080/ws"
config.relay_server_url = "ws://your-server.com:8080/relay"

# WebRTC settings
config.webrtc_enabled = true
config.add_turn_server("turn:your-turn-server.com:3478", "username", "password")

# Fallback and recovery
config.use_websocket_fallback = true
config.auto_reconnect = true
config.enable_host_migration = true

# Performance tuning
config.heartbeat_interval = 2.0
config.enable_compression = true

# Apply mobile optimizations
config.set_mobile_optimized()
```

## API Reference

### WebStarManager (Autoload: WebStar)

#### Methods

- `join_lobby(lobby_id: String, username: String) -> bool`
- `leave_lobby()`
- `start_game() -> bool` (host only)
- `send_message(target_player_id: int, message_name: String, data: Dictionary)`
- `broadcast_message(message_name: String, data: Dictionary)`
- `get_player_count() -> int`
- `is_player_connected(player_id: int) -> bool`
- `get_ping(player_id: int) -> int`

#### Signals

- `lobby_joined(lobby_id: String, player_id: int)`
- `lobby_left()`
- `player_joined(player_id: int, player_info: Dictionary)`
- `player_left(player_id: int)`
- `host_changed(new_host_id: int)`
- `message_received(sender_id: int, message_name: String, data: Dictionary)`
- `game_started()`
- `connection_failed(player_id: int, reason: String)`

#### Properties

- `is_host: bool` - Whether this player is the lobby host
- `local_player_id: int` - This player's unique ID
- `lobby_id: String` - Current lobby ID
- `is_connected: bool` - Connection status

### WebStarConfig

Configuration resource with all networking settings. See the configuration section above for details.

## Architecture

### Star Topology

WebStar uses a star topology where one player acts as the host:

```
Player 2 ←→ Host (Player 1) ←→ Player 3
                ↕
            Player 4
```

- **Host relays** all messages between players
- **Efficient**: O(N) messages instead of O(N²) 
- **Cost-effective**: No dedicated server required
- **Scalable**: Works well for 2-8 players

### Connection Flow

1. **Join Lobby**: Connect to signaling server and join a lobby
2. **WebRTC Setup**: Exchange connection info through signaling server
3. **P2P Connection**: Establish direct WebRTC connections to host
4. **Fallback**: Use WebSocket relay if WebRTC fails
5. **Host Migration**: Automatically handle host disconnection

### Message Types

- **System Messages**: Handled internally (heartbeats, host migration)
- **User Messages**: Your game messages sent via `send_message()`
- **Broadcast Messages**: Messages sent to all players

## Examples

### Position Synchronization

```gdscript
# Send position updates
func _physics_process(delta):
    if WebStar.is_connected:
        WebStar.broadcast_message("position", {
            "x": global_position.x,
            "y": global_position.y,
            "velocity_x": velocity.x,
            "velocity_y": velocity.y
        })

# Handle received positions
func _on_message_received(sender_id: int, message_name: String, data: Dictionary):
    if message_name == "position":
        update_player_position(sender_id, Vector2(data.x, data.y))
```

### Game State Management

```gdscript
# Host manages game state
func _on_player_joined(player_id: int, player_info: Dictionary):
    if WebStar.is_host:
        # Send current game state to new player
        WebStar.send_message(player_id, "game_state", {
            "level": current_level,
            "score": player_scores,
            "time_remaining": timer.time_left
        })

# Start game (host only)
func start_multiplayer_game():
    if WebStar.is_host and WebStar.get_player_count() >= 2:
        WebStar.start_game()
        WebStar.broadcast_message("game_start", {
            "level": selected_level,
            "mode": game_mode
        })
```

### Host Migration Handling

```gdscript
func _on_host_changed(new_host_id: int):
    if new_host_id == WebStar.local_player_id:
        # I became the host
        print("I am now the host!")
        become_host()
    else:
        # Someone else became host
        print("New host: ", new_host_id)
        follow_new_host(new_host_id)

func become_host():
    # Take over host responsibilities
    # Sync game state with other players
    WebStar.broadcast_message("host_sync", get_current_game_state())
```

## Server Setup

### Using the Included Server

The addon includes a Node.js WebSocket server:

```bash
cd addons/webstar/server
npm install
npm start
```

### Environment Configuration

Create a `.env` file:

```env
HOST=0.0.0.0
PORT=8080
ALLOWED_ORIGINS=http://localhost:3000,https://yourgame.com
MAX_LOBBIES=1000
LOG_LEVEL=info
```

### Production Deployment

For production, deploy the server with:
- SSL/TLS encryption (wss://)
- TURN servers for NAT traversal
- Load balancing for multiple server instances
- Monitoring and logging

## Troubleshooting

### Common Issues

1. **Connection Timeouts**: Check firewall settings and server URL
2. **WebRTC Failures**: Ensure STUN/TURN servers are configured
3. **High Latency**: Enable compression and optimize heartbeat intervals
4. **Host Migration Loops**: Check network stability and migration timeout settings

### Debug Mode

Enable debug logging:

```gdscript
var config = WebStarConfig.new()
config.enable_debug_mode()
WebStar.initialize_with_config(config)
```

### Performance Optimization

- Use `set_mobile_optimized()` for mobile games
- Use `set_lan_optimized()` for local network play
- Enable compression for large messages
- Adjust heartbeat intervals based on game requirements

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please see CONTRIBUTING.md for guidelines.

## Support

- **Issues**: Report bugs on GitHub
- **Discussions**: Join our Discord community
- **Documentation**: Full docs at [webstar-networking.dev](https://webstar-networking.dev)
