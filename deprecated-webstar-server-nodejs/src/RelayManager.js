const config = require('../config');
const logger = require('./Logger');

class RelayManager {
    constructor() {
        this.relayLobbies = new Map(); // lobbyId -> Set of player websockets
        this.playerRelayInfo = new Map(); // websocket -> { lobbyId, playerId }
        this.messageQueue = new Map(); // playerId -> Array of queued messages
        this.rateLimiters = new Map(); // playerId -> { count, resetTime }
    }
    
    // Handle relay connection
    addRelayClient(ws, lobbyId, playerId) {
        // Initialize relay lobby if it doesn't exist
        if (!this.relayLobbies.has(lobbyId)) {
            this.relayLobbies.set(lobbyId, new Set());
        }
        
        // Add client to relay lobby
        this.relayLobbies.get(lobbyId).add(ws);
        this.playerRelayInfo.set(ws, { lobbyId, playerId });
        
        // Send any queued messages
        this.deliverQueuedMessages(playerId);
        
        logger.info(`Player ${playerId} connected to relay for lobby ${lobbyId}`);
        
        return true;
    }
    
    // Remove relay client
    removeRelayClient(ws) {
        const relayInfo = this.playerRelayInfo.get(ws);
        if (!relayInfo) return false;
        
        const { lobbyId, playerId } = relayInfo;
        
        // Remove from relay lobby
        const relayLobby = this.relayLobbies.get(lobbyId);
        if (relayLobby) {
            relayLobby.delete(ws);
            
            // Clean up empty relay lobby
            if (relayLobby.size === 0) {
                this.relayLobbies.delete(lobbyId);
            }
        }
        
        // Clean up player info
        this.playerRelayInfo.delete(ws);
        this.messageQueue.delete(playerId);
        this.rateLimiters.delete(playerId);
        
        logger.info(`Player ${playerId} disconnected from relay for lobby ${lobbyId}`);
        
        return true;
    }
    
    // Handle relay message
    handleMessage(ws, message, clientInfo) {
        try {
            switch (message.type) {
                case 'relay_join':
                    this.handleRelayJoin(ws, message, clientInfo);
                    break;
                
                case 'relay_message':
                    this.handleRelayMessage(ws, message, clientInfo);
                    break;
                
                case 'relay_heartbeat':
                    this.handleRelayHeartbeat(ws, message, clientInfo);
                    break;
                
                default:
                    logger.warn(`Unknown relay message type: ${message.type}`);
                    this.sendRelayError(ws, `Unknown message type: ${message.type}`);
                    break;
            }
        } catch (error) {
            logger.error(`Error handling relay message ${message.type}:`, error);
            this.sendRelayError(ws, 'Internal server error');
        }
    }
    
    handleRelayJoin(ws, message, clientInfo) {
        const { lobby_id, player_id } = message;
        
        if (!lobby_id || !player_id) {
            return this.sendRelayError(ws, 'Lobby ID and Player ID required');
        }
        
        // Add to relay
        this.addRelayClient(ws, lobby_id, player_id);
        
        // Update client info
        clientInfo.lobbyId = lobby_id;
        clientInfo.playerId = player_id;
        
        // Send confirmation
        this.sendMessage(ws, {
            type: 'relay_joined',
            lobby_id: lobby_id,
            player_id: player_id
        });
        
        // Notify other players in the relay
        this.broadcastToRelayLobby(lobby_id, {
            type: 'relay_player_joined',
            player_id: player_id
        }, ws);
    }
    
    handleRelayMessage(ws, message, clientInfo) {
        const { target_player_id, data } = message;
        const relayInfo = this.playerRelayInfo.get(ws);
        
        if (!relayInfo) {
            return this.sendRelayError(ws, 'Not connected to relay');
        }
        
        const { lobbyId, playerId } = relayInfo;
        
        // Rate limiting
        if (!this.checkRateLimit(playerId)) {
            return this.sendRelayError(ws, 'Rate limit exceeded');
        }
        
        // Validate message size
        const messageSize = JSON.stringify(data).length;
        if (messageSize > config.relay.maxMessageSize) {
            return this.sendRelayError(ws, 'Message too large');
        }
        
        const relayMessage = {
            type: 'relay_message',
            from_player_id: playerId,
            data: data,
            timestamp: Date.now()
        };
        
        if (target_player_id) {
            // Send to specific player
            this.sendToRelayPlayer(lobbyId, target_player_id, relayMessage);
        } else {
            // Broadcast to all players in relay lobby
            this.broadcastToRelayLobby(lobbyId, relayMessage, ws);
        }
        
        logger.debug(`Relay message from ${playerId} to ${target_player_id || 'all'} in lobby ${lobbyId}`);
    }
    
    handleRelayHeartbeat(ws, message, clientInfo) {
        this.sendMessage(ws, {
            type: 'relay_heartbeat_ack',
            timestamp: Date.now()
        });
    }
    
    // Send message to specific player in relay
    sendToRelayPlayer(lobbyId, targetPlayerId, message) {
        const relayLobby = this.relayLobbies.get(lobbyId);
        if (!relayLobby) return false;
        
        for (const playerWs of relayLobby) {
            const relayInfo = this.playerRelayInfo.get(playerWs);
            if (relayInfo && relayInfo.playerId === targetPlayerId) {
                this.sendMessage(playerWs, message);
                return true;
            }
        }
        
        // If player not found, queue the message
        this.queueMessage(targetPlayerId, message);
        return false;
    }
    
    // Broadcast to all players in relay lobby
    broadcastToRelayLobby(lobbyId, message, excludeWs = null) {
        const relayLobby = this.relayLobbies.get(lobbyId);
        if (!relayLobby) return;
        
        for (const playerWs of relayLobby) {
            if (excludeWs && playerWs === excludeWs) continue;
            this.sendMessage(playerWs, message);
        }
    }
    
    // Queue message for offline player
    queueMessage(playerId, message) {
        if (!this.messageQueue.has(playerId)) {
            this.messageQueue.set(playerId, []);
        }
        
        const queue = this.messageQueue.get(playerId);
        queue.push({
            message: message,
            timestamp: Date.now()
        });
        
        // Limit queue size
        const maxQueueSize = 100;
        if (queue.length > maxQueueSize) {
            queue.splice(0, queue.length - maxQueueSize);
        }
        
        logger.debug(`Queued message for offline player ${playerId}`);
    }
    
    // Deliver queued messages to player
    deliverQueuedMessages(playerId) {
        const queue = this.messageQueue.get(playerId);
        if (!queue || queue.length === 0) return;
        
        const relayLobby = this.findPlayerRelay(playerId);
        if (!relayLobby) return;
        
        const now = Date.now();
        const messageTimeout = 5 * 60 * 1000; // 5 minutes
        
        // Send non-expired messages
        const validMessages = queue.filter(item => now - item.timestamp < messageTimeout);
        
        for (const item of validMessages) {
            this.sendToRelayPlayer(relayLobby.lobbyId, playerId, item.message);
        }
        
        // Clear the queue
        this.messageQueue.delete(playerId);
        
        if (validMessages.length > 0) {
            logger.info(`Delivered ${validMessages.length} queued messages to player ${playerId}`);
        }
    }
    
    // Find relay lobby for player
    findPlayerRelay(playerId) {
        for (const [lobbyId, playerWsSet] of this.relayLobbies) {
            for (const playerWs of playerWsSet) {
                const relayInfo = this.playerRelayInfo.get(playerWs);
                if (relayInfo && relayInfo.playerId === playerId) {
                    return { lobbyId, playerWs };
                }
            }
        }
        return null;
    }
    
    // Rate limiting
    checkRateLimit(playerId) {
        const now = Date.now();
        const windowMs = 1000; // 1 second window
        
        if (!this.rateLimiters.has(playerId)) {
            this.rateLimiters.set(playerId, {
                count: 1,
                resetTime: now + windowMs
            });
            return true;
        }
        
        const limiter = this.rateLimiters.get(playerId);
        
        if (now > limiter.resetTime) {
            // Reset window
            limiter.count = 1;
            limiter.resetTime = now + windowMs;
            return true;
        }
        
        if (limiter.count >= config.relay.maxMessagesPerSecond) {
            return false; // Rate limit exceeded
        }
        
        limiter.count++;
        return true;
    }
    
    // Remove player from lobby
    removePlayerFromLobby(lobbyId, playerId) {
        const relayLobby = this.relayLobbies.get(lobbyId);
        if (!relayLobby) return;
        
        // Find and remove player's WebSocket
        for (const playerWs of relayLobby) {
            const relayInfo = this.playerRelayInfo.get(playerWs);
            if (relayInfo && relayInfo.playerId === playerId) {
                this.removeRelayClient(playerWs);
                break;
            }
        }
    }
    
    // Get relay statistics
    getStats() {
        return {
            relayLobbies: this.relayLobbies.size,
            totalRelayPlayers: this.playerRelayInfo.size,
            queuedMessages: Array.from(this.messageQueue.values()).reduce((sum, queue) => sum + queue.length, 0),
            rateLimitedPlayers: Array.from(this.rateLimiters.values()).filter(limiter => 
                limiter.count >= config.relay.maxMessagesPerSecond
            ).length
        };
    }
    
    // Clean up expired data
    cleanup() {
        const now = Date.now();
        const messageTimeout = 5 * 60 * 1000; // 5 minutes
        
        // Clean up expired queued messages
        for (const [playerId, queue] of this.messageQueue) {
            const validMessages = queue.filter(item => now - item.timestamp < messageTimeout);
            if (validMessages.length === 0) {
                this.messageQueue.delete(playerId);
            } else if (validMessages.length < queue.length) {
                this.messageQueue.set(playerId, validMessages);
            }
        }
        
        // Clean up expired rate limiters
        for (const [playerId, limiter] of this.rateLimiters) {
            if (now > limiter.resetTime) {
                this.rateLimiters.delete(playerId);
            }
        }
    }
    
    // Helper methods
    
    sendMessage(ws, message) {
        if (ws.readyState === 1) { // WebSocket.OPEN
            try {
                const data = config.relay.enableCompression ? 
                    JSON.stringify(message) : 
                    JSON.stringify(message);
                ws.send(data);
            } catch (error) {
                logger.error('Error sending relay message:', error);
            }
        }
    }
    
    sendRelayError(ws, errorMessage) {
        this.sendMessage(ws, {
            type: 'relay_error',
            message: errorMessage,
            timestamp: Date.now()
        });
    }
}

module.exports = RelayManager;
