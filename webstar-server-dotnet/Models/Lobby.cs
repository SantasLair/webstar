using System.Collections.Concurrent;

namespace WebStarServer.Models
{
    public class Lobby
    {
        public string Id { get; set; } = "";
        public string Name { get; set; } = "";
        public int MaxPlayers { get; set; } = 8;
        public bool IsPublic { get; set; } = true;
        public string HostId { get; set; } = "";
        public DateTime CreatedAt { get; set; }
        public ConcurrentDictionary<string, Peer> Peers { get; set; } = new();
        public int NextPeerId { get; set; } = 2; // Start from 2 since host is 1
        public bool IsFull => Peers.Count >= MaxPlayers;
    }
}