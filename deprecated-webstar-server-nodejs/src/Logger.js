const fs = require('fs');
const path = require('path');
const config = require('../config');

class Logger {
    constructor() {
        this.logLevel = this.getLogLevel(config.logging.level);
        this.enableFileLogging = config.logging.enableFileLogging;
        this.logDirectory = config.logging.logDirectory;
        
        // Ensure log directory exists if file logging is enabled
        if (this.enableFileLogging && !fs.existsSync(this.logDirectory)) {
            fs.mkdirSync(this.logDirectory, { recursive: true });
        }
        
        this.logLevels = {
            error: 0,
            warn: 1,
            info: 2,
            debug: 3
        };
    }
    
    getLogLevel(level) {
        const levels = {
            'error': 0,
            'warn': 1,
            'info': 2,
            'debug': 3
        };
        return levels[level.toLowerCase()] || 2; // Default to info
    }
    
    formatMessage(level, message, meta = null) {
        const timestamp = new Date().toISOString();
        const pid = process.pid;
        
        let formattedMessage = `[${timestamp}] [${pid}] [${level.toUpperCase()}] ${message}`;
        
        if (meta) {
            if (typeof meta === 'object') {
                formattedMessage += ' ' + JSON.stringify(meta, null, 2);
            } else {
                formattedMessage += ' ' + meta;
            }
        }
        
        return formattedMessage;
    }
    
    writeToFile(level, formattedMessage) {
        if (!this.enableFileLogging) return;
        
        try {
            const today = new Date().toISOString().split('T')[0];
            const logFile = path.join(this.logDirectory, `webstar-${today}.log`);
            
            fs.appendFileSync(logFile, formattedMessage + '\n');
        } catch (error) {
            // Fallback to console if file writing fails
            console.error('Failed to write to log file:', error);
        }
    }
    
    writeToConsole(level, message, meta = null) {
        const formattedMessage = this.formatMessage(level, message, meta);
        
        switch (level) {
            case 'error':
                console.error(formattedMessage);
                break;
            case 'warn':
                console.warn(formattedMessage);
                break;
            case 'info':
                console.info(formattedMessage);
                break;
            case 'debug':
                console.log(formattedMessage);
                break;
            default:
                console.log(formattedMessage);
        }
    }
    
    log(level, message, meta = null) {
        if (this.logLevels[level] > this.logLevel) {
            return; // Skip if log level is too low
        }
        
        const formattedMessage = this.formatMessage(level, message, meta);
        
        // Write to console
        this.writeToConsole(level, message, meta);
        
        // Write to file if enabled
        this.writeToFile(level, formattedMessage);
    }
    
    error(message, meta = null) {
        this.log('error', message, meta);
    }
    
    warn(message, meta = null) {
        this.log('warn', message, meta);
    }
    
    info(message, meta = null) {
        this.log('info', message, meta);
    }
    
    debug(message, meta = null) {
        this.log('debug', message, meta);
    }
    
    // Cleanup old log files
    cleanupOldLogs(daysToKeep = 7) {
        if (!this.enableFileLogging) return;
        
        try {
            const files = fs.readdirSync(this.logDirectory);
            const cutoffDate = new Date();
            cutoffDate.setDate(cutoffDate.getDate() - daysToKeep);
            
            for (const file of files) {
                if (file.startsWith('webstar-') && file.endsWith('.log')) {
                    const filePath = path.join(this.logDirectory, file);
                    const stats = fs.statSync(filePath);
                    
                    if (stats.mtime < cutoffDate) {
                        fs.unlinkSync(filePath);
                        this.info(`Cleaned up old log file: ${file}`);
                    }
                }
            }
        } catch (error) {
            this.error('Failed to cleanup old logs:', error);
        }
    }
}

// Create singleton instance
const logger = new Logger();

module.exports = logger;
