# WebStar Development Notes

## Current Status
- ✅ Core WebSocket connectivity working (Godot ↔ .NET server)
- ✅ Basic lobby join/leave functionality implemented
- ✅ Clean project structure established
- 🔄 WebRTC integration pending
- 🔄 Production deployment pending

## Known Working Components
- .NET 9 WebSocket server (`webstar-server-dotnet/`)
- Godot WebStar plugin (`webstar-test-client/addons/webstar/`)
- Basic lobby management
- Player messaging protocol

## Development Environment
- Godot 4.4.1
- .NET 9 SDK
- Windows development environment

## Key Decisions Made
1. **Switched from Node.js to .NET**: Node.js `ws` library had compatibility issues with Godot WebSocketPeer
2. **Kept project private**: Currently in active development phase
3. **Clean architecture**: Separated concerns between plugin, server, and test client

## Next Development Priorities
1. Complete WebRTC signaling implementation
2. Add production-ready server features (auth, rate limiting, etc.)
3. Create comprehensive testing suite
4. Performance optimization
5. Documentation completion

## Testing Workflow
```bash
# Terminal 1: Start server
cd webstar-server-dotnet/WebStarServer
dotnet run

# Terminal 2: Test client
cd webstar-test-client
godot --path . --headless
```

## Directory Structure
```
webstar/                          # Main project
├── webstar-server-dotnet/        # .NET server (working)
└── webstar-test-client/          # Addon development environment
    └── addons/webstar/           # The WebStar addon (source of truth)
```
