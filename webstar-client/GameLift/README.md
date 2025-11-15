# GameLift Integration for WebStar

This GameLiftManager provides AWS GameLift Server SDK integration for Godot headless game servers.

## Features

- **Automatic GameLift Integration**: Detects headless mode and initializes GameLift automatically
- **Player Session Management**: Handles player session creation, acceptance, and termination
- **Game Session Lifecycle**: Manages game session start/end events
- **Health Monitoring**: Provides health check callbacks for GameLift
- **Event Logging**: Structured logging for GameLift events
- **Command Line Support**: Parses command line arguments for port and max players

## Setup

### 1. Dependencies

The project already includes the necessary NuGet packages:
- `AWSSDK.GameLiftServer` (5.1.1)
- `Newtonsoft.Json` (13.0.3)

### 2. GameLift Fleet Configuration

When setting up your GameLift fleet, use these launch parameters:

```bash
# Example launch path for your Godot headless server
./WebstarClient.exe -port 7777 -maxplayers 8
```

### 3. Build Configuration

For GameLift deployment, build your Godot project as a headless server:

```bash
# Export as Linux Server (headless)
godot --headless --export-release "Linux/X11" WebstarClient.x86_64

# Or Windows Server (headless)  
godot --headless --export-release "Windows Desktop" WebstarClient.exe
```

## Usage

### Basic Integration

The GameLiftManager is automatically initialized when running in headless mode. It integrates with the existing NetworkManager:

```gdscript
# Check if running on GameLift
if NetworkManager.is_running_on_gamelift():
    print("Running on AWS GameLift")
    
    # Get current status
    var status = NetworkManager.get_gamelift_status()
    print("GameLift Status: ", status)
```

### Player Session Management

```gdscript
# When a player connects via your game client
func on_player_connected(player_id: String, player_session_id: String):
    # Accept the player session in GameLift
    if NetworkManager.accept_player_session(player_session_id):
        print("Player session accepted: ", player_session_id)
    else:
        print("Failed to accept player session")
        # Disconnect the player

# When a player disconnects
func on_player_disconnected(player_session_id: String):
    NetworkManager.remove_player_session(player_session_id)
```

### Event Logging

```gdscript
# Log custom game events for GameLift analytics
NetworkManager.log_gamelift_event("player_killed", {
    "killer_id": "player_123",
    "victim_id": "player_456",
    "weapon": "sword",
    "map_location": Vector2(100, 200)
})

NetworkManager.log_gamelift_event("match_ended", {
    "winner": "player_123",
    "match_duration": 180,
    "final_score": {"player_123": 1500, "player_456": 800}
})
```

### Signal Connections

The GameLiftManager emits several signals that you can connect to:

```gdscript
func _ready():
    if NetworkManager.gamelift_manager:
        NetworkManager.gamelift_manager.connect("game_session_started", _on_game_session_started)
        NetworkManager.gamelift_manager.connect("player_session_created", _on_player_session_created)
        NetworkManager.gamelift_manager.connect("game_lift_error", _on_gamelift_error)

func _on_game_session_started(game_session_id: String):
    print("Game session started: ", game_session_id)
    # Initialize your game state here

func _on_player_session_created(player_session_id: String, player_id: String):
    print("New player session: ", player_session_id)
    # Handle new player joining

func _on_gamelift_error(error: String):
    print("GameLift error: ", error)
    # Handle GameLift errors
```

## Command Line Arguments

The server supports these command line arguments:

- `-port <number>`: Set the server port (default: 7777)
- `-maxplayers <number>`: Set maximum players (default: 8)

Example:
```bash
./WebstarClient.exe -port 7777 -maxplayers 16
```

## GameLift Fleet Setup

### 1. Create a GameLift Build

```bash
# Upload your game server build
aws gamelift create-build \
    --name "webstar-server" \
    --build-version "1.0.0" \
    --storage-location "Bucket=your-s3-bucket,Key=webstar-server.zip"
```

### 2. Create a Fleet

```bash
aws gamelift create-fleet \
    --name "webstar-fleet" \
    --build-id "build-12345678-1234-1234-1234-123456789012" \
    --ec2-instance-type "c5.large" \
    --fleet-type "ON_DEMAND" \
    --runtime-configuration "GameSessionActivationTimeoutSeconds=600,MaxConcurrentGameSessionActivations=1,ServerProcesses=[{LaunchPath=/local/game/WebstarClient.x86_64,Parameters=-port 7777 -maxplayers 8,ConcurrentExecutions=1}]"
```

### 3. Create Game Session Queue

```bash
aws gamelift create-game-session-queue \
    --name "webstar-queue" \
    --destinations "DestinationArn=arn:aws:gamelift:us-west-2:123456789012:fleet/fleet-12345678-1234-1234-1234-123456789012"
```

## Logging

The GameLiftManager creates logs in the `/logs/` directory:
- `game.log`: Game-specific events and errors
- `engine.log`: Godot engine logs

These logs are automatically uploaded to GameLift for monitoring and debugging.

## Troubleshooting

### Common Issues

1. **GameLift not initializing**: Check that you're running in headless mode and the GameLift Server SDK is properly installed.

2. **Player sessions not accepted**: Ensure you call `AcceptPlayerSession()` when players connect.

3. **Game session not activating**: Make sure you call the activation methods in response to GameLift callbacks.

### Debug Information

Check the console output for GameLift status:
```gdscript
# Print current GameLift status
print(NetworkManager.get_gamelift_status())
```

### Log Files

Monitor the log files created by GameLift:
- Check `/logs/game.log` for application-specific logs
- Check `/logs/engine.log` for Godot engine logs
- Use CloudWatch to monitor GameLift fleet metrics

## Best Practices

1. **Health Checks**: The GameLiftManager automatically handles health checks, but ensure your game loop doesn't block.

2. **Graceful Shutdown**: The system handles GameLift termination requests automatically.

3. **Error Handling**: Always check return values when calling GameLift methods.

4. **Logging**: Use the event logging system to track important game events for analytics.

5. **Resource Cleanup**: Player sessions are automatically cleaned up on disconnection.

## Integration with WebStar

The GameLiftManager integrates seamlessly with WebStar's networking:

- Game sessions use the GameLift session ID as the WebStar lobby name
- Player limits are synchronized between GameLift and WebStar
- WebRTC connections are established after GameLift player session acceptance

This provides a complete solution for scalable multiplayer gaming using AWS GameLift infrastructure with WebRTC peer-to-peer networking.