const WebSocket = require('ws');
const http = require('http');

// Create a simple WebSocket server that logs all connection details
const server = http.createServer();
const wss = new WebSocket.Server({ 
    server,
    verifyClient: (info) => {
        console.log('=== WebSocket Connection Attempt ===');
        console.log('Origin:', info.origin);
        console.log('User-Agent:', info.req.headers['user-agent']);
        console.log('Sec-WebSocket-Version:', info.req.headers['sec-websocket-version']);
        console.log('Sec-WebSocket-Key:', info.req.headers['sec-websocket-key']);
        console.log('Sec-WebSocket-Protocol:', info.req.headers['sec-websocket-protocol']);
        console.log('Sec-WebSocket-Extensions:', info.req.headers['sec-websocket-extensions']);
        console.log('Connection:', info.req.headers['connection']);
        console.log('Upgrade:', info.req.headers['upgrade']);
        console.log('All headers:', info.req.headers);
        console.log('=====================================');
        
        // Accept all connections
        return true;
    }
});

wss.on('connection', (ws, request) => {
    console.log('WebSocket connection established!');
    console.log('Client IP:', request.socket.remoteAddress);
    
    // Send a simple welcome message
    ws.send(JSON.stringify({
        type: 'welcome',
        message: 'Hello from test server'
    }));
    
    ws.on('message', (data) => {
        console.log('Received message:', data.toString());
    });
    
    ws.on('close', (code, reason) => {
        console.log(`Connection closed: code=${code}, reason=${reason}`);
    });
    
    ws.on('error', (error) => {
        console.log('WebSocket error:', error);
    });
});

server.listen(5091, 'localhost', () => {
    console.log('Test WebSocket server running on ws://localhost:5091');
});
