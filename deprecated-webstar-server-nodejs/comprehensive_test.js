const WebSocket = require('ws');

console.log('=== WebStar Server Comprehensive Test ===\n');

async function testEndpoints() {
    console.log('1. Testing HTTP endpoints...');
    
    try {
        // Test health endpoint
        const response1 = await fetch('http://localhost:8080/health');
        const health = await response1.json();
        console.log('✓ Health endpoint:', health.status);
        
        // Test stats endpoint  
        const response2 = await fetch('http://localhost:8080/stats');
        const stats = await response2.json();
        console.log('✓ Stats endpoint: uptime', stats.performance.uptime);
        
        // Test lobbies endpoint
        const response3 = await fetch('http://localhost:8080/lobbies');
        const lobbies = await response3.json();
        console.log('✓ Lobbies endpoint: found', lobbies.length, 'lobbies');
        
    } catch (error) {
        console.log('✗ HTTP endpoint error:', error.message);
    }
}

function testSignalingWebSocket() {
    return new Promise((resolve) => {
        console.log('\n2. Testing Signaling WebSocket...');
        
        const ws = new WebSocket('ws://localhost:8080/ws');
        let testResult = { connected: false, messagesReceived: 0 };
        
        ws.on('open', () => {
            console.log('✓ Signaling WebSocket connected');
            testResult.connected = true;
            
            // Test lobby creation
            ws.send(JSON.stringify({
                type: 'create_lobby',
                data: {
                    name: 'Test Lobby',
                    maxPlayers: 4,
                    isPublic: true
                }
            }));
        });
        
        ws.on('message', (data) => {
            testResult.messagesReceived++;
            const message = JSON.parse(data.toString());
            console.log('✓ Received message type:', message.type);
            
            if (message.type === 'lobby_created') {
                console.log('✓ Lobby created with ID:', message.data.lobbyId);
                
                // Test joining the lobby
                ws.send(JSON.stringify({
                    type: 'join_lobby',
                    data: {
                        lobbyId: message.data.lobbyId,
                        username: 'TestPlayer'
                    }
                }));
            } else if (message.type === 'lobby_joined') {
                console.log('✓ Successfully joined lobby');
                ws.close();
            }
        });
        
        ws.on('error', (error) => {
            console.log('✗ Signaling WebSocket error:', error.message);
            testResult.error = error.message;
        });
        
        ws.on('close', () => {
            console.log('Signaling WebSocket closed');
            resolve(testResult);
        });
        
        // Timeout after 5 seconds
        setTimeout(() => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.close();
            }
        }, 5000);
    });
}

function testRelayWebSocket() {
    return new Promise((resolve) => {
        console.log('\n3. Testing Relay WebSocket...');
        
        const ws = new WebSocket('ws://localhost:8080/relay');
        let testResult = { connected: false, messagesReceived: 0 };
        
        ws.on('open', () => {
            console.log('✓ Relay WebSocket connected');
            testResult.connected = true;
            
            // Send test data
            ws.send(JSON.stringify({
                type: 'relay_data',
                targetId: 'test',
                data: 'Hello relay!'
            }));
            
            setTimeout(() => ws.close(), 2000);
        });
        
        ws.on('message', (data) => {
            testResult.messagesReceived++;
            console.log('✓ Relay message received:', data.toString());
        });
        
        ws.on('error', (error) => {
            console.log('✗ Relay WebSocket error:', error.message);
            testResult.error = error.message;
        });
        
        ws.on('close', () => {
            console.log('Relay WebSocket closed');
            resolve(testResult);
        });
        
        // Timeout after 5 seconds
        setTimeout(() => {
            if (ws.readyState === WebSocket.OPEN) {
                ws.close();
            }
        }, 5000);
    });
}

async function runTests() {
    await testEndpoints();
    
    const signalingResult = await testSignalingWebSocket();
    const relayResult = await testRelayWebSocket();
    
    console.log('\n=== Test Results Summary ===');
    console.log('Signaling WebSocket:');
    console.log('  - Connected:', signalingResult.connected);
    console.log('  - Messages received:', signalingResult.messagesReceived);
    if (signalingResult.error) console.log('  - Error:', signalingResult.error);
    
    console.log('Relay WebSocket:');
    console.log('  - Connected:', relayResult.connected);
    console.log('  - Messages received:', relayResult.messagesReceived);
    if (relayResult.error) console.log('  - Error:', relayResult.error);
    
    console.log('\nTest completed!');
}

runTests();
