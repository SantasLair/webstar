const config = require('../config');

class StatsCollector {
    constructor() {
        this.stats = {
            connections: {
                signaling: { total: 0, current: 0 },
                relay: { total: 0, current: 0 }
            },
            messages: {
                signaling: new Map(), // type -> count
                relay: new Map()
            },
            errors: {
                total: 0,
                byType: new Map()
            },
            performance: {
                uptime: process.uptime(),
                memoryUsage: process.memoryUsage(),
                lastUpdate: Date.now()
            },
            lobbies: {
                created: 0,
                destroyed: 0,
                current: 0
            },
            webrtc: {
                connectionsAttempted: 0,
                connectionsSuccessful: 0,
                connectionsFailed: 0,
                failureReasons: new Map()
            }
        };
        
        this.startTime = Date.now();
        this.retentionHours = config.stats.retentionHours || 24;
        this.timeSeriesData = new Map(); // timestamp -> stats snapshot
        
        // Start periodic collection
        if (config.stats.enableCollection) {
            this.startPeriodicCollection();
        }
    }
    
    // Record connection events
    recordConnection(type) {
        if (this.stats.connections[type]) {
            this.stats.connections[type].total++;
            this.stats.connections[type].current++;
        }
    }
    
    recordDisconnection(type) {
        if (this.stats.connections[type]) {
            this.stats.connections[type].current = Math.max(0, this.stats.connections[type].current - 1);
        }
    }
    
    // Record message events
    recordMessage(connectionType, messageType) {
        if (this.stats.messages[connectionType]) {
            const current = this.stats.messages[connectionType].get(messageType) || 0;
            this.stats.messages[connectionType].set(messageType, current + 1);
        }
    }
    
    // Record error events
    recordError(errorType, error = null) {
        this.stats.errors.total++;
        
        const current = this.stats.errors.byType.get(errorType) || 0;
        this.stats.errors.byType.set(errorType, current + 1);
        
        // Log detailed error for debugging
        if (error) {
            console.error(`[Stats] Error of type ${errorType}:`, error);
        }
    }
    
    // Record lobby events
    recordLobbyCreated() {
        this.stats.lobbies.created++;
        this.stats.lobbies.current++;
    }
    
    recordLobbyDestroyed() {
        this.stats.lobbies.destroyed++;
        this.stats.lobbies.current = Math.max(0, this.stats.lobbies.current - 1);
    }
    
    // Record WebRTC events
    recordWebRTCAttempt() {
        this.stats.webrtc.connectionsAttempted++;
    }
    
    recordWebRTCSuccess() {
        this.stats.webrtc.connectionsSuccessful++;
    }
    
    recordWebRTCFailure(reason = 'unknown') {
        this.stats.webrtc.connectionsFailed++;
        
        const current = this.stats.webrtc.failureReasons.get(reason) || 0;
        this.stats.webrtc.failureReasons.set(reason, current + 1);
    }
    
    // Update current stats
    updateCurrentStats(lobbyManager, relayManager) {
        // Update performance metrics
        this.stats.performance.uptime = process.uptime();
        this.stats.performance.memoryUsage = process.memoryUsage();
        this.stats.performance.lastUpdate = Date.now();
        
        // Update lobby stats from lobby manager
        if (lobbyManager) {
            const lobbyStats = lobbyManager.getStats();
            this.stats.lobbies.current = lobbyStats.totalLobbies;
        }
        
        // Update relay stats
        if (relayManager) {
            const relayStats = relayManager.getStats();
            this.stats.relay = relayStats;
        }
    }
    
    // Get current stats
    getStats() {
        return {
            ...this.stats,
            serverInfo: {
                startTime: this.startTime,
                uptime: Date.now() - this.startTime,
                nodeVersion: process.version,
                platform: process.platform,
                arch: process.arch
            },
            rates: this.calculateRates(),
            health: this.getHealthMetrics()
        };
    }
    
    // Calculate message rates and other derived metrics
    calculateRates() {
        const uptimeMinutes = (Date.now() - this.startTime) / (1000 * 60);
        
        if (uptimeMinutes === 0) {
            return {
                connectionsPerMinute: 0,
                messagesPerMinute: 0,
                errorsPerMinute: 0
            };
        }
        
        const totalMessages = Array.from(this.stats.messages.signaling.values()).reduce((sum, count) => sum + count, 0) +
                            Array.from(this.stats.messages.relay.values()).reduce((sum, count) => sum + count, 0);
        
        return {
            connectionsPerMinute: (this.stats.connections.signaling.total + this.stats.connections.relay.total) / uptimeMinutes,
            messagesPerMinute: totalMessages / uptimeMinutes,
            errorsPerMinute: this.stats.errors.total / uptimeMinutes
        };
    }
    
    // Get health metrics
    getHealthMetrics() {
        const memory = this.stats.performance.memoryUsage;
        const memoryUsagePercent = (memory.heapUsed / memory.heapTotal) * 100;
        
        const webrtcSuccessRate = this.stats.webrtc.connectionsAttempted > 0 ? 
            (this.stats.webrtc.connectionsSuccessful / this.stats.webrtc.connectionsAttempted) * 100 : 100;
        
        const errorRate = this.calculateRates().errorsPerMinute;
        
        // Determine overall health status
        let status = 'healthy';
        const issues = [];
        
        if (memoryUsagePercent > 90) {
            status = 'unhealthy';
            issues.push('High memory usage');
        } else if (memoryUsagePercent > 75) {
            status = 'degraded';
            issues.push('Elevated memory usage');
        }
        
        if (webrtcSuccessRate < 50) {
            status = 'unhealthy';
            issues.push('Low WebRTC success rate');
        } else if (webrtcSuccessRate < 80) {
            status = 'degraded';
            issues.push('Reduced WebRTC success rate');
        }
        
        if (errorRate > 10) {
            status = 'unhealthy';
            issues.push('High error rate');
        } else if (errorRate > 5) {
            status = 'degraded';
            issues.push('Elevated error rate');
        }
        
        return {
            status: status,
            issues: issues,
            metrics: {
                memoryUsagePercent: Math.round(memoryUsagePercent * 100) / 100,
                webrtcSuccessRate: Math.round(webrtcSuccessRate * 100) / 100,
                errorRate: Math.round(errorRate * 100) / 100,
                uptimeHours: Math.round(((Date.now() - this.startTime) / (1000 * 60 * 60)) * 100) / 100
            }
        };
    }
    
    // Get detailed message breakdown
    getMessageBreakdown() {
        const breakdown = {
            signaling: {},
            relay: {}
        };
        
        for (const [type, count] of this.stats.messages.signaling) {
            breakdown.signaling[type] = count;
        }
        
        for (const [type, count] of this.stats.messages.relay) {
            breakdown.relay[type] = count;
        }
        
        return breakdown;
    }
    
    // Get error breakdown
    getErrorBreakdown() {
        const breakdown = {};
        
        for (const [type, count] of this.stats.errors.byType) {
            breakdown[type] = count;
        }
        
        return breakdown;
    }
    
    // Get WebRTC failure breakdown
    getWebRTCFailureBreakdown() {
        const breakdown = {};
        
        for (const [reason, count] of this.stats.webrtc.failureReasons) {
            breakdown[reason] = count;
        }
        
        return breakdown;
    }
    
    // Start periodic data collection
    startPeriodicCollection() {
        // Collect stats snapshot every minute
        setInterval(() => {
            this.collectSnapshot();
        }, 60 * 1000);
        
        // Clean up old data every hour
        setInterval(() => {
            this.cleanupOldData();
        }, 60 * 60 * 1000);
    }
    
    // Collect stats snapshot for time series
    collectSnapshot() {
        const timestamp = Date.now();
        const snapshot = {
            timestamp: timestamp,
            connections: {
                signaling: this.stats.connections.signaling.current,
                relay: this.stats.connections.relay.current
            },
            lobbies: this.stats.lobbies.current,
            memory: this.stats.performance.memoryUsage.heapUsed,
            rates: this.calculateRates()
        };
        
        this.timeSeriesData.set(timestamp, snapshot);
    }
    
    // Clean up old time series data
    cleanupOldData() {
        const cutoffTime = Date.now() - (this.retentionHours * 60 * 60 * 1000);
        
        for (const [timestamp] of this.timeSeriesData) {
            if (timestamp < cutoffTime) {
                this.timeSeriesData.delete(timestamp);
            }
        }
    }
    
    // Get time series data
    getTimeSeries(hours = 1) {
        const cutoffTime = Date.now() - (hours * 60 * 60 * 1000);
        const timeSeries = [];
        
        for (const [timestamp, snapshot] of this.timeSeriesData) {
            if (timestamp >= cutoffTime) {
                timeSeries.push(snapshot);
            }
        }
        
        // Sort by timestamp
        timeSeries.sort((a, b) => a.timestamp - b.timestamp);
        
        return timeSeries;
    }
    
    // Export stats for external monitoring
    exportStats() {
        return {
            timestamp: Date.now(),
            server: {
                uptime: this.stats.performance.uptime,
                memory: this.stats.performance.memoryUsage,
                startTime: this.startTime
            },
            connections: this.stats.connections,
            lobbies: this.stats.lobbies,
            messages: this.getMessageBreakdown(),
            errors: this.getErrorBreakdown(),
            webrtc: {
                ...this.stats.webrtc,
                failureBreakdown: this.getWebRTCFailureBreakdown()
            },
            health: this.getHealthMetrics(),
            timeSeries: this.getTimeSeries(1) // Last hour
        };
    }
    
    // Reset stats (for testing or periodic reset)
    reset() {
        this.stats.messages.signaling.clear();
        this.stats.messages.relay.clear();
        this.stats.errors.byType.clear();
        this.stats.webrtc.failureReasons.clear();
        
        this.stats.errors.total = 0;
        this.stats.lobbies = { created: 0, destroyed: 0, current: 0 };
        this.stats.webrtc.connectionsAttempted = 0;
        this.stats.webrtc.connectionsSuccessful = 0;
        this.stats.webrtc.connectionsFailed = 0;
        
        this.timeSeriesData.clear();
        this.startTime = Date.now();
    }
}

module.exports = StatsCollector;
