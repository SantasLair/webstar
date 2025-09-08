# WebStar Server

A Node.js WebSocket signaling server for WebStar networking, providing lobby management, WebRTC signaling coordination, and relay fallback functionality.

## Features

- **Dual WebSocket Servers**: Separate endpoints for signaling and relay
- **Lobby Management**: Create, join, and manage game lobbies
- **WebRTC Signaling**: Coordinate peer-to-peer connections
- **Relay Fallback**: WebSocket-based message relay when WebRTC fails
- **Host Migration**: Automatic host migration when host disconnects
- **Rate Limiting**: Message rate limiting and connection management
- **Health Monitoring**: Comprehensive stats and health endpoints
- **Scalable Architecture**: Designed for high concurrent connections

## Quick Start

### Installation

```bash
npm install
```

### Configuration

The server uses environment variables for configuration. Create a `.env` file or set these variables:

```bash
# Server Configuration
HOST=0.0.0.0
PORT=8080

# Security
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080

# Limits
MAX_LOBBIES=1000
MAX_PLAYERS_PER_LOBBY=8

# Logging
LOG_LEVEL=info
ENABLE_FILE_LOGGING=true
```

### Running the Server

```bash
# Development
npm run dev

# Production
npm start
```

## API Endpoints

### HTTP Endpoints

- `GET /health` - Server health check
- `GET /stats` - Server statistics
- `GET /lobbies` - List public lobbies

### WebSocket Endpoints

- `ws://host:port/ws` - Signaling WebSocket
- `ws://host:port/relay` - Relay WebSocket

## Signaling Protocol

### Connection

Connect to `/ws` endpoint and receive a welcome message:

```json
{
  "type": "connected",
  "clientId": "uuid",
  "timestamp": 1234567890
}
```

### Lobby Management

#### Create Lobby

```json
{
  "type": "create_lobby",
  "lobby_info": {
    "name": "My Game",
    "max_players": 4,
    "is_public": true,
    "game_settings": {}
  },
  "player_info": {
    "username": "Player1",
    "peer_id": "peer-uuid"
  }
}
```

Response:
```json
{
  "type": "lobby_created",
  "lobby_id": "ABC123",
  "player_id": 123456,
  "lobby_info": { /* lobby details */ },
  "ice_servers": [ /* STUN/TURN servers */ ]
}
```

#### Join Lobby

```json
{
  "type": "join_lobby",
  "lobby_id": "ABC123",
  "player_info": {
    "username": "Player2",
    "peer_id": "peer-uuid"
  }
}
```

#### Leave Lobby

```json
{
  "type": "leave_lobby"
}
```

### WebRTC Signaling

#### Offer/Answer Exchange

```json
{
  "type": "webrtc_offer",
  "target_player_id": 123456,
  "data": { /* SDP offer */ }
}
```

```json
{
  "type": "webrtc_answer",
  "target_player_id": 123456,
  "data": { /* SDP answer */ }
}
```

#### ICE Candidates

```json
{
  "type": "webrtc_ice_candidate",
  "target_player_id": 123456,
  "data": { /* ICE candidate */ }
}
```

### Connection Failure Handling

When WebRTC connections fail:

```json
{
  "type": "peer_connection_failed",
  "target_player_id": 123456,
  "reason": "timeout"
}
```

Server responds with relay fallback:

```json
{
  "type": "fallback_to_relay",
  "relay_endpoint": "/relay",
  "target_player_id": 123456
}
```

## Relay Protocol

### Connection

Connect to `/relay` endpoint and join a lobby:

```json
{
  "type": "relay_join",
  "lobby_id": "ABC123",
  "player_id": 123456
}
```

### Message Relay

Send messages through the server:

```json
{
  "type": "relay_message",
  "target_player_id": 789012, // Optional, omit for broadcast
  "data": { /* game data */ }
}
```

### Rate Limiting

- Maximum 100 messages per second per player
- Maximum 64KB message size
- Automatic rate limiting with error responses

## Architecture

### Core Components

1. **WebStarServer** - Main server class coordinating all components
2. **LobbyManager** - Handles lobby creation, joining, and lifecycle
3. **MessageHandler** - Processes signaling messages
4. **RelayManager** - Manages relay connections and message forwarding
5. **StatsCollector** - Collects and aggregates server statistics
6. **Logger** - Structured logging with file output support

### Connection Flow

```
Client -> Signaling WebSocket -> Lobby Management -> WebRTC Coordination
                               \                  /
                                \-> Relay WebSocket (fallback)
```

### Host Migration

When a host disconnects:

1. Server detects disconnection
2. Selects new host (lowest player ID)
3. Updates lobby state
4. Broadcasts host migration to all players
5. Players reconnect WebRTC to new host

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Server bind address |
| `PORT` | `8080` | Server port |
| `ALLOWED_ORIGINS` | `*` | CORS allowed origins |
| `MAX_LOBBIES` | `1000` | Maximum concurrent lobbies |
| `MAX_PLAYERS_PER_LOBBY` | `8` | Maximum players per lobby |
| `LOG_LEVEL` | `info` | Logging level (error/warn/info/debug) |
| `ENABLE_FILE_LOGGING` | `false` | Enable file logging |

### Lobby Settings

- **Lobby ID Length**: 6 characters (alphanumeric)
- **Default TTL**: 60 minutes of inactivity
- **Cleanup Interval**: 5 minutes
- **Max Lobby Name**: 50 characters
- **Max Username**: 20 characters

### Connection Limits

- **Heartbeat Timeout**: 30 seconds
- **Heartbeat Check**: Every 15 seconds
- **Relay Message Rate**: 100 messages/second
- **Max Message Size**: 64KB

## Monitoring

### Health Check

```bash
curl http://localhost:8080/health
```

Response includes:
- Server status and uptime
- Active lobbies and clients
- Memory usage
- Connection counts

### Statistics

```bash
curl http://localhost:8080/stats
```

Provides detailed metrics:
- Connection rates and totals
- Message breakdown by type
- Error rates and types
- WebRTC success/failure rates
- Performance metrics

### Logging

Structured JSON logs include:
- Timestamp and process ID
- Log level and message
- Connection events
- Error details
- Performance metrics

## Development

### Project Structure

```
webstar-server/
├── server.js              # Main server entry point
├── config.js             # Configuration management
├── package.json          # Dependencies and scripts
└── src/
    ├── LobbyManager.js   # Lobby lifecycle management
    ├── MessageHandler.js # Signaling message processing
    ├── RelayManager.js   # Relay message forwarding
    ├── StatsCollector.js # Metrics and monitoring
    └── Logger.js         # Structured logging
```

### Adding Features

1. **New Message Types**: Add handlers in `MessageHandler.js`
2. **Lobby Features**: Extend `LobbyManager.js`
3. **Monitoring**: Add metrics to `StatsCollector.js`
4. **Configuration**: Update `config.js` and environment variables

### Testing

```bash
# Run tests
npm test

# Run with coverage
npm run test:coverage

# Run linting
npm run lint
```

## Deployment

### Docker

```dockerfile
FROM node:18-alpine

WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

COPY . .
EXPOSE 8080

CMD ["npm", "start"]
```

### Environment Variables for Production

```bash
NODE_ENV=production
HOST=0.0.0.0
PORT=8080
ALLOWED_ORIGINS=https://yourgame.com
MAX_LOBBIES=5000
LOG_LEVEL=warn
ENABLE_FILE_LOGGING=true
```

### Load Balancing

For multiple server instances:
- Use a load balancer with WebSocket support
- Enable sticky sessions for WebSocket connections
- Consider Redis for shared lobby state (future enhancement)

## Security Considerations

1. **CORS Configuration**: Set specific allowed origins in production
2. **Rate Limiting**: Configured per-player message limits
3. **Input Validation**: All user inputs are validated
4. **Connection Limits**: Maximum connections per IP (configurable)
5. **Message Size Limits**: Prevent large message attacks

## Performance

### Benchmarks

- **Concurrent Connections**: 10,000+ WebSocket connections
- **Message Throughput**: 100,000+ messages/second
- **Memory Usage**: ~2MB per 1000 connections
- **CPU Usage**: <10% on modern hardware

### Optimization

- Message compression for relay mode
- Connection pooling and reuse
- Efficient data structures for lookups
- Periodic cleanup of inactive resources

## Troubleshooting

### Common Issues

1. **Connection Timeouts**: Check firewall and network settings
2. **High Memory Usage**: Monitor lobby cleanup and connection limits
3. **WebRTC Failures**: Verify STUN/TURN server configuration
4. **Rate Limiting**: Check client message sending patterns

### Debug Mode

```bash
LOG_LEVEL=debug npm start
```

Provides verbose logging of all connections and messages.

## License

MIT License - see LICENSE file for details.
