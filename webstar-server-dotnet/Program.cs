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

app.MapGet("/", () => "WebStar Server .NET 9");

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
async Task HandleMessage(WebSocket webSocket, Peer clientInfo, string messageText)
{
    try
    {
        var message = JsonSerializer.Deserialize<JsonElement>(messageText);
        var messageType = message.GetProperty("type").GetString();
        
        Console.WriteLine($"Received message from {clientInfo.Id}: {messageType}");
        
        switch (messageType)
        {
            case "create_lobby":
                await HandleCreateLobby(webSocket, clientInfo, message);
                break;
            case "join_lobby":
                await HandleJoinLobby(webSocket, clientInfo, message);
                break;
            case "leave_lobby":
                await HandleLeaveLobby(webSocket, clientInfo);
                break;
            case "lobby_message":
                await HandleLobbyMessage(webSocket, clientInfo, message);
                break;
            case "get_lobbies":
                await HandleGetLobbies(webSocket);
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
        CreatedAt = DateTime.UtcNow,
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
        lobby = new
        {
            id = lobby.Id,
            name = lobby.Name,
            maxPlayers = (int)lobby.MaxPlayers,
            peerId = 1,
        }
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
        lobby = new
        {
            id = lobbyId,
            maxPlayers = lobby.MaxPlayers,
            isPublic = lobby.IsPublic,
            hostId = lobby.HostId,
            peerId = (int)lobby.Peers[peer.Id].PeerId,
            players = lobby.Peers.Values.Select(p => new { 
                id = p.Id, 
                peerId = p.PeerId,
            })
        }
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
    //if (!lobbies.TryGetValue(lobbyId, out var lobby))
    //    return;
    
    //lobby.Peers.TryRemove(playerId, out _);
    
    //// Remove client's lobby reference
    //var clientToUpdate = clients.Values.FirstOrDefault(c => c.Id == playerId);
    //if (clientToUpdate != null)
    //{
    //    clientToUpdate.LobbyId = null;
    //}
    
    //if (lobby.Peers.Count == 0)
    //{
    //    // Remove empty lobby
    //    lobbies.TryRemove(lobbyId, out _);
    //    Console.WriteLine($"Removed empty lobby {lobbyId}");
    //}
    //else
    //{
    //    // Notify remaining players
    //    await BroadcastToLobby(lobbyId, new
    //    {
    //        type = "player_left",
    //        playerId = playerId
    //    });
        
    //    // If the host left, assign new host
    //    if (lobby.HostId == playerId)
    //    {
    //        var newHost = lobby.Peers.Values.First();
    //        newHost.IsHost = true;
    //        lobby.HostId = newHost.Id;
            
    //        await BroadcastToLobby(lobbyId, new
    //        {
    //            type = "host_changed",
    //            newHostId = newHost.Id
    //        });
    //    }
    //}
}

string GenerateLobbyId()
{
    const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var random = new Random();
    return new string(Enumerable.Repeat(chars, 6)
        .Select(s => s[random.Next(s.Length)]).ToArray());
}

