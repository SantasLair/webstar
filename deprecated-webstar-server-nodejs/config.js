module.exports = {
    server: {
        host: process.env.HOST || 'localhost',
        port: parseInt(process.env.PORT) || 5090
    },
    
    cors: {
        allowedOrigins: process.env.ALLOWED_ORIGINS ? 
            process.env.ALLOWED_ORIGINS.split(',') : 
            ['*'] // In production, specify actual origins
    },
    
    lobby: {
        maxLobbies: parseInt(process.env.MAX_LOBBIES) || 1000,
        maxPlayersPerLobby: parseInt(process.env.MAX_PLAYERS_PER_LOBBY) || 8,
        lobbyIdLength: 6,
        defaultTtlMinutes: 60,
        cleanupInterval: 5 * 60 * 1000, // 5 minutes
        maxLobbyNameLength: 50,
        maxUsernameLength: 20
    },
    
    heartbeat: {
        timeout: 30 * 1000, // 30 seconds
        checkInterval: 15 * 1000 // 15 seconds
    },
    
    relay: {
        maxMessageSize: 64 * 1024, // 64 KB
        maxMessagesPerSecond: 100,
        enableCompression: true
    },
    
    webrtc: {
        iceServers: [
            { urls: 'stun:stun.l.google.com:19302' },
            { urls: 'stun:stun1.l.google.com:19302' },
            // Add TURN servers for production
            // {
            //     urls: 'turn:your-turn-server.com:3478',
            //     username: 'username',
            //     credential: 'password'
            // }
        ],
        connectionTimeout: 10 * 1000, // 10 seconds
        maxRetries: 3
    },
    
    logging: {
        level: process.env.LOG_LEVEL || 'info', // error, warn, info, debug
        enableFileLogging: process.env.ENABLE_FILE_LOGGING === 'true',
        logDirectory: './logs'
    },
    
    rateLimit: {
        windowMs: 15 * 60 * 1000, // 15 minutes
        max: 1000, // limit each IP to 1000 requests per windowMs
        skipSuccessfulRequests: true
    },
    
    stats: {
        enableCollection: true,
        retentionHours: 24
    }
};
