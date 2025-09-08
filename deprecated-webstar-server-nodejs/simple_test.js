const WebSocket = require('ws');

console.log('=== Simple WebStar Server Test ===\n');

// Test basic signaling connection
console.log('Testing basic signaling connection...');
const ws = new WebSocket('ws://localhost:8080/ws', {
    perMessageDeflate: false // Disable compression to avoid RSV1 issues
});

ws.on('open', () => {
    console.log('✓ Connected to signaling server');
    
    // Send a simple ping
    setTimeout(() => {
        try {
            ws.send(JSON.stringify({ type: 'ping' }));
            console.log('✓ Sent ping message');
        } catch (error) {
            console.log('✗ Error sending message:', error.message);
        }
    }, 100);
});

ws.on('message', (data) => {
    try {
        const message = JSON.parse(data.toString());
        console.log('✓ Received message:', message.type);
        
        if (message.type === 'connected') {
            console.log('  - Client ID:', message.clientId);
            console.log('  - Server message:', message.message);
        }
    } catch (error) {
        console.log('✓ Received raw message:', data.toString());
    }
});

ws.on('error', (error) => {
    console.log('✗ WebSocket error:', error.message);
});

ws.on('close', (code, reason) => {
    console.log('Connection closed. Code:', code, 'Reason:', reason.toString());
});

// Close after 3 seconds
setTimeout(() => {
    console.log('\nClosing connection...');
    ws.close();
    
    setTimeout(() => {
        console.log('Test completed!');
        process.exit(0);
    }, 1000);
}, 3000);
