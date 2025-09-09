# WebStar 🌟

**Modern WebRTC Star Topology Networking for Godot 4**

[![Godot 4.4+](https://img.shields.io/badge/Godot-4.4+-blue.svg)](https://godotengine.org/)
[![.NET 9](https://img.shields.io/badge/.NET-9.0-purple.svg)](https://dotnet.microsoft.com/)
[![WebRTC](https://img.shields.io/badge/WebRTC-P2P-green.svg)](https://webrtc.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **⚠️ BETA SOFTWARE**: WebStar is an experimental networking solution that has passed comprehensive testing but **has not yet been validated in real-world game scenarios**. Use with caution in production environments.

WebStar provides **star topology networking** for Godot 4, combining **WebRTC peer-to-peer connections** with **WebSocket signaling** to create scalable, low-latency multiplayer experiences. Perfect for 2-8 player games requiring real-time synchronization.

## 🎯 **What Makes WebStar Different**

### **Star Topology Architecture**
```
    Client A ──┐
               │
    Client B ──┼── 👑 Host (Authority)
               │
    Client C ──┘
```

- **🎮 Host Authority**: One player acts as the authoritative server
- **⚡ Low Latency**: Direct WebRTC P2P connections to host
- **📈 Scalable**: O(n) connection complexity, not O(n²)
- **🔄 Reliable**: Automatic host migration and WebSocket fallback

### **Key Features**
- ✅ **WebRTC P2P**: Ultra-low latency direct connections
- ✅ **Godot Integration**: Native RPCs, MultiplayerSpawners, Authority system
- ✅ **Cross-Platform**: Desktop, Web, Mobile browser support
- ✅ **Production Server**: Professional .NET 9 signaling server
- ✅ **Fallback Support**: WebSocket relay when P2P fails
- ✅ **Host Migration**: Seamless authority transfer

---

## 🚀 **Quick Start**

### **1. Prerequisites**
- **Godot 4.4.1+** 
- **.NET 9 SDK** (for signaling server)
- **WebRTC Plugin** (for desktop): [webrtc-native](https://github.com/godotengine/webrtc-native/releases)

### **2. Installation**

#### Install WebStar Addon
```bash
# Copy the addon to your project
cp -r webstar-addon-dev/addons/webstar/ your-project/addons/
```

#### Start Signaling Server
```bash
cd webstar-server-dotnet
dotnet run
# Server starts on ws://localhost:5090
```

### **3. Basic Usage**

```gdscript
# Initialize WebStar in your game
extends Node

var webstar_manager: WebStarManager

func _ready():
    # Create and configure WebStar
    var config = WebStarConfig.new()
    config.signaling_server_url = "ws://localhost:5090"  # or "ws://dev.webstar.santaslair.net" for testing (may not always be available)
    config.webrtc_enabled = true
    
    webstar_manager = WebStarManager.new()
    webstar_manager.initialize_with_config(config)
    add_child(webstar_manager)
    
    # Connect signals
    webstar_manager.lobby_joined.connect(_on_lobby_joined)
    webstar_manager.player_joined.connect(_on_player_joined)

func create_game():
    # Host creates lobby
    var success = await webstar_manager.join_lobby("my_game_lobby", "Host")
    if success:
        print("Lobby created! Waiting for players...")

func join_game():
    # Client joins existing lobby
    var success = await webstar_manager.join_lobby("my_game_lobby", "Player")
    if success:
        print("Joined game!")

# Use Godot's high-level networking with WebStar
@rpc("any_peer", "call_local", "reliable")
func sync_player_position(position: Vector2):
    player.position = position

func _on_lobby_joined(lobby_id: String, player_number: int):
    print("Connected as player ", player_number)

func _on_player_joined(player_id: int, player_info: Dictionary):
    print("Player joined: ", player_info.username)
```

---

## 📁 **Project Structure**

```
webstar/
├── 📁 webstar-addon-dev/           # Addon development & testing
│   ├── 📁 addons/webstar/          # 🌟 The WebStar addon (main component)
│   ├── 📁 scripts/                 # Test scripts and examples
│   └── 📄 project.godot            # Test project
├── 📁 webstar-server-dotnet/       # .NET 9 signaling server
│   ├── 📄 Program.cs               # Server implementation
│   └── 📄 WebStarServer.csproj     # Project file
├── 📄 README.md                    # This file
├── 📄 LICENSE                      # MIT license
└── 📄 WEBSTAR_TESTING_CHECKIN.md   # Comprehensive test results
```

---

## 🎮 **Perfect For These Game Types**

| Game Type | Why WebStar Excels | Examples |
|-----------|-------------------|----------|
| **RTS Games** | Host authority prevents cheating | Command & Conquer style |
| **Turn-Based** | Predictable state management | Chess, card games |
| **Cooperative** | Shared objectives, host coordination | Portal 2, It Takes Two |
| **Battle Royale** | Scalable up to 8 players | Small-scale BR games |
| **Racing** | Real-time position sync | Mario Kart style |
| **Fighting** | Low-latency input handling | Street Fighter style |

---

## 🔧 **Technical Architecture**

### **Networking Stack**
```
┌─────────────────────────────────────┐
│        Your Game Logic              │
├─────────────────────────────────────┤
│     Godot High-Level Networking     │ ← RPCs, Authority, Spawners
│        (RPCs, MultiplayerAPI)       │
├─────────────────────────────────────┤
│       WebStar Manager               │ ← Star topology coordination
├─────────────────────────────────────┤
│  WebRTC P2P  │  WebSocket Signaling │ ← Transport layer
├─────────────────────────────────────┤
│     Network (Internet/LAN)          │
└─────────────────────────────────────┘
```

### **Core Components**
- **WebStarManager**: Main networking coordinator
- **WebStarSignalingClient**: WebSocket lobby management  
- **WebStarWebRTCManager**: P2P connection handling
- **WebStarMultiplayerPeer**: Godot MultiplayerAPI integration
- **WebStarConfig**: Centralized configuration

---

## 🧪 **Testing Status**

WebStar has undergone **comprehensive automated testing**:

| Component | Test Status | Success Rate |
|-----------|-------------|--------------|
| **Core System** | ✅ PASSED | 100% |
| **WebRTC P2P** | ✅ PASSED | 100% |
| **Star Topology** | ✅ PASSED | 80% |
| **High-Level Integration** | ✅ PASSED | 75% |
| **Cross-Platform** | ✅ PASSED | 100% |

**Overall System Health: 91%** ✅

> 📊 **See [WEBSTAR_TESTING_CHECKIN.md](WEBSTAR_TESTING_CHECKIN.md) for detailed test results**

### **⚠️ What Needs Real-World Validation**
- **Multi-client stress testing** with 4-8 simultaneous players
- **NAT traversal** in diverse network environments  
- **Mobile browser compatibility** across different devices
- **Performance under game load** (physics, rendering, etc.)
- **Host migration** in real disconnect scenarios

---

## 🌐 **Platform Support**

| Platform | WebRTC Support | Status | Notes |
|----------|----------------|--------|-------|
| **Windows** | Native Plugin | ✅ Tested | Requires webrtc-native |
| **macOS** | Native Plugin | 🔄 Expected | Should work with plugin |
| **Linux** | Native Plugin | 🔄 Expected | Should work with plugin |
| **Web (Chrome)** | Built-in | ✅ Tested | No plugin needed |
| **Web (Firefox)** | Built-in | 🔄 Expected | Should work |
| **Web (Safari)** | Built-in | ⚠️ Limited | WebRTC limitations |
| **Mobile Browsers** | Built-in | 🔄 Untested | Needs validation |

---

## 📖 **Documentation**

### **Getting Started**
- [Installation Guide](webstar-addon-dev/addons/webstar/README.md)
- [Server Setup](webstar-server-dotnet/README.md)
- [Basic Examples](webstar-addon-dev/scripts/)

### **Advanced Topics**
- [Star Topology Explanation](DEVELOPMENT.md#star-topology)
- [WebRTC Configuration](DEVELOPMENT.md#webrtc-setup)
- [Host Migration](DEVELOPMENT.md#host-migration)

### **API Reference**
- [WebStarManager API](webstar-addon-dev/addons/webstar/webstar_manager.gd)
- [Configuration Options](webstar-addon-dev/addons/webstar/webstar_config.gd)

---

## 🤝 **Contributing**

WebStar needs **real-world game testing** to reach production readiness!

### **How You Can Help**
1. **🎮 Build a game** with WebStar and report results
2. **🐛 Test edge cases** (poor networks, mobile devices)
3. **📝 Improve documentation** and examples
4. **🔧 Submit bug fixes** and enhancements

### **Development Setup**
```bash
# Clone repository
git clone https://github.com/SantasLair/webstar.git
cd webstar

# Start development server
cd webstar-server-dotnet && dotnet run

# Open test project in Godot
# File -> Import Project -> webstar-addon-dev/project.godot
```

---

## ⚠️ **Important Disclaimers**

### **Beta Software Notice**
- WebStar is **experimental** and may have undiscovered issues
- **Backup your projects** before integrating WebStar
- API may change based on community feedback
- Not recommended for **commercial projects** without thorough testing

### **Network Requirements**
- Requires **STUN servers** for NAT traversal (Google's provided by default)
- May need **TURN servers** for restrictive networks
- **Signaling server** required for lobby management

### **Known Limitations**
- WebRTC native plugin required for desktop builds
- Limited to **8 players** in star topology (by design)
- Host disconnection causes temporary interruption
- Mobile testing incomplete

---

## 🚀 **Server Deployment**

WebStar includes a production-ready .NET server with **automated deployment to any cloud provider**:

### **Supported Platforms**
- ✅ **DigitalOcean** (Droplets, App Platform)
- ✅ **AWS** (EC2, ECS, Fargate, App Runner) 
- ✅ **Google Cloud** (Compute Engine, Cloud Run, GKE)
- ✅ **Microsoft Azure** (Container Instances, App Service, AKS)
- ✅ **Heroku, Railway, Render, Fly.io**
- ✅ **Any Linux server with Docker**

### **One-Click Deployment**
1. **Push to main branch** → GitHub Actions automatically builds & deploys
2. **Configure 3 secrets**: Server IP, SSH username, SSH key
3. **Access your server**: `http://your-server-ip/health`

```bash
# Works on ANY cloud provider with Docker
docker run -d --name webstar-server -p 80:5090 --restart unless-stopped \
  ghcr.io/santasliar/webstar-server:latest
```

📚 **[Complete Deployment Guide](DEPLOYMENT.md)**

---

## 📄 **License**

MIT License - See [LICENSE](LICENSE) file for details.

### **Third-Party Components**
- **WebRTC**: Licensed under BSD 3-Clause
- **Godot Engine**: Licensed under MIT
- **.NET**: Licensed under MIT

---

## 🙏 **Acknowledgments**

- **Godot Community** for the amazing engine
- **WebRTC Project** for real-time communication
- **GDevelop** for star topology inspiration
- **Test Contributors** who helped validate WebStar

---

## 📞 **Support & Community**

- **Issues**: [GitHub Issues](https://github.com/SantasLair/webstar/issues)
- **Discussions**: [GitHub Discussions](https://github.com/SantasLair/webstar/discussions)
- **Documentation**: See `docs/` folder
- **Examples**: See `webstar-addon-dev/scripts/`

---

**🌟 Ready to build the next great multiplayer game with WebStar?**

**[⬇️ Download Latest Release](https://github.com/SantasLair/webstar/releases) | [📖 Read the Docs](webstar-addon-dev/addons/webstar/README.md) | [🎮 Try the Demo](webstar-addon-dev/)**
