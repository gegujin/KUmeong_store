// src/ws/realtime.server.ts
import type { Server as HttpServer } from 'http';
import { WebSocketServer, WebSocket } from 'ws';
import type { DataSource } from 'typeorm';

type Sub = { ws: WebSocket; roomId: string; userId?: string };

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

// ✅ path 를 선택 인자로 추가
type InitWsArgs = { httpServer: HttpServer; ds: DataSource; path?: string };

export function initRealtimeWs({ httpServer, ds, path = '/ws/realtime' }: InitWsArgs) {
  const wss = new WebSocketServer({
    server: httpServer,
    path,                     // ← 전달받은 경로 사용
    perMessageDeflate: false,
  });

  const rooms = new Map<string, Set<Sub>>();

  function joinRoom(sub: Sub) {
    const set = rooms.get(sub.roomId) ?? new Set<Sub>();
    set.add(sub);
    rooms.set(sub.roomId, set);
  }
  function leave(ws: WebSocket) {
    for (const set of rooms.values()) {
      for (const s of Array.from(set)) {
        if (s.ws === ws) set.delete(s);
      }
    }
  }

  (global as any).broadcastChatToRoom = (roomId: string, payload: unknown) => {
    const subs = rooms.get(roomId);
    if (!subs) return;
    const data = JSON.stringify({ type: 'chat', data: payload });
    for (const s of subs) {
      try { s.ws.send(data); } catch {}
    }
  };

  wss.on('connection', async (ws, req) => {
    try {
      const u = new URL(req.url ?? '', `http://${req.headers.host}`);
      const roomId = u.searchParams.get('room') ?? '';
      const me = u.searchParams.get('me') ?? '';

      if (!UUID_RE.test(roomId) || !UUID_RE.test(me)) {
        ws.close(4000, 'Bad query');
        return;
      }

      const rows = await ds.query(
        `SELECT id, type, buyerId, sellerId FROM chatRooms WHERE id = ? LIMIT 1`,
        [roomId],
      );
      const room = rows?.[0] as
        | { id: string; type: 'FRIEND' | 'TRADE'; buyerId: string; sellerId: string }
        | undefined;

      if (!room || room.type !== 'FRIEND') return ws.close(1008, 'invalid room');
      if (room.buyerId !== me && room.sellerId !== me) return ws.close(1008, 'forbidden');

      joinRoom({ ws, roomId, userId: me });

      ws.on('message', (buf) => {
        try {
          const msg = JSON.parse(String(buf));
          if (msg?.type === 'ping') {
            ws.send(JSON.stringify({ type: 'pong', t: new Date().toISOString() }));
          }
        } catch {}
      });

      ws.on('close', () => leave(ws));
      ws.on('error', () => leave(ws));
    } catch {
      ws.close(1011, 'bad request');
    }
  });

  return wss;
}
