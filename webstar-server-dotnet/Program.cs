using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Collections.Concurrent;
using WebStarServer.Models;

var builder = WebApplication.CreateBuilder(args);

// Add services
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

// Configure middleware
app.UseCors();

// Global state - In production, use dependency injection
var clients = new ConcurrentDictionary<WebSocket, Peer>();
var lobbies = new ConcurrentDictionary<string, Lobby>();

// Health check endpoint
app.MapGet("/health", () => new
{
    status = "healthy",
    uptime = Environment.TickCount64 / 1000,
    lobbies = lobbies.Count,
    clients = clients.Count,
    memory = GC.GetTotalMemory(false)
});

// Stats endpoint
app.MapGet("/stats", () => new
{
    totalConnections = clients.Count,
    activeLobbies = lobbies.Count,
    uptime = Environment.TickCount64 / 1000
});

// Lobby list endpoint
app.MapGet("/lobbies", () =>
{
    return lobbies.Values
        .Where(l => l.IsPublic && !l.IsFull)
        .Select(l => new
        {
            id = l.Id,
            name = l.Name,
            playerCount = l.Peers.Count,
            maxPlayers = l.MaxPlayers,
            host = l.HostId
        });
});

// WebSocket endpoint
app.UseWebSockets(new WebSocketOptions
{
    KeepAliveInterval = TimeSpan.FromSeconds(30)
});

app.Use(async (context, next) =>
{
    if (context.Request.Path == "/ws")
    {
        if (context.WebSockets.IsWebSocketRequest)
        {
            var webSocket = await context.WebSockets.AcceptWebSocketAsync();
            await HandleWebSocketConnection(webSocket, context);
        }
        else
        {
            context.Response.StatusCode = 400;
        }
    }
    else
    {
        await next();
    }
});

app.MapGet("/", () => Results.Content(@"
<!DOCTYPE html>
<html lang=""en"">
<head>
    <meta charset=""UTF-8"">
    <meta name=""viewport"" content=""width=device-width, initial-scale=1.0"">
    <title>WebStar Server</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
        }
        .container {
            text-align: center;
            background: rgba(255, 255, 255, 0.1);
            padding: 2rem;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(31, 38, 135, 0.37);
            border: 1px solid rgba(255, 255, 255, 0.18);
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.3);
        }
        .status {
            font-size: 1.2rem;
            margin: 1rem 0;
            opacity: 0.9;
        }
        .links {
            margin-top: 2rem;
        }
        .links a {
            color: white;
            text-decoration: none;
            margin: 0 1rem;
            padding: 0.5rem 1rem;
            border: 1px solid rgba(255, 255, 255, 0.3);
            border-radius: 5px;
            transition: all 0.3s ease;
        }
        .links a:hover {
            background: rgba(255, 255, 255, 0.2);
            transform: translateY(-2px);
        }
        .version {
            margin-top: 1rem;
            opacity: 0.7;
            font-size: 0.9rem;
        }
    </style>
</head>
<body>
    <div class=""container"">
        <h1>🌟 WebStar Server</h1>
        <div class=""status"">✅ Server is running and ready!</div>
        <div class=""status"">WebRTC Signaling Server for Godot</div>
        
        <div class=""links"">
            <a href=""/health"">Health Check</a>
            <a href=""/stats"">Statistics</a>
            <a href=""/lobbies"">Active Lobbies</a>
        </div>
        
    </div>
</body>
</html>", "text/html"));

Console.WriteLine("Starting WebStar Server on port 5090...");
app.Run("http://localhost:5090");

// WebSocket connection handler
async Task HandleWebSocketConnection(WebSocket webSocket, HttpContext context)
{
    var clientId = Guid.NewGuid().ToString();
    var clientInfo = new Peer
    {
        Id = clientId,
        WebSocket = webSocket,
        ConnectedAt = DateTime.UtcNow,
        RemoteEndPoint = context.Connection.RemoteIpAddress?.ToString() ?? "unknown"
    };
    
    clients.TryAdd(webSocket, clientInfo);
    
    Console.WriteLine($"Client {clientId} connected from {clientInfo.RemoteEndPoint}");
    
    // Send welcome message
    await SendMessage(webSocket, new
    {
        type = "welcome",
        clientId = clientId,
        message = "Connected to WebStar server"
    });
    
    var buffer = new byte[4096];
    
    try
    {
        while (webSocket.State == WebSocketState.Open)
        {
            var result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), CancellationToken.None);
            
            if (result.MessageType == WebSocketMessageType.Close)
            {
                await webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Client disconnected", CancellationToken.None);
                break;
            }
            else if (result.MessageType == WebSocketMessageType.Text)
            {
                var message = Encoding.UTF8.GetString(buffer, 0, result.Count);
                await HandleMessage(webSocket, clientInfo, message);
            }
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error handling client {clientId}: {ex.Message}");
    }
    finally
    {
        clients.TryRemove(webSocket, out _);
        
        // Clean up lobby if this client was in one
        if (!string.IsNullOrEmpty(clientInfo.LobbyId))
        {
            await RemovePlayerFromLobby(clientInfo.LobbyId, clientId);
        }
        
        Console.WriteLine($"Client {clientId} disconnected");
    }
}

// Message handler
async Task HandleMessage(WebSocket webSocket, Peer peer, string messageText)
{
    try
    {
        var message = JsonSerializer.Deserialize<JsonElement>(messageText);
        var messageType = message.GetProperty("type").GetString();
        
        Console.WriteLine($"Received message from {peer.Id}: {messageType}");
        
        switch (messageType)
        {
            case "create_lobby":
                await HandleCreateLobby(webSocket, peer, message);
                break;
            case "join_lobby":
                await HandleJoinLobby(webSocket, peer, message);
                break;
            case "leave_lobby":
                await HandleLeaveLobby(webSocket, peer);
                break;
            case "lobby_message":
                await HandleLobbyMessage(webSocket, peer, message);
                break;
            case "get_lobbies":
                await HandleGetLobbies(webSocket);
                break;
            case "send_message_to":
            case "offer":
            case "answer":
                await HandleSendMessageTo(webSocket, peer, message);
                break;
            case "candidate":
                await HandleSendCandidate(webSocket, peer, message);
                break;
            case "ping":
                await SendMessage(webSocket, new { type = "pong", timestamp = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() });
                break;
            default:
                await SendError(webSocket, $"Unknown message type: {messageType}");
                break;
        }
    }
    catch (Exception ex)
    {
        Console.WriteLine($"Error processing message: {ex.Message}");
        await SendError(webSocket, "Invalid message format");
    }
}

// Helper methods
async Task SendMessage(WebSocket webSocket, object message)
{
    if (webSocket.State == WebSocketState.Open)
    {
        var options = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            WriteIndented = false
        };

        var json = JsonSerializer.Serialize(message, options);
        var bytes = Encoding.UTF8.GetBytes(json);
        await webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);

        Console.WriteLine($"Sent message to client: {json}");
    }
}

async Task SendError(WebSocket webSocket, string error)
{
    await SendMessage(webSocket, new { type = "error", message = error });
}

async Task HandleCreateLobby(WebSocket webSocket, Peer peer, JsonElement message)
{
    var lobbyId = message.TryGetProperty("lobbyId", out var lobbyIdProperty) ? lobbyIdProperty.GetString() : GenerateLobbyId();
    var maxPlayers = message.TryGetProperty("maxPlayers", out var maxProperty) ? maxProperty.GetInt32() : 8;
    var isPublic = message.TryGetProperty("isPublic", out var publicProperty) ? publicProperty.GetBoolean() : true;
    
    lobbyId ??= GenerateLobbyId();

    var lobby = new Lobby
    {
        Id = lobbyId ?? GenerateLobbyId(),
        MaxPlayers = maxPlayers,
        IsPublic = isPublic,
        HostId = peer.Id,
        NextPeerId = 2
    };

    lobby.Peers[peer.Id] = peer;
    peer.PeerId = 1; // Host is always PeerId 1
    peer.LobbyId = lobbyId;

    lobbies[lobbyId!] = lobby;

    await SendMessage(webSocket, new
    {
        type = "lobby_created",
        lobbyId,
        maxPlayers = lobby.MaxPlayers,
        peerId = 1
    });
    
    Console.WriteLine($"Client {peer.Id} created lobby {lobbyId}");
}

async Task HandleJoinLobby(WebSocket webSocket, Peer peer, JsonElement message)
{
    var lobbyId = message.TryGetProperty("lobbyId", out var lobbyIdProperty) ? lobbyIdProperty.GetString() : null;
    if (lobbyId is null)
    {
        await SendError(webSocket, "No lobbyId provided");
        return;
    }

    var lobby = lobbies.TryGetValue(lobbyId, out var lobbyValue) ? lobbyValue : null;
    if (lobby is null)
    {
        await SendError(webSocket, "Lobby not found");
        return;
    }
    
    if (lobby.IsFull)
    {
        await SendError(webSocket, "Lobby is full");
        return;
    }


    lobby.Peers[peer.Id] = peer;
    peer.PeerId = lobby.NextPeerId++;
    peer.LobbyId = lobbyId;
        
    await SendMessage(webSocket, new
    {
        type = "lobby_joined",
        lobbyId,
        peerId = peer.PeerId,
    });

    // Notify all players in lobby
    await BroadcastToLobby(lobby.Peers[peer.Id].PeerId, lobby, new
    {
        type = "peer_joined",
        peerId = lobby.Peers[peer.Id].PeerId
    });


    Console.WriteLine($"Client {peer.Id} joined lobby {lobbyId}");
}

async Task HandleLeaveLobby(WebSocket webSocket, Peer clientInfo)
{
    if (string.IsNullOrEmpty(clientInfo.LobbyId))
    {
        await SendError(webSocket, "Not in a lobby");
        return;
    }
    
    await RemovePlayerFromLobby(clientInfo.LobbyId, clientInfo.Id);
    await SendMessage(webSocket, new { type = "lobby_left" });
}

async Task HandleLobbyMessage(WebSocket webSocket, Peer clientInfo, JsonElement message)
{
    //if (string.IsNullOrEmpty(clientInfo.LobbyId))
    //{
    //    await SendError(webSocket, "Not in a lobby");
    //    return;
    //}

    //await BroadcastToLobby(clientInfo.LobbyId, new
    //{
    //    type = "lobby_message",
    //    playerId = clientInfo.Id,
    //    data = message.GetProperty("data")
    //}, clientInfo.Id);
}

async Task HandleGetLobbies(WebSocket webSocket)
{
    var publicLobbies = lobbies.Values
        .Where(l => l.IsPublic && !l.IsFull)
        .Select(l => new
        {
            id = l.Id,
            name = l.Name,
            playerCount = l.Peers.Count,
            maxPlayers = l.MaxPlayers,
            host = l.HostId
        });
    
    await SendMessage(webSocket, new
    {
        type = "lobbies_list",
        lobbies = publicLobbies
    });
}

async Task HandleSendMessageTo(WebSocket webSocket, Peer peer, JsonElement message)
{
    if (string.IsNullOrEmpty(peer.LobbyId))
    {
        await SendError(webSocket, "Not in a lobby");
        return;
    }
    var lobby = lobbies.TryGetValue(peer.LobbyId, out var lobbyValue) ? lobbyValue : null;
    if (lobby is null)
    {
        await SendError(webSocket, "Lobby not found");
        return;
    }
    var targetPeerId = message.TryGetProperty("targetPeerId", out var targetPeerIdProperty) ? targetPeerIdProperty.GetInt32() : 0;
    if (targetPeerId == 0)
    {
        await SendError(webSocket, "No targgetPeerId provided");
        return;
    }
    var toPeer = lobby.Peers.Values.FirstOrDefault(p => p.PeerId == targetPeerId);
    if (toPeer is null)
    {
        await SendError(webSocket, "target peer not found in lobby");
        return;
    }
    var data = message.TryGetProperty("data", out var dataProperty) ? dataProperty : new JsonElement();

    var type = message.GetProperty("type").GetString();
    await SendMessage(toPeer.WebSocket, new
    {
        type,
        fromPeerId = peer.PeerId,
        data
    });
}

async Task HandleSendCandidate(WebSocket webSocket, Peer peer, JsonElement message)
{
    if (string.IsNullOrEmpty(peer.LobbyId))
    {
        await SendError(webSocket, "Not in a lobby");
        return;
    }
    var lobby = lobbies.TryGetValue(peer.LobbyId, out var lobbyValue) ? lobbyValue : null;
    if (lobby is null)
    {
        await SendError(webSocket, "Lobby not found");
        return;
    }
    var targetPeerId = message.TryGetProperty("targetPeerId", out var targetPeerIdProperty) ? targetPeerIdProperty.GetInt32() : 0;
    if (targetPeerId == 0)
    {
        await SendError(webSocket, "No targgetPeerId provided");
        return;
    }
    var toPeer = lobby.Peers.Values.FirstOrDefault(p => p.PeerId == targetPeerId);
    if (toPeer is null)
    {
        await SendError(webSocket, "target peer not found in lobby");
        return;
    }

    var mid = message.TryGetProperty("mid", out var midNameProperty) ? midNameProperty.ToString() : "";
    var index = message.TryGetProperty("index", out var indexNameProperty) ? indexNameProperty.GetInt32() : 0;
    var sdp = message.TryGetProperty("sdp", out var sdpNameProperty) ? sdpNameProperty.ToString() : "";
    
    await SendMessage(toPeer.WebSocket, new
    {
        type = "candidate",
        fromPeerId = peer.PeerId,
        mid,
        index,
        sdp
    });
}


async Task BroadcastToLobby(int fromPeerId, Lobby lobby, object message)
{    
    var tasks = new List<Task>();
    
    foreach (var (ws, clientInfo) in clients)
    {
        if (clientInfo.LobbyId == lobby.Id && lobby.Peers[clientInfo.Id].PeerId != fromPeerId)
        {
            tasks.Add(SendMessage(ws, message));
        }
    }
    
    await Task.WhenAll(tasks);
}

async Task RemovePlayerFromLobby(string lobbyId, string playerId)
{
    if (!lobbies.TryGetValue(lobbyId, out var lobby))
        return;

    lobby.Peers.TryRemove(playerId, out _);

    // Remove client's lobby reference
    var clientToUpdate = clients.Values.FirstOrDefault(c => c.Id == playerId);
    if (clientToUpdate != null)
    {
        clientToUpdate.LobbyId = null;
    }

    if (lobby.Peers.Count == 0)
    {
        // Remove empty lobby
        lobbies.TryRemove(lobbyId, out _);
        Console.WriteLine($"Removed empty lobby {lobbyId}");
    }
    else
    {
        //// Notify remaining players
        //await BroadcastToLobby(lobbyId, new
        //{
        //    type = "player_left",
        //    playerId = playerId
        //});

        //// If the host left, assign new host
        //if (lobby.HostId == playerId)
        //{
        //    var newHost = lobby.Peers.Values.First();
        //    newHost.IsHost = true;
        //    lobby.HostId = newHost.Id;

        //    await BroadcastToLobby(lobbyId, new
        //    {
        //        type = "host_changed",
        //        newHostId = newHost.Id
        //    });
        //}
    }
}

string GenerateLobbyId()
{
    const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var random = new Random();
    return new string(Enumerable.Repeat(chars, 6)
        .Select(s => s[random.Next(s.Length)]).ToArray());
}

