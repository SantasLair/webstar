const config = require('../config');
const logger = require('./Logger');

class MessageHandler {
    constructor(lobbyManager, relayManager) {
        this.lobbyManager = lobbyManager;
        this.relayManager = relayManager;
    }
    
    // Handle signaling messages
    handleSignalingMessage(ws, message, clientInfo) {
        try {
            switch (message.type) {
                case 'heartbeat':
                    this.handleHeartbeat(ws, message, clientInfo);
                    break;
                
                case 'create_lobby':
                    this.handleCreateLobby(ws, message, clientInfo);
                    break;
                
                case 'join_lobby':
                    this.handleJoinLobby(ws, message, clientInfo);
                    break;
                
                case 'leave_lobby':
                    this.handleLeaveLobby(ws, message, clientInfo);
                    break;
                
                case 'lobby_list':
                    this.handleLobbyList(ws, message, clientInfo);
                    break;
                
                case 'player_ready':
                    this.handlePlayerReady(ws, message, clientInfo);
                    break;
                
                case 'start_game':
                    this.handleStartGame(ws, message, clientInfo);
                    break;
                
                case 'webrtc_offer':
                case 'webrtc_answer':
                case 'webrtc_ice_candidate':
                    this.handleWebRTCSignaling(ws, message, clientInfo);
                    break;
                
                case 'peer_connection_failed':
                    this.handlePeerConnectionFailed(ws, message, clientInfo);
                    break;
                
                case 'update_player_info':
                    this.handleUpdatePlayerInfo(ws, message, clientInfo);
                    break;
                
                case 'lobby_settings':
                    this.handleLobbySettings(ws, message, clientInfo);
                    break;
                
                default:
                    logger.warn(`Unknown signaling message type: ${message.type} from ${clientInfo.id}`);
                    this.sendError(ws, `Unknown message type: ${message.type}`);
                    break;
            }
        } catch (error) {
            logger.error(`Error handling signaling message ${message.type}:`, error);
            this.sendError(ws, 'Internal server error');
        }
    }
    
    handleHeartbeat(ws, message, clientInfo) {
        this.sendMessage(ws, {
            type: 'heartbeat_ack',
            timestamp: Date.now()
        });
        
        // Update player activity
        if (clientInfo.playerId) {
            this.lobbyManager.updatePlayerActivity(clientInfo.playerId);
        }
    }
    
    handleCreateLobby(ws, message, clientInfo) {
        try {
            const { lobby_info, player_info } = message;
            
            // Validate input
            const lobbyErrors = this.lobbyManager.validateLobbyCreation(lobby_info || {});
            const playerErrors = this.lobbyManager.validatePlayerJoin(player_info || {});
            
            if (lobbyErrors.length > 0 || playerErrors.length > 0) {
                return this.sendError(ws, [...lobbyErrors, ...playerErrors].join(', '));
            }
            
            // Generate player ID
            const playerId = this.generatePlayerId();
            
            // Create lobby
            const lobby = this.lobbyManager.createLobby(playerId, lobby_info);
            
            // Add creator as first player
            this.lobbyManager.joinLobby(lobby.id, playerId, {
                username: player_info.username,
                peerId: player_info.peer_id,
                metadata: player_info.metadata
            });
            
            // Update client info
            clientInfo.lobbyId = lobby.id;
            clientInfo.playerId = playerId;
            clientInfo.username = player_info.username;
            
            // Send response
            this.sendMessage(ws, {
                type: 'lobby_created',
                lobby_id: lobby.id,
                player_id: playerId,
                lobby_info: this.serializeLobby(lobby),
                ice_servers: config.webrtc.iceServers
            });
            
            logger.info(`Player ${playerId} created lobby ${lobby.id}`);
            
        } catch (error) {
            logger.error('Error creating lobby:', error);
            this.sendError(ws, error.message);
        }
    }
    
    handleJoinLobby(ws, message, clientInfo) {
        try {
            const { lobby_id, player_info } = message;
            
            // Validate input
            const playerErrors = this.lobbyManager.validatePlayerJoin(player_info || {});
            if (playerErrors.length > 0) {
                return this.sendError(ws, playerErrors.join(', '));
            }
            
            // Generate player ID
            const playerId = this.generatePlayerId();
            
            // Join lobby
            const lobby = this.lobbyManager.joinLobby(lobby_id, playerId, {
                username: player_info.username,
                peerId: player_info.peer_id,
                metadata: player_info.metadata
            });
            
            // Update client info
            clientInfo.lobbyId = lobby_id;
            clientInfo.playerId = playerId;
            clientInfo.username = player_info.username;
            
            // Send response to joining player
            this.sendMessage(ws, {
                type: 'lobby_joined',
                lobby_id: lobby_id,
                player_id: playerId,
                lobby_info: this.serializeLobby(lobby),
                ice_servers: config.webrtc.iceServers
            });
            
            // Notify other players
            this.broadcastToLobby(lobby_id, {
                type: 'player_joined',
                player_info: {
                    player_id: playerId,
                    username: player_info.username,
                    peer_id: player_info.peer_id,
                    metadata: player_info.metadata
                }
            }, playerId);
            
            logger.info(`Player ${playerId} (${player_info.username}) joined lobby ${lobby_id}`);
            
        } catch (error) {
            logger.error('Error joining lobby:', error);
            this.sendError(ws, error.message);
        }
    }
    
    handleLeaveLobby(ws, message, clientInfo) {
        if (!clientInfo.lobbyId || !clientInfo.playerId) {
            return this.sendError(ws, 'Not in a lobby');
        }
        
        const lobbyId = clientInfo.lobbyId;
        const playerId = clientInfo.playerId;
        const username = clientInfo.username;
        
        // Remove from lobby
        this.lobbyManager.removePlayerFromLobby(lobbyId, playerId);
        
        // Notify other players
        this.broadcastToLobby(lobbyId, {
            type: 'player_left',
            player_id: playerId,
            username: username
        }, playerId);
        
        // Update client info
        clientInfo.lobbyId = null;
        clientInfo.playerId = null;
        clientInfo.username = null;
        
        // Send confirmation
        this.sendMessage(ws, {
            type: 'lobby_left',
            lobby_id: lobbyId
        });
        
        logger.info(`Player ${playerId} (${username}) left lobby ${lobbyId}`);
    }
    
    handleLobbyList(ws, message, clientInfo) {
        const publicLobbies = this.lobbyManager.getPublicLobbies();
        
        this.sendMessage(ws, {
            type: 'lobby_list',
            lobbies: publicLobbies
        });
    }
    
    handlePlayerReady(ws, message, clientInfo) {
        if (!clientInfo.lobbyId || !clientInfo.playerId) {
            return this.sendError(ws, 'Not in a lobby');
        }
        
        const { is_ready } = message;
        const success = this.lobbyManager.setPlayerReady(clientInfo.lobbyId, clientInfo.playerId, is_ready);
        
        if (!success) {
            return this.sendError(ws, 'Failed to update ready state');
        }
        
        // Broadcast to lobby
        this.broadcastToLobby(clientInfo.lobbyId, {
            type: 'player_ready_changed',
            player_id: clientInfo.playerId,
            is_ready: is_ready
        });
        
        // Check if all players are ready
        const lobby = this.lobbyManager.getLobby(clientInfo.lobbyId);
        if (lobby && lobby.players.size >= 2) {
            const allReady = Array.from(lobby.players.values()).every(player => player.isReady);
            if (allReady) {
                this.broadcastToLobby(clientInfo.lobbyId, {
                    type: 'all_players_ready'
                });
            }
        }
    }
    
    handleStartGame(ws, message, clientInfo) {
        if (!clientInfo.lobbyId || !clientInfo.playerId) {
            return this.sendError(ws, 'Not in a lobby');
        }
        
        const lobby = this.lobbyManager.getLobby(clientInfo.lobbyId);
        if (!lobby) {
            return this.sendError(ws, 'Lobby not found');
        }
        
        // Only host can start the game
        if (lobby.hostPlayerId !== clientInfo.playerId) {
            return this.sendError(ws, 'Only the host can start the game');
        }
        
        // Check if enough players
        if (lobby.players.size < 2) {
            return this.sendError(ws, 'Need at least 2 players to start');
        }
        
        // Update lobby state
        this.lobbyManager.setLobbyState(clientInfo.lobbyId, 'in_game');
        
        // Broadcast game start
        this.broadcastToLobby(clientInfo.lobbyId, {
            type: 'game_started',
            game_settings: message.game_settings || {},
            timestamp: Date.now()
        });
        
        logger.info(`Game started in lobby ${clientInfo.lobbyId} by host ${clientInfo.playerId}`);
    }
    
    handleWebRTCSignaling(ws, message, clientInfo) {
        if (!clientInfo.lobbyId) {
            return this.sendError(ws, 'Not in a lobby');
        }
        
        const { target_player_id, data } = message;
        
        if (!target_player_id) {
            return this.sendError(ws, 'Target player ID required for WebRTC signaling');
        }
        
        // Find target player's WebSocket
        const targetWs = this.findPlayerWebSocket(clientInfo.lobbyId, target_player_id);
        if (!targetWs) {
            return this.sendError(ws, 'Target player not found');
        }
        
        // Forward the WebRTC signaling message
        this.sendMessage(targetWs, {
            type: message.type,
            from_player_id: clientInfo.playerId,
            data: data
        });
        
        logger.debug(`WebRTC ${message.type} forwarded from ${clientInfo.playerId} to ${target_player_id}`);
    }
    
    handlePeerConnectionFailed(ws, message, clientInfo) {
        if (!clientInfo.lobbyId) {
            return;
        }
        
        const { target_player_id, reason } = message;
        
        logger.info(`WebRTC connection failed between ${clientInfo.playerId} and ${target_player_id}: ${reason}`);
        
        // Notify the target player about the connection failure
        const targetWs = this.findPlayerWebSocket(clientInfo.lobbyId, target_player_id);
        if (targetWs) {
            this.sendMessage(targetWs, {
                type: 'peer_connection_failed',
                from_player_id: clientInfo.playerId,
                reason: reason
            });
        }
        
        // Both players can fall back to relay mode if needed
        this.sendMessage(ws, {
            type: 'fallback_to_relay',
            relay_endpoint: `/relay`,
            target_player_id: target_player_id
        });
        
        if (targetWs) {
            this.sendMessage(targetWs, {
                type: 'fallback_to_relay',
                relay_endpoint: `/relay`,
                target_player_id: clientInfo.playerId
            });
        }
    }
    
    handleUpdatePlayerInfo(ws, message, clientInfo) {
        if (!clientInfo.lobbyId || !clientInfo.playerId) {
            return this.sendError(ws, 'Not in a lobby');
        }
        
        const lobby = this.lobbyManager.getLobby(clientInfo.lobbyId);
        if (!lobby) {
            return this.sendError(ws, 'Lobby not found');
        }
        
        const player = lobby.players.get(clientInfo.playerId);
        if (!player) {
            return this.sendError(ws, 'Player not found in lobby');
        }
        
        // Update player info
        if (message.username) {
            player.username = message.username;
            clientInfo.username = message.username;
        }
        
        if (message.peer_id) {
            player.peerId = message.peer_id;
        }
        
        if (message.metadata) {
            player.metadata = { ...player.metadata, ...message.metadata };
        }
        
        // Broadcast update to other players
        this.broadcastToLobby(clientInfo.lobbyId, {
            type: 'player_info_updated',
            player_id: clientInfo.playerId,
            username: player.username,
            peer_id: player.peerId,
            metadata: player.metadata
        }, clientInfo.playerId);
    }
    
    handleLobbySettings(ws, message, clientInfo) {
        if (!clientInfo.lobbyId || !clientInfo.playerId) {
            return this.sendError(ws, 'Not in a lobby');
        }
        
        const lobby = this.lobbyManager.getLobby(clientInfo.lobbyId);
        if (!lobby) {
            return this.sendError(ws, 'Lobby not found');
        }
        
        // Only host can change lobby settings
        if (lobby.hostPlayerId !== clientInfo.playerId) {
            return this.sendError(ws, 'Only the host can change lobby settings');
        }
        
        // Update lobby settings
        if (message.lobby_name) {
            lobby.name = message.lobby_name;
        }
        
        if (message.max_players) {
            lobby.maxPlayers = Math.min(message.max_players, config.lobby.maxPlayersPerLobby);
        }
        
        if (message.is_public !== undefined) {
            lobby.isPublic = message.is_public;
        }
        
        if (message.game_settings) {
            lobby.gameSettings = { ...lobby.gameSettings, ...message.game_settings };
        }
        
        // Broadcast settings update
        this.broadcastToLobby(clientInfo.lobbyId, {
            type: 'lobby_settings_updated',
            lobby_info: this.serializeLobby(lobby)
        });
        
        logger.info(`Lobby ${clientInfo.lobbyId} settings updated by host ${clientInfo.playerId}`);
    }
    
    // Helper methods
    
    serializeLobby(lobby) {
        return {
            id: lobby.id,
            name: lobby.name,
            host_player_id: lobby.hostPlayerId,
            max_players: lobby.maxPlayers,
            current_players: lobby.players.size,
            is_public: lobby.isPublic,
            state: lobby.state,
            game_settings: lobby.gameSettings,
            created_at: lobby.createdAt,
            players: Array.from(lobby.players.values()).map(player => ({
                player_id: player.playerId,
                username: player.username,
                peer_id: player.peerId,
                is_ready: player.isReady,
                connected_at: player.connectedAt,
                metadata: player.metadata
            }))
        };
    }
    
    findPlayerWebSocket(lobbyId, playerId) {
        // This would need access to the server's client list
        // For now, return null - the server will need to provide this functionality
        return null;
    }
    
    broadcastToLobby(lobbyId, message, excludePlayerId = null) {
        // This would need access to the server's broadcast functionality
        // The server will implement this method
    }
    
    sendMessage(ws, message) {
        if (ws.readyState === 1) { // WebSocket.OPEN
            try {
                ws.send(JSON.stringify(message));
            } catch (error) {
                logger.error('Error sending message:', error);
            }
        }
    }
    
    sendError(ws, errorMessage) {
        this.sendMessage(ws, {
            type: 'error',
            message: errorMessage,
            timestamp: Date.now()
        });
    }
    
    generatePlayerId() {
        return Math.floor(Math.random() * 1000000);
    }
}

module.exports = MessageHandler;
