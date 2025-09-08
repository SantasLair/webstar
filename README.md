# WebStar 🌟

A Godot 4 networking plugin for creating multiplayer games with WebRTC star topology and WebSocket fallback.

> **Note**: This project is currently in private development.

## 🚀 Quick Start

### 1. Add the Plugin
Copy the `webstar-test-client/addons/webstar/` folder to your Godot project's `addons/` directory.

### 2. Start the Server
```bash
cd webstar-server-dotnet/WebStarServer
dotnet run
```

### 3. Use in Godot
```gdscript
# In your game script
WebStar.initialize()
var success = await WebStar.join_lobby("my-lobby", "Player1")
if success:
    print("Connected to lobby!")
```

## 📁 Project Structure

```
webstar/
├── 📁 webstar-server-dotnet/      # .NET 9 server (recommended)
├── 📁 webstar-test-client/        # Addon development environment
│   └── 📁 addons/webstar/         # The WebStar addon (source of truth)
└── 📄 README.md                   # This file
```

## ✨ Features

- **🎮 Godot 4 Native**: Built specifically for Godot 4.x
- **🔗 WebRTC P2P**: Direct peer-to-peer connections for low latency
- **🔄 WebSocket Fallback**: Automatic fallback for NAT traversal
- **🏠 Lobby System**: Easy lobby creation and management
- **🚀 Production Ready**: Includes .NET server implementation

## 🛠️ Components

### Godot Plugin (`webstar-test-client/addons/webstar/`)
The WebStar networking addon with all functionality.

### .NET Server (`webstar-server-dotnet/`)
High-performance WebSocket signaling server built with .NET 9.
- ✅ Godot WebSocketPeer compatible
- ✅ Cross-platform deployment
- ✅ Production ready

### Test Client (`webstar-test-client/`)
Example Godot project showing WebStar usage.

## 🔧 Development

### Prerequisites
- Godot 4.4.1+
- .NET 9 SDK (for server)

### Testing
1. Start the .NET server: `cd webstar-server-dotnet/WebStarServer && dotnet run`
2. Open `webstar-test-client/` in Godot
3. Run the project to see the demo

## 📚 Documentation

See individual component READMEs:
- [Addon Documentation](webstar-test-client/addons/webstar/README.md)
- [Server Documentation](webstar-server-dotnet/README.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Test with the demo project
4. Submit a pull request

## 📄 License

MIT License - see LICENSE file for details.

---

Made with ❤️ for the Godot community
