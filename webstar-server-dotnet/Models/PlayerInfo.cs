namespace WebStarServer.Models
{
    public class PlayerInfo
    {
        public string Id { get; set; } = "";
        public int PeerId { get; set; } = 0;    // peer id used by the client
        public string Name { get; set; } = "";
        public bool IsHost { get; set; }
        public DateTime JoinedAt { get; set; }
    }
}
