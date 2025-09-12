using System.Net.WebSockets;

namespace WebStarServer.Models
{
    public class Peer
    {
        public string Id { get; set; } = "";
        public WebSocket WebSocket { get; set; } = null!;
        public DateTime ConnectedAt { get; set; }
        public string RemoteEndPoint { get; set; } = "";
        public string? LobbyId { get; set; }
        public int PeerId { get; set; } = 0;  // PeerId assigned in the lobby
    }
}
