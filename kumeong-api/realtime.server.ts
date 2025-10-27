import * as http from 'http';
import WebSocket, { WebSocketServer } from 'ws';

export function initRealtimeWs(args: {
  httpServer: http.Server;
  onSendText(roomId: string, me: string, text: string): Promise<any>;
}) {
  const { httpServer, onSendText } = args;

  // ✅ 포트 바인딩하지 않음
  const wss = new WebSocketServer({ noServer: true });

  httpServer.on('upgrade', (req, socket, head) => {
    const url = new URL(req.url ?? '', `http://${req.headers.host}`);
    if (url.pathname !== '/ws/realtime') {
      socket.destroy(); return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  });

  wss.on('connection', (ws: WebSocket) => {
    // ... 메시지 처리 (hello/send 등)
  });

  return { wss };
}
