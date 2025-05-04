const WebSocket = require('ws');

const server = new WebSocket.Server({ port: 9000 });

console.log('WebSocket server running on port 9000');

server.on('connection', (ws) => {
  console.log('Client connected');

  // Echo back messages
  ws.on('message', (message) => {
    console.log(`Received: ${message}`);
    ws.send(`${message}`);
  });

  // Send welcome message
  ws.send('Welcome to WebSocket Echo Server');

  ws.on('close', () => {
    console.log('Client disconnected');
  });
}); 