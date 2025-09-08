const WebSocket = require('ws');
const http = require('http');
const express = require('express');
const cors = require('cors');
const compression = require('compression');
const { v4: uuidv4 } = require('uuid');

const config = require('./config');
const LobbyManager = require('./src/LobbyManager');
const RelayManager = require('./src/RelayManager');
const MessageHandler = require('./src/MessageHandler');
const StatsCollector = require('./src/StatsCollector');
const logger = require('./src/Logger');

class WebStarServer {
    constructor() {
        this.app = express();
        this.server = http.createServer(this.app);
        this.wss = null;
        this.relayWss = null;
        
        // Core managers
        this.lobbyManager = new LobbyManager();
        this.relayManager = new RelayManager();
        this.messageHandler = new MessageHandler(this.lobbyManager, this.relayManager);
        this.statsCollector = new StatsCollector();
        
        // Client tracking
        this.clients = new Map(); // websocket -> client info
        this.relayClients = new Map(); // websocket -> relay client info
        
        this.setupExpress();
        this.setupWebSocket();
        this.setupRelayWebSocket();
        this.setupMessageHandler();
        this.setupCleanupHandlers();
    }
    
    setupExpress() {
        // Middleware
        this.app.use(compression());
        this.app.use(cors({
            origin: config.cors.allowedOrigins,
            credentials: true
        }));
        this.app.use(express.json());
        this.app.use(express.static('public'));
        
        // Health check endpoint
        this.app.get('/health', (req, res) => {
            res.json({
                status: 'healthy',
                uptime: process.uptime(),
                lobbies: this.lobbyManager.getLobbyCount(),
                clients: this.clients.size,
                relayClients: this.relayClients.size,
                memory: process.memoryUsage()
            });
        });
        
        // Stats endpoint
        this.app.get('/stats', (req, res) => {
            res.json(this.statsCollector.getStats());
        });
        
        // Lobby list endpoint
        this.app.get('/lobbies', (req, res) => {
            const lobbies = this.lobbyManager.getPublicLobbies();
            res.json(lobbies);
        });
        
        logger.info('Express app configured');
    }
    
    setupWebSocket() {
        // Main signaling WebSocket server
        this.wss = new WebSocket.Server({
            server: this.server,
            path: '/ws',
            verifyClient: (info) => {
                // Add custom verification logic here if needed
                return true;
            }
        });
        
        this.wss.on('connection', (ws, request) => {
            this.handleSignalingConnection(ws, request);
        });
        
        logger.info('Signaling WebSocket server configured on /ws');
    }
    
    setupRelayWebSocket() {
        // Relay WebSocket server for fallback
        this.relayWss = new WebSocket.Server({
            server: this.server,
            path: '/relay',
            verifyClient: (info) => {
                return true;
            }
        });
        
        this.relayWss.on('connection', (ws, request) => {
            this.handleRelayConnection(ws, request);
        });
        
        logger.info('Relay WebSocket server configured on /relay');
    }
    
    setupMessageHandler() {
        // Provide server methods to message handler
        this.messageHandler.findPlayerWebSocket = (lobbyId, playerId) => {
            for (const [ws, clientInfo] of this.clients) {
                if (clientInfo.lobbyId === lobbyId && clientInfo.playerId === playerId) {
                    return ws;
                }
            }
            return null;
        };
        
        this.messageHandler.broadcastToLobby = (lobbyId, message, excludePlayerId = null) => {
            this.broadcastToLobby(lobbyId, message, excludePlayerId);
        };
        
        this.messageHandler.sendMessage = (ws, message) => {
            this.sendMessage(ws, message);
        };
        
        this.messageHandler.sendError = (ws, errorMessage) => {
            this.sendError(ws, errorMessage);
        };
    }
    
    handleSignalingConnection(ws, request) {
        const clientId = uuidv4();
        const clientInfo = {
            id: clientId,
            ws: ws,
            ip: request.socket.remoteAddress,
            userAgent: request.headers['user-agent'],
            connectedAt: new Date(),
            lobbyId: null,
            playerId: null,
            username: null,
            lastHeartbeat: Date.now()
        };
        
        this.clients.set(ws, clientInfo);
        this.statsCollector.recordConnection('signaling');
        
        logger.info(`Signaling client connected: ${clientId} from ${clientInfo.ip}`);
        
        // Set up message handling
        ws.on('message', (data) => {
            this.handleSignalingMessage(ws, data);
        });
        
        ws.on('close', (code, reason) => {
            this.handleSignalingDisconnection(ws, code, reason);
        });
        
        ws.on('error', (error) => {
            logger.error(`Signaling WebSocket error for ${clientId}:`, error);
        });
        
        // Send welcome message
        this.sendMessage(ws, {
            type: 'connected',
            clientId: clientId,
            timestamp: Date.now()
        });
    }
    
    handleRelayConnection(ws, request) {
        const clientId = uuidv4();
        const clientInfo = {
            id: clientId,
            ws: ws,
            ip: request.socket.remoteAddress,
            connectedAt: new Date(),
            lobbyId: null,
            playerId: null,
            lastHeartbeat: Date.now()
        };
        
        this.relayClients.set(ws, clientInfo);
        this.statsCollector.recordConnection('relay');
        
        logger.info(`Relay client connected: ${clientId} from ${clientInfo.ip}`);
        
        ws.on('message', (data) => {
            this.handleRelayMessage(ws, data);
        });
        
        ws.on('close', (code, reason) => {
            this.handleRelayDisconnection(ws, code, reason);
        });
        
        ws.on('error', (error) => {
            logger.error(`Relay WebSocket error for ${clientId}:`, error);
        });
    }
    
    handleSignalingMessage(ws, data) {
        const clientInfo = this.clients.get(ws);
        if (!clientInfo) return;
        
        try {
            const message = JSON.parse(data);
            clientInfo.lastHeartbeat = Date.now();
            
            this.statsCollector.recordMessage('signaling', message.type);
            
            logger.debug(`Signaling message from ${clientInfo.id}:`, message.type);
            
            // Handle message through message handler
            this.messageHandler.handleSignalingMessage(ws, message, clientInfo);
            
        } catch (error) {
            logger.error(`Error parsing signaling message from ${clientInfo.id}:`, error);
            this.sendError(ws, 'Invalid message format');
        }
    }
    
    handleRelayMessage(ws, data) {
        const clientInfo = this.relayClients.get(ws);
        if (!clientInfo) return;
        
        try {
            const message = JSON.parse(data);
            clientInfo.lastHeartbeat = Date.now();
            
            this.statsCollector.recordMessage('relay', message.type);
            
            logger.debug(`Relay message from ${clientInfo.id}:`, message.type);
            
            // Handle message through relay manager
            this.relayManager.handleMessage(ws, message, clientInfo);
            
        } catch (error) {
            logger.error(`Error parsing relay message from ${clientInfo.id}:`, error);
            this.sendMessage(ws, {
                type: 'relay_error',
                message: 'Invalid message format'
            });
        }
    }
    
    handleSignalingDisconnection(ws, code, reason) {
        const clientInfo = this.clients.get(ws);
        if (!clientInfo) return;
        
        logger.info(`Signaling client disconnected: ${clientInfo.id} (${code})`);
        
        // Remove from lobby if in one
        if (clientInfo.lobbyId && clientInfo.playerId) {
            this.lobbyManager.removePlayerFromLobby(clientInfo.lobbyId, clientInfo.playerId);
            
            // Notify other players in the lobby
            const lobby = this.lobbyManager.getLobby(clientInfo.lobbyId);
            if (lobby) {
                this.broadcastToLobby(clientInfo.lobbyId, {
                    type: 'player_left',
                    player_id: clientInfo.playerId,
                    username: clientInfo.username
                }, clientInfo.playerId);
                
                // Update player list
                this.sendPlayerListUpdate(clientInfo.lobbyId);
                
                // Check if host migration is needed
                if (lobby.hostPlayerId === clientInfo.playerId && lobby.players.size > 0) {
                    this.handleHostMigration(clientInfo.lobbyId);
                }
            }
        }
        
        this.clients.delete(ws);
        this.statsCollector.recordDisconnection('signaling');
    }
    
    handleRelayDisconnection(ws, code, reason) {
        const clientInfo = this.relayClients.get(ws);
        if (!clientInfo) return;
        
        logger.info(`Relay client disconnected: ${clientInfo.id} (${code})`);
        
        // Remove from relay lobby
        if (clientInfo.lobbyId && clientInfo.playerId) {
            this.relayManager.removePlayerFromLobby(clientInfo.lobbyId, clientInfo.playerId);
        }
        
        this.relayClients.delete(ws);
        this.statsCollector.recordDisconnection('relay');
    }
    
    handleHostMigration(lobbyId) {
        const lobby = this.lobbyManager.getLobby(lobbyId);
        if (!lobby || lobby.players.size === 0) return;
        
        // Select new host (lowest player ID)
        const playerIds = Array.from(lobby.players.keys()).sort((a, b) => a - b);
        const newHostId = playerIds[0];
        
        logger.info(`Host migration in lobby ${lobbyId}: new host is player ${newHostId}`);
        
        // Update lobby
        lobby.hostPlayerId = newHostId;
        
        // Notify all players
        this.broadcastToLobby(lobbyId, {
            type: 'host_migration',
            new_host_id: newHostId,
            timestamp: Date.now()
        });
    }
    
    broadcastToLobby(lobbyId, message, excludePlayerId = null) {
        const lobby = this.lobbyManager.getLobby(lobbyId);
        if (!lobby) return;
        
        for (const [playerId, playerInfo] of lobby.players) {
            if (excludePlayerId && playerId === excludePlayerId) continue;
            
            // Find the WebSocket for this player
            for (const [ws, clientInfo] of this.clients) {
                if (clientInfo.lobbyId === lobbyId && clientInfo.playerId === playerId) {
                    this.sendMessage(ws, message);
                    break;
                }
            }
        }
    }
    
    sendPlayerListUpdate(lobbyId) {
        const lobby = this.lobbyManager.getLobby(lobbyId);
        if (!lobby) return;
        
        const playerList = Array.from(lobby.players.values()).map(player => ({
            player_id: player.playerId,
            username: player.username,
            peer_id: player.peerId,
            is_host: player.playerId === lobby.hostPlayerId,
            connected_at: player.connectedAt
        }));
        
        this.broadcastToLobby(lobbyId, {
            type: 'player_list_updated',
            player_list: playerList
        });
    }
    
    sendMessage(ws, message) {
        if (ws.readyState === WebSocket.OPEN) {
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
    
    setupCleanupHandlers() {
        // Heartbeat monitoring
        setInterval(() => {
            this.checkHeartbeats();
        }, config.heartbeat.checkInterval);
        
        // Cleanup empty lobbies
        setInterval(() => {
            this.lobbyManager.cleanupEmptyLobbies();
        }, config.lobby.cleanupInterval);
        
        // Process shutdown handlers
        process.on('SIGTERM', () => this.shutdown('SIGTERM'));
        process.on('SIGINT', () => this.shutdown('SIGINT'));
        process.on('uncaughtException', (error) => {
            logger.error('Uncaught exception:', error);
            this.shutdown('uncaughtException');
        });
    }
    
    checkHeartbeats() {
        const now = Date.now();
        const timeout = config.heartbeat.timeout;
        
        // Check signaling clients
        for (const [ws, clientInfo] of this.clients) {
            if (now - clientInfo.lastHeartbeat > timeout) {
                logger.warn(`Client ${clientInfo.id} heartbeat timeout, disconnecting`);
                ws.close(1001, 'Heartbeat timeout');
            }
        }
        
        // Check relay clients
        for (const [ws, clientInfo] of this.relayClients) {
            if (now - clientInfo.lastHeartbeat > timeout) {
                logger.warn(`Relay client ${clientInfo.id} heartbeat timeout, disconnecting`);
                ws.close(1001, 'Heartbeat timeout');
            }
        }
    }
    
    start() {
        this.server.listen(config.server.port, config.server.host, () => {
            logger.info(`WebStar server started on ${config.server.host}:${config.server.port}`);
            logger.info(`Signaling: ws://${config.server.host}:${config.server.port}/ws`);
            logger.info(`Relay: ws://${config.server.host}:${config.server.port}/relay`);
            logger.info(`Health: http://${config.server.host}:${config.server.port}/health`);
        });
    }
    
    shutdown(signal) {
        logger.info(`Received ${signal}, shutting down gracefully...`);
        
        // Close all WebSocket connections
        this.wss.clients.forEach((ws) => {
            ws.close(1001, 'Server shutting down');
        });
        
        this.relayWss.clients.forEach((ws) => {
            ws.close(1001, 'Server shutting down');
        });
        
        // Close HTTP server
        this.server.close(() => {
            logger.info('Server closed');
            process.exit(0);
        });
        
        // Force exit after 10 seconds
        setTimeout(() => {
            logger.error('Force exit after timeout');
            process.exit(1);
        }, 10000);
    }
}

// Start server if this file is run directly
if (require.main === module) {
    const server = new WebStarServer();
    server.start();
}

module.exports = WebStarServer;
