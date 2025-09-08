# WebStar .NET Server

A .NET 9 WebSocket server implementation for WebStar networking, providing Godot-compatible WebSocket communication.

## Features

- ✅ **Godot Compatible**: Works perfectly with Godot's WebSocketPeer
- ✅ **Lobby Management**: Create, join, leave lobbies
- ✅ **Real-time Messaging**: Bidirectional WebSocket communication
- ✅ **Health Monitoring**: Built-in health check endpoints
- ✅ **Cross-platform**: Runs on Windows, Linux, macOS

## Quick Start

```bash
cd WebStarServer
dotnet run
```

Server will start on `http://localhost:5090`

## Endpoints

- **WebSocket**: `ws://localhost:5090/ws`
- **Health Check**: `http://localhost:5090/health`
- **Stats**: `http://localhost:5090/stats`
- **Lobbies**: `http://localhost:5090/lobbies`

## WebSocket Protocol

### Join Lobby
```json
{
  "type": "join_lobby",
  "lobby_id": "test123",
  "player_info": {
    "username": "Player1"
  }
}
```

### Create Lobby
```json
{
  "type": "create_lobby",
  "name": "My Game",
  "maxPlayers": 8,
  "isPublic": true
}
```

## Architecture

- **ASP.NET Core WebSockets**: For Godot compatibility
- **Concurrent Collections**: Thread-safe state management
- **JSON Protocol**: Simple, human-readable messaging
- **In-memory State**: Fast lobby and player management

## vs Node.js Version

The original Node.js server had compatibility issues with Godot's WebSocketPeer. This .NET implementation provides:

- ✅ **Stable Connections**: No random disconnects
- ✅ **Better Performance**: Lower latency, higher throughput  
- ✅ **Simpler Codebase**: Easier to maintain and extend
- ✅ **Production Ready**: Built on enterprise-grade ASP.NET Core
