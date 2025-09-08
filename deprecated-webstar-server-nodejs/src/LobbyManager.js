const { v4: uuidv4 } = require('uuid');
const config = require('../config');
const logger = require('./Logger');

class LobbyManager {
    constructor() {
        this.lobbies = new Map(); // lobbyId -> Lobby
        this.playerLobbies = new Map(); // playerId -> lobbyId
    }
    
    // Create a new lobby
    createLobby(hostPlayerId, lobbyInfo = {}) {
        const lobbyId = this.generateLobbyId();
        
        const lobby = {
            id: lobbyId,
            name: lobbyInfo.name || `Lobby ${lobbyId}`,
            hostPlayerId: hostPlayerId,
            players: new Map(), // playerId -> playerInfo
            isPublic: lobbyInfo.isPublic !== false,
            maxPlayers: Math.min(lobbyInfo.maxPlayers || 4, config.lobby.maxPlayersPerLobby),
            gameSettings: lobbyInfo.gameSettings || {},
            createdAt: new Date(),
            lastActivity: Date.now(),
            state: 'waiting', // waiting, in_game, finished
            metadata: lobbyInfo.metadata || {}
        };
        
        this.lobbies.set(lobbyId, lobby);
        
        logger.info(`Created lobby ${lobbyId} with host ${hostPlayerId}`);
        
        return lobby;
    }
    
    // Join an existing lobby
    joinLobby(lobbyId, playerId, playerInfo) {
        const lobby = this.lobbies.get(lobbyId);
        
        if (!lobby) {
            throw new Error('Lobby not found');
        }
        
        if (lobby.players.size >= lobby.maxPlayers) {
            throw new Error('Lobby is full');
        }
        
        if (lobby.players.has(playerId)) {
            throw new Error('Player already in lobby');
        }
        
        // Check if player is already in another lobby
        const existingLobbyId = this.playerLobbies.get(playerId);
        if (existingLobbyId && existingLobbyId !== lobbyId) {
            this.removePlayerFromLobby(existingLobbyId, playerId);
        }
        
        const player = {
            playerId: playerId,
            username: playerInfo.username,
            peerId: playerInfo.peerId || null,
            connectedAt: new Date(),
            lastSeen: Date.now(),
            isReady: false,
            metadata: playerInfo.metadata || {}
        };
        
        lobby.players.set(playerId, player);
        lobby.lastActivity = Date.now();
        this.playerLobbies.set(playerId, lobbyId);
        
        logger.info(`Player ${playerId} (${playerInfo.username}) joined lobby ${lobbyId}`);
        
        return lobby;
    }
    
    // Remove player from lobby
    removePlayerFromLobby(lobbyId, playerId) {
        const lobby = this.lobbies.get(lobbyId);
        
        if (!lobby) {
            return false;
        }
        
        const player = lobby.players.get(playerId);
        if (!player) {
            return false;
        }
        
        lobby.players.delete(playerId);
        lobby.lastActivity = Date.now();
        this.playerLobbies.delete(playerId);
        
        logger.info(`Player ${playerId} (${player.username}) left lobby ${lobbyId}`);
        
        // If lobby is empty, mark for cleanup
        if (lobby.players.size === 0) {
            logger.info(`Lobby ${lobbyId} is now empty, will be cleaned up`);
        }
        // If the host left, the lobby will need a new host (handled by server)
        
        return true;
    }
    
    // Update player ready state
    setPlayerReady(lobbyId, playerId, isReady) {
        const lobby = this.lobbies.get(lobbyId);
        if (!lobby) return false;
        
        const player = lobby.players.get(playerId);
        if (!player) return false;
        
        player.isReady = isReady;
        player.lastSeen = Date.now();
        lobby.lastActivity = Date.now();
        
        return true;
    }
    
    // Update lobby game state
    setLobbyState(lobbyId, state) {
        const lobby = this.lobbies.get(lobbyId);
        if (!lobby) return false;
        
        lobby.state = state;
        lobby.lastActivity = Date.now();
        
        logger.info(`Lobby ${lobbyId} state changed to: ${state}`);
        
        return true;
    }
    
    // Get lobby by ID
    getLobby(lobbyId) {
        return this.lobbies.get(lobbyId);
    }
    
    // Get lobby for a specific player
    getPlayerLobby(playerId) {
        const lobbyId = this.playerLobbies.get(playerId);
        return lobbyId ? this.lobbies.get(lobbyId) : null;
    }
    
    // Get list of public lobbies
    getPublicLobbies() {
        const publicLobbies = [];
        
        for (const lobby of this.lobbies.values()) {
            if (lobby.isPublic && lobby.state === 'waiting' && lobby.players.size < lobby.maxPlayers) {
                publicLobbies.push({
                    id: lobby.id,
                    name: lobby.name,
                    playerCount: lobby.players.size,
                    maxPlayers: lobby.maxPlayers,
                    createdAt: lobby.createdAt,
                    gameSettings: lobby.gameSettings
                });
            }
        }
        
        // Sort by creation time (newest first)
        publicLobbies.sort((a, b) => b.createdAt - a.createdAt);
        
        return publicLobbies;
    }
    
    // Find lobby by name or ID
    findLobby(identifier) {
        // Try by ID first
        let lobby = this.lobbies.get(identifier);
        if (lobby) return lobby;
        
        // Try by name
        for (const l of this.lobbies.values()) {
            if (l.name.toLowerCase() === identifier.toLowerCase()) {
                return l;
            }
        }
        
        return null;
    }
    
    // Update player's last seen timestamp
    updatePlayerActivity(playerId) {
        const lobbyId = this.playerLobbies.get(playerId);
        if (!lobbyId) return;
        
        const lobby = this.lobbies.get(lobbyId);
        if (!lobby) return;
        
        const player = lobby.players.get(playerId);
        if (player) {
            player.lastSeen = Date.now();
            lobby.lastActivity = Date.now();
        }
    }
    
    // Cleanup empty lobbies and inactive players
    cleanupEmptyLobbies() {
        const now = Date.now();
        const inactiveThreshold = 30 * 60 * 1000; // 30 minutes
        const emptyLobbyThreshold = 5 * 60 * 1000; // 5 minutes
        
        const lobbiesToDelete = [];
        
        for (const [lobbyId, lobby] of this.lobbies) {
            // Remove inactive players
            const playersToRemove = [];
            for (const [playerId, player] of lobby.players) {
                if (now - player.lastSeen > inactiveThreshold) {
                    playersToRemove.push(playerId);
                }
            }
            
            for (const playerId of playersToRemove) {
                this.removePlayerFromLobby(lobbyId, playerId);
                logger.info(`Removed inactive player ${playerId} from lobby ${lobbyId}`);
            }
            
            // Mark empty lobbies for deletion
            if (lobby.players.size === 0 && now - lobby.lastActivity > emptyLobbyThreshold) {
                lobbiesToDelete.push(lobbyId);
            }
        }
        
        // Delete empty lobbies
        for (const lobbyId of lobbiesToDelete) {
            this.lobbies.delete(lobbyId);
            logger.info(`Cleaned up empty lobby ${lobbyId}`);
        }
        
        if (lobbiesToDelete.length > 0) {
            logger.info(`Cleanup completed: removed ${lobbiesToDelete.length} empty lobbies`);
        }
    }
    
    // Generate a unique lobby ID
    generateLobbyId() {
        let attempts = 0;
        const maxAttempts = 100;
        
        while (attempts < maxAttempts) {
            const id = this.generateRandomId(config.lobby.lobbyIdLength);
            if (!this.lobbies.has(id)) {
                return id;
            }
            attempts++;
        }
        
        // Fallback to UUID if we can't generate a short unique ID
        return uuidv4().substring(0, config.lobby.lobbyIdLength).toUpperCase();
    }
    
    // Generate random alphanumeric ID
    generateRandomId(length) {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let result = '';
        for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return result;
    }
    
    // Get statistics
    getStats() {
        const stats = {
            totalLobbies: this.lobbies.size,
            totalPlayers: this.playerLobbies.size,
            publicLobbies: 0,
            waitingLobbies: 0,
            inGameLobbies: 0,
            lobbyStates: {},
            playerDistribution: {}
        };
        
        for (const lobby of this.lobbies.values()) {
            if (lobby.isPublic) stats.publicLobbies++;
            
            stats.lobbyStates[lobby.state] = (stats.lobbyStates[lobby.state] || 0) + 1;
            
            const playerCount = lobby.players.size;
            stats.playerDistribution[playerCount] = (stats.playerDistribution[playerCount] || 0) + 1;
            
            if (lobby.state === 'waiting') stats.waitingLobbies++;
            if (lobby.state === 'in_game') stats.inGameLobbies++;
        }
        
        return stats;
    }
    
    // Get total lobby count
    getLobbyCount() {
        return this.lobbies.size;
    }
    
    // Validate lobby creation parameters
    validateLobbyCreation(lobbyInfo) {
        const errors = [];
        
        if (this.lobbies.size >= config.lobby.maxLobbies) {
            errors.push('Maximum number of lobbies reached');
        }
        
        if (lobbyInfo.name && lobbyInfo.name.length > config.lobby.maxLobbyNameLength) {
            errors.push(`Lobby name too long (max ${config.lobby.maxLobbyNameLength} characters)`);
        }
        
        if (lobbyInfo.maxPlayers && (lobbyInfo.maxPlayers < 2 || lobbyInfo.maxPlayers > config.lobby.maxPlayersPerLobby)) {
            errors.push(`Invalid max players (must be between 2 and ${config.lobby.maxPlayersPerLobby})`);
        }
        
        return errors;
    }
    
    // Validate player join parameters
    validatePlayerJoin(playerInfo) {
        const errors = [];
        
        if (!playerInfo.username || playerInfo.username.trim().length === 0) {
            errors.push('Username is required');
        }
        
        if (playerInfo.username && playerInfo.username.length > config.lobby.maxUsernameLength) {
            errors.push(`Username too long (max ${config.lobby.maxUsernameLength} characters)`);
        }
        
        return errors;
    }
}

module.exports = LobbyManager;
