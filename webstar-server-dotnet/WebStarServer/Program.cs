using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Collections.Concurrent;

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
var clients = new ConcurrentDictionary<WebSocket, ClientInfo>();
var lobbies = new ConcurrentDictionary<string, LobbyInfo>();

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
            playerCount = l.Players.Count,
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
    var clientInfo = new ClientInfo
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
async Task HandleMessage(WebSocket webSocket, ClientInfo clientInfo, string messageText)
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
        var json = JsonSerializer.Serialize(message);
        var bytes = Encoding.UTF8.GetBytes(json);
        await webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
    }
}

async Task SendError(WebSocket webSocket, string error)
{
    await SendMessage(webSocket, new { type = "error", message = error });
}

async Task HandleCreateLobby(WebSocket webSocket, ClientInfo clientInfo, JsonElement message)
{
    var lobbyId = GenerateLobbyId();
    var lobbyName = message.TryGetProperty("name", out var nameProperty) ? nameProperty.GetString() : "Lobby";
    var maxPlayers = message.TryGetProperty("maxPlayers", out var maxProperty) ? maxProperty.GetInt32() : 8;
    var isPublic = message.TryGetProperty("isPublic", out var publicProperty) ? publicProperty.GetBoolean() : true;
    
    var lobby = new LobbyInfo
    {
        Id = lobbyId,
        Name = lobbyName ?? "Lobby",
        MaxPlayers = maxPlayers,
        IsPublic = isPublic,
        HostId = clientInfo.Id,
        CreatedAt = DateTime.UtcNow
    };
    
    lobby.Players[clientInfo.Id] = new PlayerInfo
    {
        Id = clientInfo.Id,
        Name = clientInfo.Id, // Use clientId as name for now
        IsHost = true,
        JoinedAt = DateTime.UtcNow
    };
    
    lobbies[lobbyId] = lobby;
    clientInfo.LobbyId = lobbyId;
    
    await SendMessage(webSocket, new
    {
        type = "lobby_created",
        lobbyId = lobbyId,
        lobby = new
        {
            id = lobby.Id,
            name = lobby.Name,
            maxPlayers = lobby.MaxPlayers,
            isPublic = lobby.IsPublic,
            hostId = lobby.HostId,
            players = lobby.Players.Values.Select(p => new { id = p.Id, name = p.Name, isHost = p.IsHost })
        }
    });
    
    Console.WriteLine($"Client {clientInfo.Id} created lobby {lobbyId}");
}

async Task HandleJoinLobby(WebSocket webSocket, ClientInfo clientInfo, JsonElement message)
{
    string? lobbyId = null;
    
    // Try to get lobbyId from message
    if (message.TryGetProperty("lobbyId", out var lobbyIdProperty))
    {
        lobbyId = lobbyIdProperty.GetString();
    }
    else if (message.TryGetProperty("lobby_id", out var lobbyIdProperty2))
    {
        lobbyId = lobbyIdProperty2.GetString();
    }
    
    if (string.IsNullOrEmpty(lobbyId))
    {
        await SendError(webSocket, "No lobbyId provided");
        return;
    }
    
    if (!lobbies.TryGetValue(lobbyId, out var lobby))
    {
        await SendError(webSocket, "Lobby not found");
        return;
    }
    
    if (lobby.IsFull)
    {
        await SendError(webSocket, "Lobby is full");
        return;
    }
    
    lobby.Players[clientInfo.Id] = new PlayerInfo
    {
        Id = clientInfo.Id,
        Name = clientInfo.Id,
        IsHost = false,
        JoinedAt = DateTime.UtcNow
    };
    
    clientInfo.LobbyId = lobbyId;
    
    // Notify all players in lobby
    await BroadcastToLobby(lobbyId, new
    {
        type = "player_joined",
        playerId = clientInfo.Id,
        player = new { id = clientInfo.Id, name = clientInfo.Id, isHost = false }
    });
    
    await SendMessage(webSocket, new
    {
        type = "lobby_joined",
        lobbyId = lobbyId,
        lobby = new
        {
            id = lobby.Id,
            name = lobby.Name,
            maxPlayers = lobby.MaxPlayers,
            isPublic = lobby.IsPublic,
            hostId = lobby.HostId,
            players = lobby.Players.Values.Select(p => new { id = p.Id, name = p.Name, isHost = p.IsHost })
        }
    });
    
    Console.WriteLine($"Client {clientInfo.Id} joined lobby {lobbyId}");
}

async Task HandleLeaveLobby(WebSocket webSocket, ClientInfo clientInfo)
{
    if (string.IsNullOrEmpty(clientInfo.LobbyId))
    {
        await SendError(webSocket, "Not in a lobby");
        return;
    }
    
    await RemovePlayerFromLobby(clientInfo.LobbyId, clientInfo.Id);
    await SendMessage(webSocket, new { type = "lobby_left" });
}

async Task HandleLobbyMessage(WebSocket webSocket, ClientInfo clientInfo, JsonElement message)
{
    if (string.IsNullOrEmpty(clientInfo.LobbyId))
    {
        await SendError(webSocket, "Not in a lobby");
        return;
    }
    
    await BroadcastToLobby(clientInfo.LobbyId, new
    {
        type = "lobby_message",
        playerId = clientInfo.Id,
        data = message.GetProperty("data")
    }, clientInfo.Id);
}

async Task HandleGetLobbies(WebSocket webSocket)
{
    var publicLobbies = lobbies.Values
        .Where(l => l.IsPublic && !l.IsFull)
        .Select(l => new
        {
            id = l.Id,
            name = l.Name,
            playerCount = l.Players.Count,
            maxPlayers = l.MaxPlayers,
            host = l.HostId
        });
    
    await SendMessage(webSocket, new
    {
        type = "lobbies_list",
        lobbies = publicLobbies
    });
}

async Task BroadcastToLobby(string lobbyId, object message, string? excludePlayerId = null)
{
    if (!lobbies.TryGetValue(lobbyId, out var lobby))
        return;
    
    var tasks = new List<Task>();
    
    foreach (var (ws, clientInfo) in clients)
    {
        if (clientInfo.LobbyId == lobbyId && clientInfo.Id != excludePlayerId)
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
    
    lobby.Players.TryRemove(playerId, out _);
    
    // Remove client's lobby reference
    var clientToUpdate = clients.Values.FirstOrDefault(c => c.Id == playerId);
    if (clientToUpdate != null)
    {
        clientToUpdate.LobbyId = null;
    }
    
    if (lobby.Players.Count == 0)
    {
        // Remove empty lobby
        lobbies.TryRemove(lobbyId, out _);
        Console.WriteLine($"Removed empty lobby {lobbyId}");
    }
    else
    {
        // Notify remaining players
        await BroadcastToLobby(lobbyId, new
        {
            type = "player_left",
            playerId = playerId
        });
        
        // If the host left, assign new host
        if (lobby.HostId == playerId)
        {
            var newHost = lobby.Players.Values.First();
            newHost.IsHost = true;
            lobby.HostId = newHost.Id;
            
            await BroadcastToLobby(lobbyId, new
            {
                type = "host_changed",
                newHostId = newHost.Id
            });
        }
    }
}

string GenerateLobbyId()
{
    const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    var random = new Random();
    return new string(Enumerable.Repeat(chars, 6)
        .Select(s => s[random.Next(s.Length)]).ToArray());
}

// Data classes
public class ClientInfo
{
    public string Id { get; set; } = "";
    public WebSocket WebSocket { get; set; } = null!;
    public DateTime ConnectedAt { get; set; }
    public string RemoteEndPoint { get; set; } = "";
    public string? LobbyId { get; set; }
}

public class LobbyInfo
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public int MaxPlayers { get; set; } = 8;
    public bool IsPublic { get; set; } = true;
    public string HostId { get; set; } = "";
    public DateTime CreatedAt { get; set; }
    public ConcurrentDictionary<string, PlayerInfo> Players { get; set; } = new();
    
    public bool IsFull => Players.Count >= MaxPlayers;
}

public class PlayerInfo
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public bool IsHost { get; set; }
    public DateTime JoinedAt { get; set; }
}
