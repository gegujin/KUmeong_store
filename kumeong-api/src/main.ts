// C:\Users\82105\KU-meong Store\kumeong-api\src\main.ts
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { ConfigService } from '@nestjs/config';
import { SuccessResponseInterceptor } from './common/interceptors/success-response.interceptor';
import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
import { DataSource } from 'typeorm';
import { join } from 'path';
import * as express from 'express';
import * as http from 'http';
import { WebSocketServer, WebSocket } from 'ws';

type Sub = { ws: WebSocket; roomId: string; userId?: string };

// 빈 값일 때도 기본값 'api'
function sanitizePrefix(p?: string) {
  const v = (p ?? '').trim();
  const base = v.length > 0 ? v : 'api';
  return base.replace(/^\/+|\/+$/g, '');
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const cfg = app.get(ConfigService);

  // ===== Prefix (버전 포함, 버전닝 비활성) =====
  const apiPrefix = sanitizePrefix(cfg.get<string>('API_PREFIX'));
  const apiVersion = (cfg.get<string>('API_VERSION') ?? '1').trim();
  const fullPrefix = `${apiPrefix}/v${apiVersion}`; // => "api/v1"
  app.setGlobalPrefix(fullPrefix);
  Logger.log(`[HTTP] prefix="/${fullPrefix}"`);

  // ===== 공통 미들웨어 =====
  app.enableCors({
    origin: true,
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization', 'X-User-Id'],
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS', 'PATCH'],
  });
  app.use('/uploads', express.static(join(__dirname, '..', 'public', 'uploads')));

  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalInterceptors(new SuccessResponseInterceptor());
  app.useGlobalFilters(new GlobalExceptionFilter());

  // ===== Swagger =====
  const swaggerConfig = new DocumentBuilder()
    .setTitle('KU멍가게 API')
    .setDescription('캠퍼스 중고거래/배달(KU대리) 백엔드 v1')
    .setVersion('1.0.0')
    .addServer(`/${fullPrefix}`)
    .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
    .build();
  const swaggerDoc = SwaggerModule.createDocument(app, swaggerConfig, {
    operationIdFactory: (_controllerKey, methodKey) => methodKey,
  });
  SwaggerModule.setup(`/${apiPrefix}/docs`, app, swaggerDoc, {
    swaggerOptions: { docExpansion: 'none' },
  });

  // ===== DB 체크 =====
  const ds = app.get(DataSource);
  try {
    const [dbRow] = await ds.query('SELECT DATABASE() AS db');
    const currentDb = dbRow?.db ?? '(unknown)';
    Logger.log(`[DB] connected to: ${currentDb}`);
  } catch (e) {
    Logger.error(`[DB] startup check failed: ${(e as Error).message}`);
  }

  // ✅ 중요: 외부 서버를 쓸 때는 반드시 init() 먼저!
  await app.init();

  // ===== HTTP + WS 같은 포트 =====
  const server = http.createServer(app.getHttpAdapter().getInstance());
  const wss = new WebSocketServer({ server, path: '/ws/realtime' });

  const rooms = new Map<string, Set<Sub>>();
  function joinRoom(sub: Sub) {
    const set = rooms.get(sub.roomId) ?? new Set<Sub>();
    set.add(sub);
    rooms.set(sub.roomId, set);
  }
  function leave(ws: WebSocket) {
    for (const set of rooms.values()) {
      for (const s of Array.from(set)) if (s.ws === ws) set.delete(s);
    }
  }

  wss.on('connection', (ws, req) => {
    try {
      const url = new URL(req.url ?? '', `http://${req.headers.host}`);
      const roomId = url.searchParams.get('room') ?? '';
      const userId = url.searchParams.get('me') ?? '';
      if (!roomId) {
        ws.close(1008, 'room query required');
        return;
      }
      const sub: Sub = { ws, roomId, userId: userId || undefined };
      joinRoom(sub);

      ws.on('message', (buf) => {
        try {
          const msg = JSON.parse(String(buf));
          if (msg?.type === 'ping') {
            ws.send(JSON.stringify({ type: 'pong', t: new Date().toISOString() }));
          }
        } catch {/* ignore */}
      });
      ws.on('close', () => leave(ws));
      ws.on('error', () => leave(ws));
    } catch {
      ws.close(1011, 'bad request');
    }
  });

  (global as any).broadcastChatToRoom = (roomId: string, payload: any) => {
    const set = rooms.get(roomId);
    if (!set?.size) return;
    const frame = JSON.stringify({
      id: Date.now(),
      kind: 'chat.msg',
      roomId,
      refId: payload.id,
      userId: payload.senderId,
      payload: {
        seq: payload.seq,
        senderId: payload.senderId,
        type: 'TEXT',
        content: payload.text ?? '',
        createdAt: payload.timestamp,
      },
    });
    for (const s of set) if (s.ws.readyState === WebSocket.OPEN) s.ws.send(frame);
  };

  // ===== Route Dump (디버그) — server.listen 직전 =====
  const httpAdapter: any = app.getHttpAdapter();
  const expressApp: any = httpAdapter.getInstance ? httpAdapter.getInstance() : httpAdapter;
  const stack: any[] = expressApp?._router?.stack ?? [];
  for (const layer of stack) {
    if (layer.route) {
      const p = layer.route.path;
      const ms = Object.keys(layer.route.methods).join(',').toUpperCase();
      Logger.log(`[ROUTE] ${ms} ${p}`);
    } else if (layer.name === 'router' && layer.handle?.stack) {
      for (const s of layer.handle.stack) {
        if (s.route) {
          const p = s.route.path;
          const ms = Object.keys(s.route.methods).join(',').toUpperCase();
          Logger.log(`[ROUTE] ${ms} ${p}`);
        }
      }
    }
  }

  // ===== Listen =====
  const port = Number(cfg.get<string>('PORT') ?? 3000);
  await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', () => resolve()));

  Logger.log(`🚀 Server running at http://localhost:${port}/${fullPrefix}`);
  Logger.log(`📘 Swagger:        http://localhost:${port}/${apiPrefix}/docs`);
  Logger.log(`🔌 WS endpoint:    ws://localhost:${port}/ws/realtime?room=<roomId>&me=<uuid>`);
}

bootstrap().catch((e) => {
  Logger.error(e);
  process.exit(1);
});




// import 'reflect-metadata';
// import { NestFactory } from '@nestjs/core';
// import { AppModule } from './app.module';
// import { ValidationPipe, VersioningType, Logger } from '@nestjs/common';
// import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
// import { ConfigService } from '@nestjs/config';
// import { SuccessResponseInterceptor } from './common/interceptors/success-response.interceptor';
// import { GlobalExceptionFilter } from './common/filters/global-exception.filter';
// import { normalizeId } from './common/utils/ids';
// import { DataSource } from 'typeorm';
// import { join } from 'path';
// import * as express from 'express';

// // ★ 추가: 동일 포트에서 WS 구동을 위해 http/wss 사용
// import * as http from 'http';
// import { WebSocketServer, WebSocket } from 'ws';

// type Sub = { ws: WebSocket; roomId: string; userId?: string };

// /** prefix 문자열에서 /를 정리 */
// function sanitizePrefix(p?: string) {
//   const v = (p ?? 'api').trim();
//   return v.replace(/^\/+|\/+$/g, '');
// }

// /** .env의 CORS_ORIGIN 파싱 */
// function parseCorsOrigin(cfg: ConfigService) {
//   const raw = (cfg.get<string>('CORS_ORIGIN') ?? '').trim();
//   if (!raw) {
//     return [/^http:\/\/localhost(?::\d+)?$/, /^http:\/\/127\.0\.0\.1(?::\d+)?$/];
//   }
//   if (raw === '*') return true;
//   return raw
//     .split(',')
//     .map((s) => s.trim())
//     .filter(Boolean)
//     .map((s) => (s.startsWith('/') && s.endsWith('/') ? new RegExp(s.slice(1, -1)) : s));
// }

// /** 숫자 ID → UUID 문자열 변환 유틸 */
// function toUuidFromNumeric(n: string): string {
//   const digits = n.replace(/\D/g, '').slice(0, 12); // 12자리까지만 사용
//   return `00000000-0000-0000-0000-${digits.padStart(12, '0')}`;
// }

// async function bootstrap() {
//   const app = await NestFactory.create(AppModule);

//   const cfg = app.get(ConfigService);

//   // 요청 전처리: X-User-Id 숫자→UUID, UUID면 정규화
//   app.use((req, _res, next) => {
//     const raw = req.headers['x-user-id'];
//     if (typeof raw === 'string') {
//       const normalized = /^\d+$/.test(raw) ? toUuidFromNumeric(raw) : raw;
//       req.headers['x-user-id'] = normalizeId(normalized);
//     }
//     next();
//   });

//   // CORS
//   const originConf = parseCorsOrigin(cfg);
//   app.enableCors({
//     origin: originConf,
//     credentials: true,
//     methods: ['GET', 'HEAD', 'PUT', 'PATCH', 'POST', 'DELETE', 'OPTIONS'],
//     allowedHeaders: [
//       'Content-Type',
//       'Authorization',
//       'X-Requested-With',
//       'Accept',
//       'X-User-Id',
//       'X-API-Version',
//     ],
//     exposedHeaders: ['Content-Length'],
//   });

//   // 정적 파일 (업로드)
//   app.use('/uploads', express.static(join(__dirname, '..', 'public', 'uploads')));

//   // API Prefix & Versioning — URI (/api/v1/*)
//   const apiPrefix = sanitizePrefix(cfg.get<string>('API_PREFIX'));
//   const apiVersion = (cfg.get<string>('API_VERSION') ?? '1').trim();

//   app.setGlobalPrefix(apiPrefix);
//   app.enableVersioning({
//     type: VersioningType.URI, // /api/v1/*
//     defaultVersion: apiVersion,
//   });

//   // 호환 레이어: /api/* → /api/v{apiVersion}/*
//   app.use(`/${apiPrefix}`, (req, _res, next) => {
//     if (!req.url.startsWith('/v')) {
//       req.url = `/v${apiVersion}${req.url}`;
//     }
//     next();
//   });

//   // 글로벌 Pipes/Interceptors/Filters
//   app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
//   app.useGlobalInterceptors(new SuccessResponseInterceptor());
//   app.useGlobalFilters(new GlobalExceptionFilter());

//   // Swagger
//   const swaggerConfig = new DocumentBuilder()
//     .setTitle('KU멍가게 API')
//     .setDescription('캠퍼스 중고거래/배달(KU대리) 백엔드 v1')
//     .setVersion('1.0.0')
//     .addServer(`/${apiPrefix}/v${apiVersion}`)
//     .addBearerAuth({ type: 'http', scheme: 'bearer', bearerFormat: 'JWT' }, 'bearer')
//     .build();

//   const swaggerDoc = SwaggerModule.createDocument(app, swaggerConfig, {
//     operationIdFactory: (_controllerKey, methodKey) => methodKey,
//   });
//   SwaggerModule.setup(`/${apiPrefix}/docs`, app, swaggerDoc, {
//     swaggerOptions: { docExpansion: 'none' },
//   });

//   // DB 연결 체크 로그
//   const ds = app.get(DataSource);
//   try {
//     const [dbRow] = await ds.query('SELECT DATABASE() AS db');
//     const currentDb = dbRow?.db ?? '(unknown)';
//     const [viewRow] = await ds.query(
//       `
//       SELECT
//         SUM(CASE WHEN TABLE_NAME='vwfriendsforuser' THEN 1 ELSE 0 END) AS has_vwfriendsforuser,
//         SUM(CASE WHEN TABLE_NAME='vw_friends_for_user' THEN 1 ELSE 0 END) AS has_vw_friends_for_user,
//         SUM(CASE WHEN TABLE_NAME='vw_conversations_for_user' THEN 1 ELSE 0 END) AS has_vw_conversations_for_user
//       FROM information_schema.VIEWS
//       WHERE TABLE_SCHEMA = ?
//       `,
//       [currentDb],
//     );

//     Logger.log(`[DB] connected to: ${currentDb}`);
//     Logger.log(
//       `[DB] views — vwfriendsforuser: ${viewRow?.has_vwfriendsforuser ? 'OK' : 'MISSING'}, ` +
//         `vw_friends_for_user: ${viewRow?.has_vw_friends_for_user ? 'OK' : 'MISSING'}, ` +
//         `vw_conversations_for_user: ${viewRow?.has_vw_conversations_for_user ? 'OK' : 'MISSING'}`,
//     );
//   } catch (e) {
//     Logger.error(`[DB] startup check failed: ${(e as Error).message}`);
//   }

//   // ───────────── WS(Server-Side) 통합 (같은 포트) ─────────────
//   // Nest의 http 핸들러로 http.Server를 만들고, 같은 포트에서 WS도 띄움
//   const server = http.createServer(app.getHttpAdapter().getInstance());
//   const wss = new WebSocketServer({ server, path: '/ws/realtime' });

//   // roomId -> Set<Sub>
//   const rooms = new Map<string, Set<Sub>>();

//   function joinRoom(sub: Sub) {
//     const set = rooms.get(sub.roomId) ?? new Set<Sub>();
//     set.add(sub);
//     rooms.set(sub.roomId, set);
//   }
//   function leave(ws: WebSocket) {
//     for (const set of rooms.values()) {
//       for (const s of Array.from(set)) {
//         if (s.ws === ws) set.delete(s);
//       }
//     }
//   }

//   wss.on('connection', (ws, req) => {
//     try {
//       const url = new URL(req.url ?? '', `http://${req.headers.host}`);
//       const roomId = url.searchParams.get('room') ?? '';
//       const userId = url.searchParams.get('me') ?? '';
//       // const since = Number(url.searchParams.get('since') ?? 0); // 필요 시 사용

//       if (!roomId) {
//         ws.close(1008, 'room query required'); // policy violation
//         return;
//       }

//       const sub: Sub = { ws, roomId, userId: userId || undefined };
//       joinRoom(sub);

//       ws.on('message', (buf) => {
//         // 단순 ping/pong
//         try {
//           const msg = JSON.parse(String(buf));
//           if (msg?.type === 'ping') {
//             ws.send(JSON.stringify({ type: 'pong', t: new Date().toISOString() }));
//           }
//         } catch {
//           /* ignore */
//         }
//       });

//       ws.on('close', () => leave(ws));
//       ws.on('error', () => leave(ws));
//     } catch {
//       ws.close(1011, 'bad request');
//     }
//   });

//   // 프런트가 호출하는 브로드캐스터 (컨트롤러에서 사용)
//   (global as any).broadcastChatToRoom = (roomId: string, payload: any) => {
//     const set = rooms.get(roomId);
//     if (!set || set.size === 0) return;
//     const frame = JSON.stringify({
//       id: Date.now(),           // 단순 증가성 id (정합은 REST로 확보)
//       kind: 'chat.msg',
//       roomId,
//       refId: payload.id,        // 메시지 id
//       userId: payload.senderId, // 보낸 사람
//       payload: {
//         seq: payload.seq,
//         senderId: payload.senderId,
//         type: 'TEXT',
//         content: payload.text ?? '',
//         createdAt: payload.timestamp,
//       },
//     });
//     for (const s of set) {
//       if (s.ws.readyState === WebSocket.OPEN) {
//         s.ws.send(frame);
//       }
//     }
//   };

//   // 서버 시작 (HTTP + WS 동일 포트)
//   const port = Number(cfg.get<string>('PORT') ?? 3000);
//   await new Promise<void>((resolve) => server.listen(port, '0.0.0.0', () => resolve()));
//   Logger.log(`🚀 Server running at http://localhost:${port}/${apiPrefix}/v${apiVersion}`);
//   Logger.log(`   Swagger:        http://localhost:${port}/${apiPrefix}/docs`);
//   Logger.log(`   WS endpoint:    ws://localhost:${port}/ws/realtime?room=<roomId>&me=<uuid>`);
// }

// bootstrap().catch((e) => {
//   Logger.error(e);
//   process.exit(1);
// });

