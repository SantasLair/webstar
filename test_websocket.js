const WebSocket = require('ws');

console.log('Testing WebStar Server WebSocket connections...\n');

// Test signaling WebSocket
console.log('1. Testing Signaling WebSocket (/ws)...');
const signalingWs = new WebSocket('ws://localhost:8080/ws');

signalingWs.on('open', () => {
    console.log('✓ Signaling WebSocket connected successfully');
    
    // Send a test message
    signalingWs.send(JSON.stringify({
        type: 'ping',
        timestamp: Date.now()
    }));
});

signalingWs.on('message', (data) => {
    console.log('Received from signaling:', data.toString());
});

signalingWs.on('error', (error) => {
    console.log('✗ Signaling WebSocket error:', error.message);
});

signalingWs.on('close', () => {
    console.log('Signaling WebSocket closed');
});

// Test relay WebSocket
setTimeout(() => {
    console.log('\n2. Testing Relay WebSocket (/relay)...');
    const relayWs = new WebSocket('ws://localhost:8080/relay');
    
    relayWs.on('open', () => {
        console.log('✓ Relay WebSocket connected successfully');
        
        // Send a test message
        relayWs.send(JSON.stringify({
            type: 'relay_test',
            timestamp: Date.now()
        }));
    });
    
    relayWs.on('message', (data) => {
        console.log('Received from relay:', data.toString());
    });
    
    relayWs.on('error', (error) => {
        console.log('✗ Relay WebSocket error:', error.message);
    });
    
    relayWs.on('close', () => {
        console.log('Relay WebSocket closed');
    });
    
    // Close connections after test
    setTimeout(() => {
        console.log('\nClosing test connections...');
        signalingWs.close();
        relayWs.close();
        
        setTimeout(() => {
            console.log('\nWebSocket tests completed!');
            process.exit(0);
        }, 1000);
    }, 3000);
}, 1000);
