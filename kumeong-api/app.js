// app.js  (ASCII only, Express mini backend for smoke test)
// Run: npm i express cors jsonwebtoken body-parser uuid && node app.js

const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bodyParser = require('body-parser');
const { v4: uuidv4 } = require('uuid');

const PORT = process.env.PORT || 3000;
const API_BASE = '/api/v1';
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

// ---------------- In-memory stores ----------------
const users = new Map();         // key: id
const usersByEmail = new Map();  // key: email
const rooms = new Map();         // key: roomId -> room
const roomMessages = new Map();  // key: roomId -> [messages]
const readCursors = new Map();   // key: roomId:userId -> lastReadMessageId

// Seed users (lightweight)
function ensureUser(id, email, name) {
  if (![...users.values()].find(u => u.id === id)) {
    const u = { id, email, name: name || email.split('@')[0], role: 'USER', password: '1111' };
    users.set(id, u);
    usersByEmail.set(email, u);
  }
}
ensureUser('11111111-1111-1111-1111-111111111111', 'student@kku.ac.kr', 'KKU Student');
ensureUser('33333333-3333-3333-3333-333333333333', 'buyer@kku.ac.kr',   'Buyer');
ensureUser('7e1806e0-5dcc-434a-9fb6-cdab027c80ee', '111@kku.ac.kr', 'user1'); // your current login

// Seed a TRADE room id used by the smoke script as fallback
const SEEDED_TRADE_ROOM_ID = 'cr111111-cr11-cr11-cr11-cr1111111111';
if (!rooms.has(SEEDED_TRADE_ROOM_ID)) {
  rooms.set(SEEDED_TRADE_ROOM_ID, {
    id: SEEDED_TRADE_ROOM_ID,
    type: 'TRADE',
    productId: 'aaaaaaa1-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
    buyerId: '33333333-3333-3333-3333-333333333333',
    sellerId: '11111111-1111-1111-1111-111111111111',
    createdAt: new Date().toISOString(),
    lastMessageId: null,
    lastMessageAt: null,
    lastSenderId: null,
    lastSnippet: null,
  });
  roomMessages.set(SEEDED_TRADE_ROOM_ID, []);
}

// ---------------- helpers ----------------
function signToken(user) {
  return jwt.sign({ sub: user.id, email: user.email, role: user.role }, JWT_SECRET, { expiresIn: '7d' });
}

function auth(req, res, next) {
  const h = req.headers['authorization'] || '';
  const token = h.startsWith('Bearer ') ? h.slice(7) : null;
  if (!token) return res.status(401).json({ ok: false, error: 'NO_TOKEN' });
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.userId = payload.sub;
    req.user = users.get(payload.sub);
    if (!req.user) return res.status(401).json({ ok: false, error: 'USER_NOT_FOUND' });
    next();
  } catch (e) {
    return res.status(401).json({ ok: false, error: 'BAD_TOKEN' });
  }
}

function ensureRoomMessages(roomId) {
  if (!roomMessages.has(roomId)) roomMessages.set(roomId, []);
  return roomMessages.get(roomId);
}

function ensureFriendRoom(meId, peerId) {
  // canonical buyer/seller sort for FRIEND
  const buyerId  = [meId, peerId].sort()[0];
  const sellerId = [meId, peerId].sort()[1];
  // find existing FRIEND room
  for (const r of rooms.values()) {
    if (r.type === 'FRIEND' && !r.productId && r.buyerId === buyerId && r.sellerId === sellerId) {
      return r;
    }
  }
  // create new FRIEND room
  const id = uuidv4();
  const room = {
    id,
    type: 'FRIEND',
    productId: null,
    buyerId,
    sellerId,
    createdAt: new Date().toISOString(),
    lastMessageId: null,
    lastMessageAt: null,
    lastSenderId: null,
    lastSnippet: null,
  };
  rooms.set(id, room);
  roomMessages.set(id, []);
  return room;
}

// ---------------- app ----------------
const app = express();
app.use(cors());
app.use(bodyParser.json());

// root ping
app.get('/', (req, res) => res.json({ ok: true, service: 'kumeong-mock', base: API_BASE }));

// -------- Auth --------
app.post(`${API_BASE}/auth/register`, (req, res) => {
  const { email, password, name } = req.body || {};
  if (!email || !password) return res.status(400).json({ ok: false, error: 'EMAIL_PASSWORD_REQUIRED' });
  if (usersByEmail.has(email)) return res.status(409).json({ ok: false, error: 'EMAIL_EXISTS' });
  const id = uuidv4();
  const user = { id, email, name: name || email.split('@')[0], role: 'USER', password };
  users.set(id, user);
  usersByEmail.set(email, user);
  return res.json({ ok: true, data: { id: user.id, email: user.email, name: user.name } });
});

app.post(`${API_BASE}/auth/login`, (req, res) => {
  const { email, password } = req.body || {};
  const user = usersByEmail.get(email);
  if (!user || user.password !== password) {
    return res.status(401).json({ ok: false, error: { code: 'INVALID_CREDENTIALS' } });
  }
  const accessToken = signToken(user);
  return res.json({
    ok: true,
    data: {
      accessToken,
      user: { id: user.id, email: user.email, role: user.role, name: user.name }
    }
  });
});

// /auth/me — the smoke script accepts { ok:true, user:{...} } shape
app.get(`${API_BASE}/auth/me`, auth, (req, res) => {
  const u = req.user;
  return res.json({ ok: true, user: { id: u.id, email: u.email, role: u.role, name: u.name } });
});

// -------- Chats: list rooms --------
app.get(`${API_BASE}/chats/rooms`, auth, (req, res) => {
  // Return all rooms where user participates (buyer/seller)
  const mine = [...rooms.values()].filter(r => r.buyerId === req.userId || r.sellerId === req.userId);
  return res.json({ ok: true, data: mine });
});

// -------- Chats: ensure FRIEND room with peer --------
app.post(`${API_BASE}/chats/friend-room/:peerId`, auth, (req, res) => {
  const { peerId } = req.params;
  if (!peerId) return res.status(400).json({ ok: false, error: 'PEER_ID_REQUIRED' });
  if (peerId === req.userId) return res.status(400).json({ ok: false, error: 'PEER_IS_SELF' });

  const r = ensureFriendRoom(req.userId, peerId);

  // r이 string(=roomId)이든 {id}/{roomId} 객체든 안전하게 추출
  const roomId =
    typeof r === 'string' ? r
    : (r && (r.roomId || r.id)) || '';

  if (!roomId) return res.status(500).json({ ok: false, error: 'ROOM_RESOLVE_FAILED' });

  // ✅ 컨트롤러와 동일 응답 스펙
  return res.json({ ok: true, roomId, data: { id: roomId, roomId } });
});


// -------- Chats: send message to a room --------
app.post(`${API_BASE}/chats/rooms/:roomId/messages`, auth, (req, res) => {
  const { roomId } = req.params;
  const { type = 'TEXT', content = null, fileUrl = null } = req.body || {};
  const room = rooms.get(roomId);
  if (!room) return res.status(404).json({ ok: false, error: 'ROOM_NOT_FOUND' });

  const id = uuidv4();
  const now = new Date().toISOString();
  const msg = { id, roomId, senderId: req.userId, type, content, fileUrl, createdAt: now };
  ensureRoomMessages(roomId).push(msg);

  room.lastMessageId = id;
  room.lastMessageAt = now;
  room.lastSenderId  = req.userId;
  room.lastSnippet   = type === 'TEXT' ? String(content || '').slice(0, 140) : (type === 'FILE' ? '[FILE]' : '[SYSTEM]');

  return res.json({ ok: true, data: msg });
});

app.get(`${API_BASE}/chat/friend-room`, auth, (req, res) => {
  const peerId = req.query.peerId;
  if (!peerId) return res.status(400).json({ ok: false, error: 'PEER_ID_REQUIRED' });
  if (peerId === req.userId) return res.status(400).json({ ok: false, error: 'PEER_IS_SELF' });

  const r = ensureFriendRoom(req.userId, peerId);
  const roomId =
    typeof r === 'string' ? r
    : (r && (r.roomId || r.id)) || '';

  if (!roomId) return res.status(500).json({ ok: false, error: 'ROOM_RESOLVE_FAILED' });

  return res.json({ ok: true, roomId, data: { id: roomId, roomId } });
});


// -------- Chats: update read cursor --------
app.put(`${API_BASE}/chats/rooms/:roomId/read-cursor`, auth, (req, res) => {
  const { roomId } = req.params;
  const { lastReadMessageId } = req.body || {};
  if (!rooms.has(roomId)) return res.status(404).json({ ok: false, error: 'ROOM_NOT_FOUND' });
  const key = `${roomId}:${req.userId}`;
  readCursors.set(key, lastReadMessageId || null);
  return res.json({ ok: true });
});

// -------- Optional generic endpoints the script might probe --------

// POST /api/v1/messages/send  (body {roomId, type, content})
app.post(`${API_BASE}/messages/send`, auth, (req, res) => {
  const { roomId, type = 'TEXT', content = null } = req.body || {};
  if (!roomId) return res.status(400).json({ ok: false, error: 'ROOM_ID_REQUIRED' });
  req.params.roomId = roomId;
  req.body = { type, content };
  return app._router.handle(req, res, () => {}, 'post', `${API_BASE}/chats/rooms/:roomId/messages`);
});

// GET various list aliases
app.get(`${API_BASE}/rooms`, auth, (req, res) => {
  const mine = [...rooms.values()].filter(r => r.buyerId === req.userId || r.sellerId === req.userId);
  return res.json({ ok: true, data: mine });
});
app.get(`${API_BASE}/chat-rooms`, auth, (req, res) => {
  const mine = [...rooms.values()].filter(r => r.buyerId === req.userId || r.sellerId === req.userId);
  return res.json({ ok: true, data: mine });
});

// simple openapi/docs dummies for the scanner
app.get(`${API_BASE}/openapi.json`, (_req, res) => res.json({ openapi: '3.0.0', info: { title: 'mock', version: '1.0.0' } }));
app.get(`/openapi.json`, (_req, res) => res.json({ openapi: '3.0.0', info: { title: 'root-mock', version: '1.0.0' } }));

// ---------------- start ----------------
app.listen(PORT, () => {
  console.log(`KU-Meong mock API running on http://127.0.0.1:${PORT}${API_BASE}`);
});
